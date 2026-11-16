-- Read-only view of the pack's plan queue: .dwp/queue.json, schema
-- 'dwp-queue-v1' (pack 8.0). The pack is the only writer — create
-- appends on approval, execute flips started, finalize flips done,
-- refine flips skipped — and this module only reads, exactly like the
-- plan surfaces read manifest + PROGRESS. Defensive by the same
-- contract as dwp.state: a missing, corrupt or unrecognized queue is
-- nil, and every surface that consumes it renders exactly as before —
-- a repository without a queue never changes what the editor shows.
--
-- Shape (PLAN_024): { schema, updated_at, items: [{ plan, after,
-- state: queued|started|done|skipped, lead, start: prompt-lead|launch
-- }], parallel?: bool }. 'parallel' is optional; absent means the pack
-- runs one plan at a time per repository.

local M = {}

M.SCHEMA = "dwp-queue-v1"

local STATES = { queued = true, started = true, done = true, skipped = true }
local STARTS = { ["prompt-lead"] = true, launch = true }

local function read_json(path)
	local handle = io.open(path, "r")
	if not handle then
		return nil
	end
	local content = handle:read("*a")
	handle:close()
	local ok, decoded = pcall(vim.json.decode, content)
	if not ok then
		return nil
	end
	return decoded
end

--- Read and validate one queue file. Returns the queue table (items in
--- file order, each { plan, after, state, lead, start }) or nil when
--- the file is absent, unparsable, or not a dwp-queue-v1 document.
--- The schema id gates everything: a future schema is not guessed at.
--- Items are kept individually tolerant — an item with an unknown
--- state or start value still surfaces (with its raw values) instead
--- of hiding the plan from the queue view; only the document-level
--- shape is enforced.
function M.read(path)
	local doc = read_json(path)
	if type(doc) ~= "table" or doc.schema ~= M.SCHEMA then
		return nil
	end
	if type(doc.items) ~= "table" then
		return nil
	end
	local items = {}
	for _, raw in ipairs(doc.items) do
		if type(raw) == "table" and type(raw.plan) == "string" and raw.plan ~= "" then
			local state = raw.state
			if type(state) ~= "string" or not STATES[state] then
				state = type(state) == "string" and state or "queued"
			end
			local start = raw.start
			if type(start) ~= "string" or not STARTS[start] then
				start = nil
			end
			items[#items + 1] = {
				plan = raw.plan,
				after = type(raw.after) == "string" and raw.after ~= "" and raw.after or nil,
				state = state,
				lead = type(raw.lead) == "string" and raw.lead ~= "" and raw.lead or nil,
				start = start,
			}
		end
	end
	return {
		items = items,
		updated_at = type(doc.updated_at) == "string" and doc.updated_at or nil,
		parallel = doc.parallel == true,
	}
end

--- The queue that governs the plans scanned under `roots` — the same
--- roots dwp.plans scans. Each plan root ends in /.dwp/plans, so the
--- queue sits beside it at <repo>/.dwp/queue.json. The first valid
--- queue wins (the working directory's own repo before the config
--- directory's); nil when none of the roots has one.
function M.find_for_roots(roots)
	for _, root in ipairs(roots or {}) do
		local dwp_dir = tostring(root):match("^(.*)/plans$")
		if dwp_dir then
			local queue = M.read(dwp_dir .. "/queue.json")
			if queue then
				return queue
			end
		end
	end
	return nil
end

--- One plan's queue view: { state, position, ahead, total, lead, start
--- } or nil when the queue is nil or the plan is not in it. `position`
--- is the plan's 1-based place in file order; `ahead` counts the plans
--- before it that are still queued or started — the "how many plans
--- before mine" number a reader parses without thinking.
function M.for_plan(queue, plan_name)
	if type(queue) ~= "table" or type(queue.items) ~= "table" then
		return nil
	end
	local total = #queue.items
	for index, item in ipairs(queue.items) do
		if item.plan == plan_name then
			local ahead = 0
			for before = 1, index - 1 do
				local state = queue.items[before].state
				if state == "queued" or state == "started" then
					ahead = ahead + 1
				end
			end
			return {
				state = item.state,
				position = index,
				ahead = ahead,
				total = total,
				lead = item.lead,
				start = item.start,
			}
		end
	end
	return nil
end

--- Counts by state, for a header or summary line. Unknown states count
--- as "other" so nothing is silently dropped from the totals.
function M.summary(queue)
	if type(queue) ~= "table" or type(queue.items) ~= "table" then
		return nil
	end
	local counts = { queued = 0, started = 0, done = 0, skipped = 0, other = 0 }
	for _, item in ipairs(queue.items) do
		if counts[item.state] then
			counts[item.state] = counts[item.state] + 1
		else
			counts.other = counts.other + 1
		end
	end
	counts.parallel = queue.parallel == true
	counts.total = #queue.items
	return counts
end

--- One plain-language line for a plan's queue view, or nil when there
--- is nothing to say. The queue's own state words (queued, started,
--- done, skipped) are the pack's vocabulary, rendered verbatim — they
--- describe the queue, not the plan's working state, which stays
--- dwp.state's alone.
function M.line(view)
	if not view then
		return nil
	end
	local place = string.format("#%d of %d", view.position, view.total)
	if view.ahead > 0 then
		place = place .. string.format(", %d ahead", view.ahead)
	end
	return string.format("queue: %s · %s", view.state, place)
end

return M
