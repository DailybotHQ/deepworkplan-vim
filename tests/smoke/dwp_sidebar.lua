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
ok(text:find("▰▰▰▱▱▱▱▱ 40%", 1, true) ~= nil, "running row carries the bar and percent (F-01)")
ok(text:find("33%", 1, true) ~= nil, "draft percent renders (33%)")
ok(text:find("100%", 1, true) ~= nil, "done percent renders (100%)")
ok(text:find("couldn't read this plan", 1, true) ~= nil, "corrupt plan explains itself (F-05)")
ok(text:find("ask your agent to check it", 1, true) ~= nil, "corrupt plan points at the action (F-05)")

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

-- 10. Empty state teaches where plans are searched (F-02), fitting the
--     narrowest sidebar width.
local empty_root = vim.fn.tempname()
vim.fn.mkdir(empty_root, "p")
sidebar.open({ empty_root })
text = buf_text()
ok(text:find("No plans yet.", 1, true) ~= nil, "empty state: headline")
ok(text:find("Ask your agent to plan work.", 1, true) ~= nil, "empty state: action line")
ok(text:find(".dwp/plans", 1, true) ~= nil, "empty state: names where it searched")
ok(text:find("config folder", 1, true) ~= nil, "empty state: names the second root")
sidebar.close()

-- 9. Side and width from vim.g.dwp_plans_side / vim.g.dwp_plans_width (set from
--    dwpvim.json by lua/userconfig.lua; the sidebar never requires that module).
local function open_win()
	sidebar.open({ FIXTURES })
	return vim.fn.bufwinid(sidebar_buf())
end
local function close_it()
	sidebar.close()
	vim.g.dwp_plans_side, vim.g.dwp_plans_width = nil, nil
end
local win = open_win()
ok(vim.api.nvim_win_get_position(win)[2] == 0, "default: the sidebar docks on the left")
close_it()

vim.g.dwp_plans_side, vim.g.dwp_plans_width = "right", 30
win = open_win()
ok(vim.api.nvim_win_get_position(win)[2] > 0, "side = right: the sidebar docks on the right edge")
ok(vim.api.nvim_win_get_width(win) == 30, "width = 30 is honoured when the terminal has room")
close_it()

vim.g.dwp_plans_side, vim.g.dwp_plans_width = "left", 60
win = open_win()
ok(vim.api.nvim_win_get_width(win) <= 60, "a configured width is a ceiling")
ok(vim.api.nvim_win_get_width(win) < 60, "the responsive rule still shrinks it on a narrow terminal (80 columns)")
close_it()

local saved_columns = vim.o.columns
vim.o.columns = 200
vim.g.dwp_plans_side, vim.g.dwp_plans_width = "left", 100
win = open_win()
ok(vim.api.nvim_win_get_width(win) == 100, "a wide terminal gets the full configured width (100)")
ok(vim.api.nvim_win_get_position(win)[2] == 0, "and it stays on the left")
close_it()
vim.o.columns = saved_columns

vim.g.dwp_plans_side, vim.g.dwp_plans_width = "sideways", "wide"
win = open_win()
ok(vim.api.nvim_win_get_position(win)[2] == 0, "an unknown side falls back to the left")
ok(vim.api.nvim_win_get_width(win) >= 34, "a non-numeric width falls back to the default layout")
close_it()

-- 10. A quiet window (UX_AUDIT F1, F7, F8): no list noise, a fixed width and
--     silent edit keys on the read-only buffer.
vim.o.list = true -- the editor's global setting the window must not inherit
sidebar.open({ FIXTURES })
local qwin = vim.fn.bufwinid(sidebar_buf())
ok(vim.wo[qwin].list == false, "the sidebar window has list off even when the editor sets it globally")
ok(vim.wo[qwin].winfixwidth == true, "the sidebar width is fixed (a neighbouring sidebar cannot stretch it)")
ok(vim.wo[qwin].spell == false and vim.wo[qwin].colorcolumn == "" and vim.wo[qwin].foldcolumn == "0", "no spell, colorcolumn or fold column")
local function bufmap(lhs)
	for _, m in ipairs(vim.api.nvim_buf_get_keymap(sidebar_buf(), "n")) do
		if m.lhs == lhs then
			return m
		end
	end
end
for _, key in ipairs({ "i", "a", "o", "x", "d", "p", "u" }) do
	local m = bufmap(key)
	ok(m ~= nil and (m.rhs == "<Nop>" or m.rhs == ""), "edit key '" .. key .. "' is a silent no-op in the sidebar")
end
vim.o.list = false
sidebar.close()

if fails > 0 then
	print(("SIDEBAR SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("SIDEBAR SMOKE: %d assertions OK"):format(count))
end
