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

-- 11. The sidebar announces itself (lua/setUp/sidebars.lua listens and may close
--     a competing sidebar; lua/dwp never requires a plugin).
local announced = 0
local aug = vim.api.nvim_create_augroup("SmokeSidebarEvent", { clear = true })
vim.api.nvim_create_autocmd("User", { group = aug, pattern = "DwpPlansOpened", callback = function() announced = announced + 1 end })
sidebar.open({ FIXTURES })
ok(announced == 1, "opening the sidebar fires User DwpPlansOpened once")
sidebar.open({ FIXTURES })
ok(announced == 1, "focusing an already-open sidebar does not announce again")
sidebar.close()
sidebar.toggle()
ok(announced == 2, "reopening through toggle announces again")
sidebar.close()
vim.api.nvim_del_augroup_by_name("SmokeSidebarEvent")

-- 12. Visual hierarchy (UX_AUDIT F2, F3, F4, F5, F9, F10). The row text is
--     unchanged; hierarchy lives in highlights and virtual lines.
local NSID = vim.api.nvim_get_namespaces()["dwp-sidebar"]
sidebar.open({ FIXTURES })
local hwin = vim.fn.bufwinid(sidebar_buf())
local hbuf = sidebar_buf()
local htext = table.concat(vim.api.nvim_buf_get_lines(hbuf, 0, -1, false), "\n")
local first_line = vim.api.nvim_buf_get_lines(hbuf, 0, 1, false)[1]
ok(first_line:find("Plans", 1, true) == 1 and first_line:find("1 working", 1, true) ~= nil, "the header carries a summary of what is live")
ok(htext:find("Working · 1", 1, true) ~= nil, "an expanded section header carries its count")
ok(vim.api.nvim_get_hl(0, { name = "DwpPlansHeader" }).bold == true, "the header group is bold (derived from the theme, not a fixed colour)")
ok(vim.api.nvim_get_hl(0, { name = "DwpPlansDim" }).italic ~= true, "the dim group is not italic")

local function groups_on_line(pattern)
	local lines = vim.api.nvim_buf_get_lines(hbuf, 0, -1, false)
	for i, line in ipairs(lines) do
		if line:find(pattern, 1, true) then
			local set = {}
			for _, m in ipairs(vim.api.nvim_buf_get_extmarks(hbuf, NSID, { i - 1, 0 }, { i - 1, -1 }, { details = true })) do
				if m[4].hl_group then
					set[m[4].hl_group] = true
				end
			end
			return set
		end
	end
	return {}
end
local running = groups_on_line("Fixture running plan")
local done = groups_on_line("Fixture done plan")
ok(running.DwpPlansTitle == true and running.MoreMsg == true, "a live plan: strong title and its status colour on icon and bar")
ok(done.DwpPlansDim == true and done.DwpPlansTitle ~= true, "a settled plan recedes: dim title, no strong title")
ok(running.DwpPlansDim == true, "the percent and the empty bar cells are dim")

