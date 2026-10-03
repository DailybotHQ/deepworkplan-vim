-- Plan discovery: the folders under .dwp/plans are the source of truth —
-- there is no registry to trust, so none is read. Two roots are scanned:
-- the working directory's .dwp/plans (the repo being piloted) and the
-- config directory's .dwp/plans (the editor's own plans when the config
-- is not the working directory), deduped by path.

local state = require("dwp.state")

local M = {}

local function scandir(path)
	local handle = vim.uv.fs_scandir(path)
	if not handle then
		return {}
	end
	local names = {}
	while true do
		local name = vim.uv.fs_scandir_next(handle)
		if not name then
			break
		end
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- Task progress from the README's own checkboxes — the human surface, so
-- it is advisory (the journal-derived state stays authoritative).
local function task_counts(readme_path)
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

-- Which well-known artifacts exist. The browser's second level lists
-- exactly these plus the numbered task files.
M.ARTIFACTS = {
	"README.md",
	"manifest.json",
	"contract.json",
	"journal.ndjson",
	"state.json",
	"ORCHESTRATOR_MANIFEST.md",
	"PROGRESS.md",
	"PROMPTS.md",
}

local function artifact_set(plan_path)
	local present = {}
	for _, name in ipairs(M.ARTIFACTS) do
		present[name] = vim.uv.fs_stat(plan_path .. "/" .. name) ~= nil
	end
	return present
end

function M.default_roots()
	local roots = {}
	local cwd = vim.uv.cwd() or "."
	roots[#roots + 1] = cwd .. "/.dwp/plans"
	local config = vim.fn.stdpath("config")
	if config and config ~= cwd then
		roots[#roots + 1] = config .. "/.dwp/plans"
	end
	return roots
end

-- Scan one or more plan roots. Returns plan records sorted newest first:
--   { name, path, state, tasks_done, tasks_total, artifacts, mtime }
function M.scan(roots)
	roots = roots or M.default_roots()
	local seen, out = {}, {}
	for _, root in ipairs(roots) do
		for _, name in ipairs(scandir(root)) do
			local path = root .. "/" .. name
			local stat = vim.uv.fs_stat(path)
			if name:match("^PLAN_") and stat and stat.type == "directory" and not seen[path] then
				seen[path] = true
				local done, total = task_counts(path .. "/README.md")
				out[#out + 1] = {
					name = name,
					path = path,
					state = state.derive(path),
					tasks_done = done,
					tasks_total = total,
					artifacts = artifact_set(path),
					mtime = os.date("%Y-%m-%d", stat.mtime.sec),
				}
			end
		end
	end
	table.sort(out, function(a, b)
		if a.mtime == b.mtime then
			return a.name < b.name
		end
		return a.mtime > b.mtime
	end)
	return out
end

-- The files a plan offers for browsing, grouped for the panel's second
-- level: the plan surface, the numbered tasks, the ledger records, and
-- the analysis evidence. Only files that exist are listed.
function M.file_groups(plan_path)
	local groups = {}

	local plan_names = { "README.md", "PROGRESS.md", "PROMPTS.md", "ORCHESTRATOR_MANIFEST.md" }
	local plan_files = {}
	for _, name in ipairs(plan_names) do
		if vim.uv.fs_stat(plan_path .. "/" .. name) then
			plan_files[#plan_files + 1] = name
		end
	end
	if #plan_files > 0 then
		groups[#groups + 1] = { title = "Plan", files = plan_files }
	end

	local task_files = {}
	for _, name in ipairs(scandir(plan_path)) do
		if name:match("^%d+%.task_") then
			task_files[#task_files + 1] = name
		end
	end
	table.sort(task_files, function(a, b)
		return tonumber(a:match("^(%d+)")) < tonumber(b:match("^(%d+)"))
	end)
	if #task_files > 0 then
		groups[#groups + 1] = { title = "Tasks", files = task_files }
	end

	local record_names = { "manifest.json", "contract.json", "journal.ndjson", "state.json", "evidence.jsonl" }
	local record_files = {}
	for _, name in ipairs(record_names) do
		if vim.uv.fs_stat(plan_path .. "/" .. name) then
			record_files[#record_files + 1] = name
		end
	end
	for _, name in ipairs(scandir(plan_path .. "/contracts")) do
		if name:match("%.json$") then
			record_files[#record_files + 1] = "contracts/" .. name
		end
	end
	if #record_files > 0 then
		groups[#groups + 1] = { title = "Records", files = record_files }
	end

	local evidence_files = {}
	for _, name in ipairs(scandir(plan_path .. "/analysis_results")) do
		evidence_files[#evidence_files + 1] = "analysis_results/" .. name
	end
	if #evidence_files > 0 then
		groups[#groups + 1] = { title = "Evidence", files = evidence_files }
	end

	return groups
end

return M
