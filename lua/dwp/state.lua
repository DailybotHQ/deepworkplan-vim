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
local function blocked_signal(snapshot)
	if type(snapshot) ~= "table" then
		return false, nil
	end
	local raw = snapshot.blocker or snapshot.blocked
	-- JSON null decodes to vim.NIL, not Lua nil — both mean "no blocker".
	if raw == nil or raw == vim.NIL or raw == false or raw == "" then
		return false, nil
	end
	local reason
	if type(raw) == "string" then
		reason = raw
	elseif type(raw) == "table" then
		for _, key in ipairs({ "reason", "detail", "note", "message" }) do
			if type(raw[key]) == "string" and raw[key] ~= "" then
				reason = raw[key]
				break
			end
		end
	end
	return true, reason
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

-- Rich derivation for one plan path. Every field is safe to render
-- directly: nil-free on the display path (counts may be nil only when
-- the README has no checkboxes at all, rendered as 0/0 by callers).
function M.derive_rich(plan_path)
	local machine = M.derive(plan_path)
	local vocab = VOCAB[machine] or VOCAB.unknown
	local done, total = M.task_counts(plan_path .. "/README.md")
	local snapshot = read_json(plan_path .. "/state.json")
	local blocked, reason = blocked_signal(snapshot)
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
