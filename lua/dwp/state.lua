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

return M
