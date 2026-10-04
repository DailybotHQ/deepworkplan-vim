-- Reader smoke: the comprehension surface, proven headlessly against
-- the running (v6-shaped) and draft fixtures — rendered title, goal
-- sentence, status badge, progress figures, task checklist with the
-- current task marked, jump lines resolving to real files, read-only
-- buffer, clean close, and the sidebar Enter wiring. Run via
-- tests/smoke/run.sh.

local reader = require("dwp.reader")
local plans = require("dwp.plans")

local FIXTURES = vim.uv.cwd() .. "/tests/fixtures/dwp_plans"

local count, fails = 0, 0

local function ok(cond, msg)
	count = count + 1
	if not cond then
		fails = fails + 1
		print("FAIL: " .. msg)
	end
end

local function record_for(name)
	for _, rec in ipairs(plans.scan({ FIXTURES })) do
		if rec.name == name then
			return rec
		end
	end
	ok(false, "fixture " .. name .. " found by scan")
	return nil
end

local function reader_buf()
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[b].buftype == "nofile" and vim.bo[b].filetype == "dwp-plan" then
			return b
		end
	end
	return -1
end

local function reader_text()
	local b = reader_buf()
	if b < 0 then
		return ""
	end
	return table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
end

-- 1. The v6-shaped running fixture renders completely.
local running = record_for("PLAN_991_fixture_running")
ok(running ~= nil, "running record present")
local buf = reader.open(running)
ok(buf and vim.api.nvim_buf_is_valid(buf), "reader buffer opens")
ok(vim.bo[buf].modifiable == false, "reader buffer is nomodifiable")
ok(vim.bo[buf].buflisted == false, "reader buffer is unlisted")
local text = reader_text()
ok(text:find("Fixture running plan", 1, true) ~= nil, "title renders")
ok(text:find("Working", 1, true) ~= nil, "status word renders")
ok(text:find("▰▰▰▰▱▱▱▱▱▱ 2/5 · 40%%", 1, false) ~= nil, "progress bar, counts and percent render")
ok(text:find("What this plan is about", 1, true) ~= nil, "goal section header renders")
ok(text:find("Exercise every rich%-status derivation path", 1) ~= nil, "goal sentence renders from README")
ok(text:find("✓ Collect requirements", 1, true) ~= nil, "completed task renders")
ok(text:find("▸ Draft the design  ← working on this now", 1, true) ~= nil, "current task marked with phrasing")
ok(text:find("○ Implement the change", 1, true) ~= nil, "pending task renders")
ok(text:find("/dwp%-status PLAN_991_fixture_running", 1) ~= nil, "resume one-liner renders")

-- 2. Jump lines resolve to existing files.
local jumps = 0
for _, row in ipairs(reader.rows()) do
	if row.kind == "jump" and row.file then
		jumps = jumps + 1
		ok(vim.uv.fs_stat(row.file) ~= nil, "jump file exists: " .. row.file)
	end
end
ok(jumps >= 3, "at least three jump lines rendered (got " .. jumps .. ")")
ok(text:find("README.md", 1, true) ~= nil and text:find("the plan itself", 1, true) ~= nil, "README jump line carries its plain description")

-- 3. The blocked fixture renders the attention line with the reason.
local blocked = record_for("PLAN_993_fixture_blocked")
reader.open(blocked)
text = reader_text()
ok(text:find("⚠ Needs attention — waiting for design review", 1, true) ~= nil, "blocked line renders with reason")

-- 4. The draft-only fixture renders gracefully (no manifest, no state).
local draft = record_for("PLAN_990_fixture_draft")
reader.open(draft)
text = reader_text()
ok(text:find("Fixture draft plan", 1, true) ~= nil, "draft title renders")
ok(text:find("Not started", 1, true) ~= nil, "draft status word renders")
ok(text:find("README.md", 1, true) ~= nil, "draft still offers its README")
ok(not text:find("journal%.ndjson", 1), "draft offers no journal (it has none)")

-- 5. The corrupt fixture renders as Unknown without erroring.
local corrupt = record_for("PLAN_994_fixture_corrupt")
reader.open(corrupt)
text = reader_text()
ok(text:find("Unknown", 1, true) ~= nil, "corrupt renders Unknown")
ok(text:find("Fixture corrupt plan", 1, true) ~= nil, "corrupt title still renders")

-- 6. Close: bdelete leaves no reader buffer behind.
reader.open(running)
vim.cmd("bdelete")
ok(reader_buf() == -1, "bdelete removes the reader buffer (bufhidden=wipe)")

-- 7. Sidebar Enter is wired to the reader (the Task-3 interim is gone).
local sidebar = require("dwp.sidebar")
sidebar.open({ FIXTURES })
-- Put the cursor on the running plan's row, then press Enter.
local sbuf
for _, w in ipairs(vim.api.nvim_list_wins()) do
	local b = vim.api.nvim_win_get_buf(w)
	if vim.bo[b].filetype == "dwp-plans" then
		sbuf = b
		break
	end
end
ok(sbuf ~= nil, "sidebar open for the Enter wiring check")
local lines = vim.api.nvim_buf_get_lines(sbuf, 0, -1, false)
local plan_line = 0
for i, line in ipairs(lines) do
	if line:find("Fixture running plan", 1, true) then
		plan_line = i
		break
	end
end
ok(plan_line > 0, "running plan row found in sidebar")
if plan_line > 0 then
	local swin
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(w) == sbuf then
			swin = w
		end
	end
	vim.api.nvim_set_current_win(swin)
	vim.api.nvim_win_set_cursor(swin, { plan_line, 0 })
	-- Invoke the buffer-local Enter mapping directly: deterministic in a
	-- headless script (nvim_input is async and may not flush mid-script).
	local enter = vim.fn.maparg("<CR>", "n", false, true)
	ok(type(enter) == "table" and type(enter.callback) == "function", "sidebar Enter mapping resolves")
	if type(enter) == "table" and type(enter.callback) == "function" then
		enter.callback()
		local opened = false
		for _, b in ipairs(vim.api.nvim_list_bufs()) do
			if vim.bo[b].filetype == "dwp-plan" and vim.api.nvim_buf_is_valid(b) then
				opened = true
			end
		end
		ok(opened, "sidebar Enter opens the reader (interim README target replaced)")
		pcall(vim.cmd, "bdelete")
	end
end
sidebar.close()

if fails > 0 then
	print(("READER SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("READER SMOKE: %d assertions OK"):format(count))
end