local vlines = 0
for _, m in ipairs(vim.api.nvim_buf_get_extmarks(hbuf, NSID, 0, -1, { details = true })) do
	vlines = vlines + (m[4].virt_lines and #m[4].virt_lines or 0)
end
ok(vlines == 2, "two thin virtual rules: under the header and above the footer (no buffer text added)")
sidebar.close()

-- Done opens collapsed when it holds more than six plans, and stays under the
-- user's control afterwards.
local many = vim.fn.tempname()
for i = 1, 8 do
	local d = string.format("%s/PLAN_%03d_finished_%d", many, 900 + i, i)
	vim.fn.mkdir(many, "p")
	vim.fn.system({ "cp", "-R", FIXTURES .. "/PLAN_992_fixture_done", d })
end
sidebar.open({ many })
local dbuf = sidebar_buf()
local function dtext()
	return table.concat(vim.api.nvim_buf_get_lines(dbuf, 0, -1, false), "\n")
end
ok(dtext():find("Done ▸ 8 hidden", 1, true) ~= nil, "a Done group of eight opens collapsed with its count")
local before_rows = #vim.api.nvim_buf_get_lines(dbuf, 0, -1, false)
local enter
for _, m in ipairs(vim.api.nvim_buf_get_keymap(dbuf, "n")) do
	if m.lhs == "<CR>" then
		enter = m
	end
end
for i, line in ipairs(vim.api.nvim_buf_get_lines(dbuf, 0, -1, false)) do
	if line:find("Done ▸ 8 hidden", 1, true) then
		vim.api.nvim_win_set_cursor(vim.fn.bufwinid(dbuf), { i, 0 })
	end
end
enter.callback()
ok(dtext():find("Done · 8", 1, true) ~= nil and #vim.api.nvim_buf_get_lines(dbuf, 0, -1, false) > before_rows, "Enter on the header expands it")
sidebar.refresh()
ok(dtext():find("Done · 8", 1, true) ~= nil, "the user's choice sticks across a refresh (no re-collapse)")
sidebar.close()
vim.fn.delete(many, "rf")

-- Titles use the room the window has: a 70-column sidebar shows more of a long
-- title than the default 48-column one (cap 28 -> up to 44).
local HOSTILE_ROOT = vim.uv.cwd() .. "/tests/fixtures/dwp_render"
local function widest_title_row(width)
	vim.g.dwp_plans_width = width
	vim.o.columns = 200
	sidebar.open({ HOSTILE_ROOT })
	local lines = vim.api.nvim_buf_get_lines(sidebar_buf(), 0, -1, false)
	local best = 0
	for _, line in ipairs(lines) do
		if line:find("▸▰", 1, true) or line:find("▸▱", 1, true) then
			local head = line:match("^(.-)  [▸▾]") or line
			best = math.max(best, vim.fn.strdisplaywidth(head))
		end
	end
	sidebar.close()
	vim.g.dwp_plans_width = nil
	return best
end
local narrow_w, wide_w = widest_title_row(48), widest_title_row(70)
ok(wide_w > narrow_w, "a wider window shows more of a long title (" .. narrow_w .. " -> " .. wide_w .. " cells)")
vim.o.columns = 80

-- 13. Mouse: a click acts on the row under the POINTER (a mapped <LeftMouse>
--     does not move the cursor, so the cursor's old row is the wrong one).
local real_getmousepos = vim.fn.getmousepos
local function click_on(pattern, wincol)
	sidebar.open({ FIXTURES })
	local cbuf = sidebar_buf()
	local cwin = vim.fn.bufwinid(cbuf)
	local target
	for i, line in ipairs(vim.api.nvim_buf_get_lines(cbuf, 0, -1, false)) do
		if line:find(pattern, 1, true) then
			target = i
		end
	end
	-- Park the cursor on line 1: the old behaviour would act on THIS row.
	vim.api.nvim_win_set_cursor(cwin, { 1, 0 })
	vim.fn.getmousepos = function()
		return { winid = cwin, line = target or 1, wincol = wincol or 3, column = 1, screenrow = 1, screencol = 1, winrow = target or 1 }
	end
	local map
	for _, m in ipairs(vim.api.nvim_buf_get_keymap(cbuf, "n")) do
		if m.lhs == "<LeftMouse>" then
			map = m
		end
	end
	map.callback()
	vim.fn.getmousepos = real_getmousepos
	return cbuf, cwin, target
end
local function reader_open()
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "dwp-plan" then
			return vim.api.nvim_win_get_buf(w)
		end
	end
end
local function close_reader()
	local rb = reader_open()
	if rb then
		pcall(vim.cmd, "bdelete " .. rb)
	end
end

-- 13a. a click on a plan (title area) opens the reader for THAT plan
local cbuf, cwin, target = click_on("Fixture running plan", 6)
local rb = reader_open()
ok(rb ~= nil, "a click on a plan row opens the reader")
ok(rb ~= nil and table.concat(vim.api.nvim_buf_get_lines(rb, 0, -1, false), "\n"):find("Fixture running plan", 1, true) ~= nil, "it opens the plan under the pointer, not the cursor's old row")
close_reader()
sidebar.close()

-- 13b. a click on the expand marker toggles the checklist instead
sidebar.open({ FIXTURES })
local mrow
for _, row in ipairs({}) do end
local rows_before = #vim.api.nvim_buf_get_lines(sidebar_buf(), 0, -1, false)
local line_of
for i, line in ipairs(vim.api.nvim_buf_get_lines(sidebar_buf(), 0, -1, false)) do
	if line:find("Fixture running plan", 1, true) then
		line_of = i
	end
end
local text_line = vim.api.nvim_buf_get_lines(sidebar_buf(), line_of - 1, line_of, false)[1]
local marker_byte = text_line:find("▸", 1, true)
local marker_wincol = vim.fn.strdisplaywidth(text_line:sub(1, marker_byte - 1)) + 1
sidebar.close()
click_on("Fixture running plan", marker_wincol)
ok(reader_open() == nil, "a click on the marker does not open the reader")
ok(#vim.api.nvim_buf_get_lines(sidebar_buf(), 0, -1, false) > rows_before, "it shows the plan's tasks (more rows)")
sidebar.close()

-- 13c. a click on a section header shows or hides the group
click_on("Working · 1", 3)
ok(table.concat(vim.api.nvim_buf_get_lines(sidebar_buf(), 0, -1, false), "\n"):find("Working ▸ 1 hidden", 1, true) ~= nil, "a click on a section header collapses the group")
click_on("Working ▸ 1 hidden", 3)
ok(table.concat(vim.api.nvim_buf_get_lines(sidebar_buf(), 0, -1, false), "\n"):find("Working · 1", 1, true) ~= nil, "and a second click brings it back")
sidebar.close()

-- 13e. opening a SECOND plan while the reader shows the first replaces the
--      reader, never the sidebar, and the sidebar keeps the focus for the click.
sidebar.open({ FIXTURES })
local function click_nth_plan(n)
	local sbuf = sidebar_buf()
	local swin = vim.fn.bufwinid(sbuf)
	local seen = 0
	local tline
	for i, line in ipairs(vim.api.nvim_buf_get_lines(sbuf, 0, -1, false)) do
		if line:find("▸[▰▱]") then
			seen = seen + 1
			if seen == n then
				tline = i
			end
		end
	end
	vim.fn.getmousepos = function()
		return { winid = swin, line = tline, wincol = 6, column = 1 }
	end
	require("dwp.mouse").click()
	vim.fn.getmousepos = real_getmousepos
end
click_nth_plan(1)
click_nth_plan(2)
local filetypes = {}
for _, w in ipairs(vim.api.nvim_list_wins()) do
	filetypes[#filetypes + 1] = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
end
ok(vim.tbl_contains(filetypes, "dwp-plans"), "after a second click the sidebar is still there (" .. table.concat(filetypes, ",") .. ")")
ok(vim.tbl_contains(filetypes, "dwp-plan"), "and the reader shows the second plan")
ok(vim.bo[vim.api.nvim_get_current_buf()].filetype == "dwp-plans", "the focus returns to the sidebar after a click")
close_reader()
sidebar.close()

-- 13d. a click in another window is ignored, the double-click is a no-op
sidebar.open({ FIXTURES })
local dbuf = sidebar_buf()
vim.fn.getmousepos = function()
	return { winid = 0, line = 3, wincol = 3 }
end
local ok_click = pcall(function()
	for _, m in ipairs(vim.api.nvim_buf_get_keymap(dbuf, "n")) do
		if m.lhs == "<LeftMouse>" then
			m.callback()
		end
	end
end)
vim.fn.getmousepos = real_getmousepos
ok(ok_click and reader_open() == nil, "a click that lands in another window does nothing (and does not error)")
local dbl
for _, m in ipairs(vim.api.nvim_buf_get_keymap(dbuf, "n")) do
	if m.lhs == "<2-LeftMouse>" then
		dbl = m
	end
end
ok(dbl ~= nil and dbl.callback ~= nil, "the second click of a double-click is routed (never Vim's word selection)")
for _, lhs in ipairs({ "<3-LeftMouse>", "<4-LeftMouse>" }) do
	local found
	for _, m in ipairs(vim.api.nvim_buf_get_keymap(dbuf, "n")) do
		if m.lhs:lower() == lhs:lower() then
			found = m
		end
	end
	ok(found ~= nil, lhs .. " is routed too")
end
sidebar.close()

-- 14. Keyboard: j/k (and the arrows, Ctrl-n/Ctrl-p) jump between selectable rows
--     — plans, section headers, tasks, files — and skip blanks, rules and the footer.
sidebar.open({ FIXTURES })
local kbuf = sidebar_buf()
local kwin = vim.fn.bufwinid(kbuf)
vim.api.nvim_set_current_win(kwin)
local function klines()
	return vim.api.nvim_buf_get_lines(kbuf, 0, -1, false)
end
local function cur()
	return vim.api.nvim_win_get_cursor(kwin)[1]
end
local function cur_text()
	return klines()[cur()]
end
local function selectable(text)
	return text ~= "" and not text:find("^Plans") and not text:find("^%?") and not text:find("^click a plan")
end
ok(cur_text():find("▸", 1, true) ~= nil, "the sidebar opens with the cursor on a plan, not on the title")
local seen = { cur() }
for _ = 1, 40 do
	local before = cur()
	vim.cmd("normal j")
	if cur() == before then
		break
	end
	seen[#seen + 1] = cur()
	ok(selectable(cur_text()), "j lands on a selectable row (line " .. cur() .. ": '" .. cur_text():sub(1, 24) .. "')")
end
ok(#seen >= 4, "j visits several rows on the way down (" .. #seen .. ")")
local last = cur()
vim.cmd("normal j")
ok(cur() == last, "j stops at the last selectable row (no wrap onto the footer)")
vim.cmd("normal gg")
local first = cur()
ok(cur_text():find("^Working") ~= nil or cur_text():find("▸", 1, true) ~= nil, "gg goes to the first selectable row")
vim.cmd("normal k")
ok(cur() == first, "k stops at the first selectable row")
vim.cmd("normal G")
ok(cur() == last, "G goes to the last selectable row")
vim.cmd("normal gg")
vim.cmd("normal 2j")
ok(cur() == seen[1] or cur() > first, "a count moves several rows (2j)")
local two = cur()
vim.cmd("normal gg")
vim.cmd("normal j")
vim.cmd("normal j")
ok(cur() == two, "2j equals j twice")
for _, key in ipairs({ "<Down>", "<C-n>", "<Up>", "<C-p>" }) do
	local m
	for _, km in ipairs(vim.api.nvim_buf_get_keymap(kbuf, "n")) do
		if km.lhs:lower() == key:lower() then -- Neovim reports <C-N> for <C-n>
			m = km
		end
	end
	ok(m ~= nil and m.callback ~= nil, key .. " is mapped to the same row navigation")
end
sidebar.close()

if fails > 0 then
	print(("SIDEBAR SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("SIDEBAR SMOKE: %d assertions OK"):format(count))
end
