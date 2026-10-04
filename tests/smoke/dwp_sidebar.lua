-- Sidebar smoke: the single plan surface, proven headlessly against the
-- fixtures — open, rendered rows, expand to tasks and files, toggle
-- closed and reopened, the mapping and command resolve to the sidebar,
-- buffer-local keys exist, and the help overlay opens. Run via
-- tests/smoke/run.sh.

local sidebar = require("dwp.sidebar")

local FIXTURES = vim.uv.cwd() .. "/tests/fixtures/dwp_plans"

local count, fails = 0, 0

local function ok(cond, msg)
	count = count + 1
	if not cond then
		fails = fails + 1
		print("FAIL: " .. msg)
	end
end

-- The sidebar keeps its state private; the smoke reaches the buffer
-- through the window list (filetype is the stable public marker).
local function sidebar_buf()
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(w)
		if vim.bo[buf].filetype == "dwp-plans" then
			return buf
		end
	end
	return -1
end

local function buf_text()
	local buf = sidebar_buf()
	if buf < 0 then
		return ""
	end
	return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

-- 1. Open against the fixtures.
sidebar.open({ FIXTURES })
ok(sidebar.is_open(), "sidebar opens")
local buf = sidebar_buf()
ok(buf > 0, "sidebar buffer exists (filetype dwp-plans)")
local text = buf_text()

-- 2. Rendered rows: sections, icons, titles, plain-language status,
--    progress bar and counts.
ok(text:find("Plans", 1, true) ~= nil, "header renders")
ok(text:find("Working", 1, true) ~= nil, "Working section renders")
ok(text:find("Needs attention", 1, true) ~= nil, "Needs attention section renders")
ok(text:find("Not started", 1, true) ~= nil, "Not started section renders")
ok(text:find("Done", 1, true) ~= nil, "Done section renders")
ok(text:find("Fixture running plan", 1, true) ~= nil, "running plan title renders")
ok(text:find("Fixture draft plan", 1, true) ~= nil, "draft plan title renders")
ok(text:find("Fixture corrupt plan", 1, true) ~= nil, "corrupt plan still listed")
ok(text:find("▰▰▰▱▱▱▱▱ 2/5", 1, true) ~= nil, "running progress bar renders (2/5)")
ok(text:find("1/3", 1, true) ~= nil, "draft counts render (1/3)")
ok(text:find("5/5", 1, true) ~= nil, "done counts render (5/5)")

-- 3. Expand: task checklist (with current marker) and file groups.
sidebar.toggle_expand("PLAN_991_fixture_running")
text = buf_text()
ok(text:find("✓ Collect requirements", 1, true) ~= nil, "completed task renders with ✓")
ok(text:find("▸ Draft the design", 1, true) ~= nil, "current task renders with ▸")
ok(text:find("○ Implement the change", 1, true) ~= nil, "pending task renders with ○")
ok(text:find("Files", 1, true) ~= nil, "files group header renders")
ok(text:find("README.md", 1, true) ~= nil, "file rows render")
sidebar.toggle_expand("PLAN_991_fixture_running")
text = buf_text()
ok(text:find("✓ Collect requirements", 1, true) == nil, "collapse hides the checklist")

-- 4. Toggle closed and reopened.
sidebar.toggle()
ok(not sidebar.is_open(), "toggle closes the sidebar")
sidebar.toggle()
ok(sidebar.is_open(), "toggle reopens the sidebar")
text = buf_text()
ok(text:find("Fixture running plan", 1, true) ~= nil, "reopened sidebar still renders plans")

-- 5. Buffer-local keys exist (re-fetch: close() wiped the first buffer).
buf = sidebar_buf()
local names = {}
for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
	names[m.lhs] = true
end
for _, key in ipairs({ "<CR>", "<Tab>", "r", "?", "q", "<LeftMouse>", "<2-LeftMouse>" }) do
	ok(names[key] ~= nil, "buffer-local key " .. key .. " set")
end

-- 6. Help overlay opens and closes.
sidebar.help()
local help_open = false
for _, w in ipairs(vim.api.nvim_list_wins()) do
	local b = vim.api.nvim_win_get_buf(w)
	for _, line in ipairs(vim.api.nvim_buf_get_lines(b, 0, 1, false)) do
		if line:find("Plans sidebar", 1, true) then
			help_open = true
		end
	end
end
ok(help_open, "help overlay opens")
sidebar.close_help()

-- 7. Mapping and command resolve to the sidebar. The mapping file is
-- loaded the way init.lua loads it: leader set first, then the mappings.
vim.g.mapleader = " "
require("mapping.navigation")
local arg = vim.fn.maparg("<Space>P", "n", false, true)
ok(type(arg) == "table" and arg.callback ~= nil, "<leader>P is mapped to a callback")
ok(arg.desc == "Plan browser (sidebar)", "<leader>P desc carries the plan browser phrase")
ok(vim.fn.exists(":DwpPlans") == 2, ":DwpPlans command exists")

-- 8. Section collapse is a round trip, not a one-way trap: Enter on a
-- section header keeps the header (with a hidden count) so the group
-- can come back (final-review finding 1).
sidebar.open({ FIXTURES })
buf = nil
for _, w in ipairs(vim.api.nvim_list_wins()) do
	local b = vim.api.nvim_win_get_buf(w)
	if vim.bo[b].filetype == "dwp-plans" then
		buf = b
	end
end
local enter_map
for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
	if m.lhs == "<CR>" then
		enter_map = m
	end
end
ok(enter_map ~= nil and enter_map.callback ~= nil, "sidebar Enter resolves for the collapse round trip")
local function sidebar_lines()
	return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end
local function cursor_to(pattern)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	for i, line in ipairs(lines) do
		if line:find(pattern, 1, true) then
			for _, w in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_buf(w) == buf then
					vim.api.nvim_win_set_cursor(w, { i, 0 })
				end
			end
			return i
		end
	end
	return 0
end
ok(cursor_to("Working") > 0, "Working header present before collapse")
-- The blocked sibling (Needs attention) shares this title, so count
-- occurrences: two plan rows before, one after collapsing Working.
local _, before = sidebar_lines():gsub("Fixture running plan", "")
local working_line = cursor_to("Working")
enter_map.callback()
local collapsed = sidebar_lines()
local _, after = collapsed:gsub("Fixture running plan", "")
ok(collapsed:find("Working ▸ 1 hidden", 1, true) ~= nil, "collapsed header stays with a hidden count")
ok(after == before - 1, "collapsed section hides its plan rows (one fewer row)")
ok(vim.api.nvim_buf_get_lines(buf, working_line - 1, working_line, false)[1]:find("Working", 1, true) ~= nil, "the header row itself survives Enter")
cursor_to("Working ▸ 1 hidden")
enter_map.callback()
local restored = sidebar_lines()
local _, after_restore = restored:gsub("Fixture running plan", "")
ok(after_restore == before, "Enter again restores the group (round trip)")

sidebar.close()
ok(not sidebar.is_open(), "close() closes the sidebar")

if fails > 0 then
	print(("SIDEBAR SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("SIDEBAR SMOKE: %d assertions OK"):format(count))
end
