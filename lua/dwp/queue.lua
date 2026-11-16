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
local MAX_BYTES = 64 * 1024
local MAX_ITEMS = 64
local NOTE_MAX = 200
local DOC_KEYS = { schema = true, updated_at = true, items = true, parallel = true }
local ITEM_KEYS = { plan = true, after = true, state = true, lead = true, start = true, note = true }
local REQUIRED = { "plan", "after", "state", "lead", "start" }

-- The pack's PLAN_ID: ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$
local function plan_id(value)
	return type(value) == "string" and #value <= 128 and value:match("^[A-Za-z0-9][A-Za-z0-9._-]*$") ~= nil
end

-- herdr-peers' pane address:
-- ^(?:local|[A-Za-z0-9][A-Za-z0-9._-]{0,63}):[A-Za-z0-9]{1,32}:[A-Za-z0-9]{1,32}$
local function pane_address(value)
	if type(value) ~= "string" then
		return false
	end
	local machine, workspace, pane = value:match("^([^:]+):([^:]+):([^:]+)$")
	if not machine then
		return false
	end
	local machine_ok = machine == "local" or (#machine <= 64 and machine:match("^[A-Za-z0-9][A-Za-z0-9._-]*$") ~= nil)
	return machine_ok
		and #workspace <= 32
		and workspace:match("^[A-Za-z0-9]+$") ~= nil
		and #pane <= 32
		and pane:match("^[A-Za-z0-9]+$") ~= nil
end

-- A regular file (never a symlink) of at most 64 KiB, decoded; nil
-- otherwise. The same ceilings the pack's writer and the daemon apply.
local function read_json(path)
	local stat = (vim.uv or vim.loop).fs_lstat(path)
	if not stat or stat.type ~= "file" or stat.size > MAX_BYTES then
		return nil
	end
	local handle = io.open(path, "r")
	if not handle then
		return nil
	end
	local content = handle:read(MAX_BYTES + 1)
	handle:close()
	if type(content) ~= "string" or #content > MAX_BYTES then
		return nil
	end
	local ok, decoded = pcall(vim.json.decode, content)
	if not ok then
		return nil
	end
	return decoded
end

-- One item, validated exactly like the pack's valid_doc: every base key
-- present (null allowed only where the schema allows it), nothing
-- unknown. Returns the display item or nil.
local function valid_item(raw)
	if type(raw) ~= "table" then
		return nil
	end
	for key in pairs(raw) do
		if not ITEM_KEYS[key] then
			return nil
		end
	end
	for _, key in ipairs(REQUIRED) do
		if raw[key] == nil then
			return nil
		end
	end
	if not plan_id(raw.plan) then
		return nil
	end
	local after = raw.after
	if after == vim.NIL then
		after = nil
	elseif not plan_id(after) then
		return nil
	end
	if not STATES[raw.state] or not STARTS[raw.start] then
		return nil
	end
	local lead = raw.lead
	if lead == vim.NIL then
		lead = nil
	elseif not pane_address(lead) then
		return nil
	end
	if raw.state == "started" and lead == nil then
		return nil
	end
	if raw.note ~= nil then
		if type(raw.note) ~= "string" or raw.note:match("^%s*$") or #raw.note > NOTE_MAX then
			return nil
		end
	end
	return { plan = raw.plan, after = after, state = raw.state, lead = lead, start = raw.start }
end

--- Read and validate one queue file. Returns the queue table (items in
--- file order, each { plan, after, state, lead, start }) or nil when
--- the file is absent, not a regular file of at most 64 KiB, unparsable,
--- or not a valid dwp-queue-v1 document. Validation matches the pack's
--- writer (shared/queue.py valid_doc) and is all-or-nothing: one bad
--- item, a duplicate plan or more than 64 items rejects the document,
--- so no hand-edited value ever reaches a buffer.
function M.read(path)
	local doc = read_json(path)
	if type(doc) ~= "table" or doc.schema ~= M.SCHEMA then
		return nil
	end
	for key in pairs(doc) do
		if not DOC_KEYS[key] then
			return nil
		end
	end
	if type(doc.items) ~= "table" or #doc.items > MAX_ITEMS then
		return nil
	end
	if doc.parallel ~= nil and type(doc.parallel) ~= "boolean" then
		return nil
	end
	local items, seen = {}, {}
	for _, raw in ipairs(doc.items) do
		local item = valid_item(raw)
		if not item or seen[item.plan] then
			return nil
		end
		seen[item.plan] = true
		items[#items + 1] = item
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
