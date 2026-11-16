-- Plan state derivation, defensive by contract: parse what exists,
-- degrade gracefully, never crash on a partial plan. A plan that cannot
-- be parsed is "unknown" — still listed, never hidden.
--
-- Labels and their meaning:
--   draft      markdown only — no manifest.json (not yet materialized)
--   approved   materialized (manifest + contract) with an approval event
--              and no task started
--   in-flight  at least one task_start in the journal and completion not
--              yet derived
--   completed  the state.json projection shows every task completed
--   unknown    a present artifact failed to parse
--
-- derive_rich() layers the plain-language vocabulary every UI surface
-- renders (frozen in the plan's DESIGN_SPEC: label, icon, highlight,
-- progress, current task, blocked signal, friendly title). derive()
-- keeps its v1 behavior byte-identical — rich facts never feed back.

local M = {}

local function read_json(path)
	local handle = io.open(path, "r")
	if not handle then
		return nil
	end
	local content = handle:read("*a")
	handle:close()
	local ok, decoded = pcall(vim.json.decode, content)
	if not ok then
		return nil, false
	end
	return decoded, true
end

-- Journal lines are independent JSON objects; a torn or corrupt line is
-- skipped, not fatal — the readable events still carry signal.
local function journal_types(path)
	local handle = io.open(path, "r")
	if not handle then
		return {}
	end
	local types = {}
	for line in handle:lines() do
		if line ~= "" then
			local ok, event = pcall(vim.json.decode, line)
			if ok and type(event) == "table" and event.type then
				types[#types + 1] = event.type
			end
		end
	end
	handle:close()
	return types
end

function M.derive(plan_path)
	local manifest, ok = read_json(plan_path .. "/manifest.json")
	if manifest == nil then
		if ok == false then
			return "unknown"
		end
		return "draft"
	end

	local types = journal_types(plan_path .. "/journal.ndjson")
	local snapshot = read_json(plan_path .. "/state.json")
	if type(snapshot) == "table" and type(snapshot.tasks) == "table" and #snapshot.tasks > 0 then
		local all_done = true
		for _, task in ipairs(snapshot.tasks) do
			if task.status ~= "completed" then
				all_done = false
				break
			end
		end
		if all_done then
			return "completed"
		end
	end

	for _, event_type in ipairs(types) do
		if event_type == "task_start" then
			return "in-flight"
		end
	end
	for _, event_type in ipairs(types) do
		if event_type == "approval" then
			return "approved"
		end
	end
	return "draft"
end

-- ---------------------------------------------------------------- rich --

-- The frozen plain-language vocabulary (DESIGN_SPEC § Status vocabulary).
-- "Needs attention" is not a sixth machine state: it overlays in-flight
-- when the plan's state.json carries a blocker.
local VOCAB = {
	draft = { label = "Not started", icon = "○", highlight = "Comment" },
	approved = { label = "Ready", icon = "◔", highlight = "Directory" },
	["in-flight"] = { label = "Working", icon = "◉", highlight = "MoreMsg" },
	completed = { label = "Done", icon = "✓", highlight = "Special" },
	unknown = { label = "Unknown", icon = "·", highlight = "Comment" },
}

-- Task progress from the README's own checkboxes — the human surface, so
-- it is advisory (the journal-derived state stays authoritative). Owned
-- here so derivation and display never disagree about the counter.
function M.task_counts(readme_path)
	local handle = io.open(readme_path, "r")
	if not handle then
		return nil, nil
	end
	local total, done = 0, 0
	for line in handle:lines() do
		if line:match("^%s*%- %[x%]") then
			total = total + 1
			done = done + 1
		elseif line:match("^%s*%- %[ %]") then
			total = total + 1
		end
	end
	handle:close()
	return done, total
end

-- Friendly title, frozen resolution order (first hit wins, the last
-- source cannot fail): README's first "# " heading minus a "Plan: "
-- prefix, then the contract's title via the manifest pointer, then the
-- directory name humanized, then the raw directory name.
function M.resolve_title(plan_path)
	local handle = io.open(plan_path .. "/README.md", "r")
	if handle then
		for line in handle:lines() do
			local heading = line:match("^#%s+(.+)%s*$")
			if heading then
				handle:close()
				return (heading:gsub("^Plan:%s*", ""))
			end
			-- A level-2+ heading or body text means no level-1 title exists.
			if line:match("^##") or line:match("%S") then
				break
			end
		end
		handle:close()
	end

	local manifest = read_json(plan_path .. "/manifest.json")
	if type(manifest) == "table" and type(manifest.contract) == "table" and manifest.contract.path then
		local contract = read_json(plan_path .. "/" .. manifest.contract.path)
		if type(contract) == "table" and type(contract.title) == "string" and contract.title ~= "" then
			return contract.title
		end
	end

	local base = plan_path:match("([^/]+)$") or plan_path
	local humanized = base:gsub("^PLAN_%d+_", ""):gsub("_", " ")
	return humanized:sub(1, 1):upper() .. humanized:sub(2)
end

-- The blocked signal. The ledger writes `blocker`; `blocked` is accepted
-- as a defensive alias (both spellings appear in the wild). Any shape is
-- tolerated — only a human-readable reason is extracted, never assumed.
-- Pack 8.0 adds structured fields on the table shape: `resolver`
-- ("lead" | "human"; absent means human) and `class` (C1–C7), surfaced
-- on the record as blocker_resolver / blocker_class.
-- Both come back as nil unless the record carries them, so a 7.x plan
-- renders exactly as before and an 8.0 record earns its badge.
local function blocked_signal(snapshot)
	if type(snapshot) ~= "table" then
		return false, nil, nil, nil
	end
	local raw = snapshot.blocker or snapshot.blocked
	-- JSON null decodes to vim.NIL, not Lua nil — both mean "no blocker".
	if raw == nil or raw == vim.NIL or raw == false or raw == "" then
		return false, nil, nil, nil
	end
	local reason, resolver, class
	if type(raw) == "string" then
		reason = raw
	elseif type(raw) == "table" then
		for _, key in ipairs({ "reason", "detail", "note", "message" }) do
			if type(raw[key]) == "string" and raw[key] ~= "" then
				reason = raw[key]
				break
			end
		end
		if raw.resolver == "lead" or raw.resolver == "human" then
			resolver = raw.resolver
		end
		-- The class is the blocker record's `class` (C1–C7), the field
		-- pack 8.0.0's plan-snapshot/v8 writes and herdr-peers 2.1.0's
		-- fleet report reads; anything outside C1–C7 is ignored.
		if type(raw.class) == "string" and raw.class:match("^C[1-7]$") then
			class = raw.class
		end
		-- plan-snapshot/v8 allows resolver "lead" only with C3, C4 or C7
		-- (a lead never clears authority, consent, damage or terms); any
		-- other class with "lead" is read as the human's.
		if resolver == "lead" and class and not ({ C3 = true, C4 = true, C7 = true })[class] then
			resolver = "human"
		end
	end
	return true, reason, resolver, class
end

-- The autonomy posture (plan-contract/v8, spec/LOOP_ENGINEERING.md §2):
-- the optional, closed `autonomy` block of the plan's live CONTRACT
-- (the highest contracts/ revision, else the manifest's pointer), never
-- state.json.
-- Only a v8 contract has a posture; a v7 or older contract (or none)
-- yields nil, so those plans render exactly as before. Inside a v8
-- contract the consumer MUST apply each absent key's recorded default —
-- an absent block means all five defaults: stall_budget 3, promptable =
-- the lead only, notify = no target, brain = false, queue = none. A key
-- of the wrong shape falls back to its default; a non-table block says
-- nothing. Queue position is NOT read here: it lives in the pack's queue
-- (dwp.queue), not the contract.
M.CONTRACT_V8 = "https://deepworkplan.com/schema/plan-contract/v8.json"

local function string_list(value)
	if type(value) ~= "table" or #value == 0 then
		return nil
	end
	local out = {}
	for _, item in ipairs(value) do
		if type(item) ~= "string" or item == "" then
			return nil
		end
		out[#out + 1] = item
	end
	return out
end

-- The live contract (V6_LIFECYCLE §5): the highest revision under
-- contracts/ (contract.rN.json; staged .pending files are invisible),
-- else the manifest's pointer (provenance, the contract as first
-- written). nil when neither exists.
local function live_contract(plan_path)
	local best, best_n = nil, 0
	local dir = (vim.uv or vim.loop).fs_scandir(plan_path .. "/contracts")
	if dir then
		while true do
			local name, kind = (vim.uv or vim.loop).fs_scandir_next(dir)
			if not name then
				break
			end
			local n = tonumber(name:match("^contract%.r(%d+)%.json$"))
			if n and kind == "file" and n > best_n then
				best, best_n = name, n
			end
		end
	end
	if best then
		return read_json(plan_path .. "/contracts/" .. best)
	end
	local manifest = read_json(plan_path .. "/manifest.json")
	if type(manifest) ~= "table" or type(manifest.contract) ~= "table" then
		return nil
	end
	local rel = manifest.contract.path
	if type(rel) ~= "string" or rel == "" or rel:find("..", 1, true) then
		return nil
	end
	return read_json(plan_path .. "/" .. rel)
end

--- The plan's autonomy posture, or nil (see above). Computed on demand
--- by the reader only — never during a plans scan, so the sidebar,
--- statusline and greeter pay no contract reads for it.
function M.posture(plan_path)
	if type(plan_path) ~= "string" then
		return nil
	end
	local contract = live_contract(plan_path)
	if type(contract) ~= "table" or contract.schema ~= M.CONTRACT_V8 then
		return nil
	end
	local raw = contract.autonomy
	if raw == nil then
		raw = {}
	elseif type(raw) ~= "table" then
		return nil
	end
	local out = { stall_budget = 3, promptable = nil, notify = nil, brain = false, queue = "none" }
	local budget = raw.stall_budget
	if type(budget) == "number" and budget % 1 == 0 and budget >= 1 and budget <= 10 then
		out.stall_budget = budget
	end
	out.promptable = string_list(raw.promptable)
	out.notify = string_list(raw.notify)
	if raw.brain == true then
		out.brain = true
	end
	if raw.queue == "prompt-lead" or raw.queue == "launch" or raw.queue == "none" then
		out.queue = raw.queue
	end
	return out
end

-- The task happening right now: the started-but-not-completed task with
-- the highest started_seq in the state.json projection; if the snapshot
-- cannot answer, the journal's last task_start stands in. Constant
-- memory, and the journal is only read when the snapshot stays silent.
local function current_task(machine, snapshot, plan_path)
	if machine ~= "in-flight" then
		return nil
	end
	if type(snapshot) == "table" and type(snapshot.tasks) == "table" then
		local best, best_seq
		for _, task in ipairs(snapshot.tasks) do
			if
				type(task) == "table"
				and task.id
				and task.status ~= "completed"
				and type(task.started_seq) == "number"
				and (best_seq == nil or task.started_seq > best_seq)
			then
				best, best_seq = task.id, task.started_seq
			end
		end
		if best then
			return best
		end
	end
	local handle = io.open(plan_path .. "/journal.ndjson", "r")
	if not handle then
		return nil
	end
	local last
	for line in handle:lines() do
		if line ~= "" then
			local ok, event = pcall(vim.json.decode, line)
			if ok and type(event) == "table" and event.type == "task_start" and event.task then
				last = event.task
			end
		end
	end
	handle:close()
	return last
end

-- The structured-blocker badge text (pack 8.0), or nil when the record
-- carries neither field — a 7.x plan renders without a badge. Absent
-- resolver means human (PLAN_024); the words carry the meaning, colour
-- only follows.
function M.blocker_badge(resolver, class)
	if not resolver and not class then
		return nil
	end
	local prefix = class and class .. " · " or ""
	if resolver == "lead" then
		return prefix .. "resolvable by: lead"
	end
	return prefix .. "needs: human"
end

-- Rich derivation for one plan path. Every field is safe to render
-- directly: nil-free on the display path (counts may be nil only when
-- the README has no checkboxes at all, rendered as 0/0 by callers).
function M.derive_rich(plan_path)
	local machine = M.derive(plan_path)
	local vocab = VOCAB[machine] or VOCAB.unknown
	local done, total = M.task_counts(plan_path .. "/README.md")
	local snapshot = read_json(plan_path .. "/state.json")
	local blocked, reason, resolver, class = blocked_signal(snapshot)
	local entry = {
		machine = machine,
		label = vocab.label,
		icon = vocab.icon,
		highlight = vocab.highlight,
		tasks_done = done or 0,
		tasks_total = total or 0,
		percent = (total and total > 0) and math.floor((done / total) * 100 + 0.5) or 0,
		blocked = blocked,
		blocker_reason = reason,
		blocker_resolver = resolver,
		blocker_class = class,
		current_task = current_task(machine, snapshot, plan_path),
		title = M.resolve_title(plan_path),
	}
	if machine == "in-flight" and blocked then
		entry.label = "Needs attention"
		entry.icon = "⚠"
		entry.highlight = "WarningMsg"
	end
	return entry
end

return M
