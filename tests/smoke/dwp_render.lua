-- Render smoke: what the user actually SEES, proven on the screen grid
-- (vim.fn.screenstring) rather than buffer text — sidebar and reader at a
-- width matrix, hostile content (CJK title, unheaded folder name, blocked,
-- empty, many plans), greeter column alignment, statusline width
-- degradation, and resize re-fitting. Run via tests/smoke/run.sh.

local sidebar = require("dwp.sidebar")
local reader = require("dwp.reader")
local greeter = require("dwp.greeter_plans")
local statusline = require("dwp.statusline")
local plans = require("dwp.plans")

local SHARED = vim.uv.cwd() .. "/tests/fixtures/dwp_plans"
local HOSTILE = vim.uv.cwd() .. "/tests/fixtures/dwp_render"

local count, fails = 0, 0
local failures = {}

local function ok(cond, msg)
	count = count + 1
	if not cond then
		fails = fails + 1
		failures[#failures + 1] = msg
	end
end

-- Failure lines are buffered and printed once at the end: a mid-run
-- print lands on the message grid and screenstring reads it back,
-- corrupting every later screen assertion.

local function sidebar_win()
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(w)
		if vim.bo[buf].filetype == "dwp-plans" then
			return w
		end
	end
	return -1
end

-- The sidebar's rendered cells, one string per screen row.
local function screen_lines(win)
	local pos = vim.api.nvim_win_get_position(win)
	local w = vim.api.nvim_win_get_width(win)
	local h = vim.api.nvim_win_get_height(win)
	local out = {}
	for r = 0, h - 1 do
		local cells = {}
		for c = 0, w - 1 do
			cells[#cells + 1] = vim.fn.screenstring(pos[1] + 1 + r, pos[2] + 1 + c)
		end
		out[#out + 1] = table.concat(cells)
	end
	return out
end

local function buf_line_count(win)
	local buf = vim.api.nvim_win_get_buf(win)
	return #vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

-- Open fresh at a terminal size (F-03 made the width responsive).
local function open_at(cols, roots)
	if sidebar.is_open() then
		sidebar.close()
	end
	vim.o.columns = cols
	vim.o.lines = 40
	vim.cmd("redraw")
	sidebar.open(roots)
	vim.cmd("redraw")
	return sidebar_win()
end

-- Every screen row that renders a plan row carries its expand marker at
-- the same DISPLAY column: the bar/counts block is column-aligned (F-07).
-- Byte offsets would lie — icons and ellipses are multibyte — so convert.
local function marker_columns(lines)
	local cols = {}
	for _, line in ipairs(lines) do
		local c = line:find("▸", 1, true)
		if c then
			cols[#cols + 1] = vim.fn.strdisplaywidth(line:sub(1, c - 1)) + 1
		end
	end
	return cols
end

local function all_equal(t)
	for i = 2, #t do
		if t[i] ~= t[1] then
			return false
		end
	end
	return true
end

-- No-wrap proof: the LAST buffer line ("click a plan to expand…")
-- renders exactly at screen row n (n = buffer line count) — any earlier
-- row wrapping onto a second screen line would push it lower.
local function footer_on_expected_row(win, lines)
	local n = buf_line_count(win)
	local row = lines[n]
	return row ~= nil and row:find("click a plan to expand", 1, true) ~= nil, n
end

-- 1. Width matrix: the sidebar is responsive and its rows fit on one
--    screen line at every width, counts complete, block aligned.
local widths = { { 60, 34 }, { 80, 44 }, { 120, 48 } }
for _, case in ipairs(widths) do
	local cols, want = case[1], case[2]
	local win = open_at(cols, { SHARED, HOSTILE })
	local got = vim.api.nvim_win_get_width(win)
	ok(got == want, string.format("columns %d: sidebar width %d (want %d)", cols, got, want))
	local lines = screen_lines(win)

	-- Percent-complete at the row's end, whatever the title cap
	-- truncated at this width: the running plan is the 40% row.
	local running = nil
	for _, line in ipairs(lines) do
		if line:find("40%%%s*$") then
			running = line
			break
		end
	end
	ok(running ~= nil, string.format("columns %d: a plan row ends in its complete percent 40%%", cols))

	local cols_marker = marker_columns(lines)
	ok(#cols_marker >= 4, string.format("columns %d: plan rows carry the expand marker (%d)", cols, #cols_marker))
	ok(all_equal(cols_marker), string.format("columns %d: bar block column-aligned across rows (F-07)", cols))

	local cjk = nil
	for _, line in ipairs(lines) do
		if line:find("深", 1, true) then
			cjk = line
			break
		end
	end
	ok(cjk ~= nil, string.format("columns %d: CJK title row renders", cols))
	ok(cjk and cjk:find("…", 1, true) ~= nil, string.format("columns %d: CJK title truncates with ellipsis", cols))

	-- An unheaded README falls back to the humanized folder-name title
	-- ("Fixture with deliberately …"), which must truncate cleanly.
	local unheaded = nil
	for _, line in ipairs(lines) do
		if line:find("Fixture with", 1, true) then
			unheaded = line
			break
		end
	end
	ok(unheaded ~= nil, string.format("columns %d: unheaded fixture lists (humanized folder title)", cols))
	ok(unheaded and unheaded:find("…", 1, true) ~= nil, string.format("columns %d: long folder name truncates with ellipsis", cols))

	local good, _ = footer_on_expected_row(win, lines)
	ok(good, string.format("columns %d: footer on its expected screen row — no row wrapped or bled", cols))
end

-- 2. Empty state at the narrowest width: the teaching line renders.
do
	local empty_root = vim.fn.tempname()
	vim.fn.mkdir(empty_root, "p")
	local win = open_at(60, { empty_root })
	local lines = screen_lines(win)
	local found = false
	for _, line in ipairs(lines) do
		if line:find("No plans yet", 1, true) then
			found = true
			break
		end
	end
	ok(found, "empty root: 'No plans yet' renders at 60 columns")
	local teaching = false
	for _, line in ipairs(lines) do
		if line:find("Plans are searched", 1, true) then
			teaching = true
			break
		end
	end
	ok(teaching, "empty root: the teaching line naming the searched places renders (F-02)")
end

-- 3. Many plans: eleven synthetic plans all render, block stays aligned,
--    footer still lands on its expected row.
do
	local root = vim.fn.tempname()
	vim.fn.mkdir(root, "p")
	for i = 1, 11 do
		local dir = string.format("%s/PLAN_%03d_synthetic", root, i)
		vim.fn.mkdir(dir, "p")
		local h = io.open(dir .. "/README.md", "w")
		h:write(string.format("# Plan: Synthetic plan %02d\n\nFixture.\n\n## Tasks\n\n- [ ] One task\n", i))
		h:close()
	end
	local win = open_at(80, { root })
	local lines = screen_lines(win)
	local cols_marker = marker_columns(lines)
	ok(#cols_marker == 11, "many plans: 11 rows render with markers (got " .. #cols_marker .. ")")
	ok(all_equal(cols_marker), "many plans: block aligned across 11 rows")
	local good, _ = footer_on_expected_row(win, lines)
	ok(good, "many plans: footer on its expected row — no wrap at 11 plans")
end

-- 4. Reader across widths: prose wraps (never clips), CJK title truncates,
--    the blocked reason renders whole.
do
	local records = plans.scan({ HOSTILE })
	local cjk_rec = nil
	for _, r in ipairs(records) do
		if r.name == "PLAN_995_fixture_cjk" then
			cjk_rec = r
		end
	end
	ok(cjk_rec ~= nil, "reader: CJK fixture scans")

	vim.o.columns = 80
	vim.o.lines = 40
	vim.cmd("redraw")
	reader.open(cjk_rec)
	vim.cmd("redraw")
	local rows = reader.rows()
	local goal_rows = {}
	for _, row in ipairs(rows) do
		if row.kind == "goal" then
			goal_rows[#goal_rows + 1] = row.text
		end
	end
	ok(#goal_rows >= 2, "reader at 80: long goal wraps into multiple rows (got " .. #goal_rows .. ")")
	local widths_ok = true
	for _, line in ipairs(goal_rows) do
		if vim.fn.strdisplaywidth(line) > 78 then
			widths_ok = false
		end
	end
	ok(widths_ok, "reader at 80: every goal row fits the window width")
	local tail_found = false
	for _, line in ipairs(goal_rows) do
		if line:find("columns%.$", 1, true) or line:find("columns.", 1, true) then
			tail_found = true
		end
	end
	ok(tail_found, "reader at 80: the goal's final word survives the wrap")
	local title_row = rows[1] and rows[1].text or ""
	ok(title_row:find("…", 1, true) ~= nil, "reader at 80: 60-cell CJK title truncates with ellipsis")

	vim.o.columns = 60
	vim.cmd("redraw")
	reader.open(cjk_rec)
	vim.cmd("redraw")
	rows = reader.rows()
	goal_rows = {}
	for _, row in ipairs(rows) do
		if row.kind == "goal" then
			goal_rows[#goal_rows + 1] = row.text
		end
	end
	local narrow_ok = true
	for _, line in ipairs(goal_rows) do
		if vim.fn.strdisplaywidth(line) > 58 then
			narrow_ok = false
		end
	end
	ok(narrow_ok, "reader at 60: every goal row fits the narrower window (wrap, not clip)")

	-- Hard-split integrity at a width that forces it: the fixture goal
	-- carries an unspaced CJK sentence and a long URL. Wrap must keep
	-- every byte (byte-resume, not char-resume — a char-count sub lands
	-- mid-codepoint), cap continuations at width minus indent, and
	-- spend exactly the goal's own cells plus the indent per line.
	vim.o.columns = 44
	vim.cmd("redraw")
	reader.open(cjk_rec)
	vim.cmd("redraw")
	rows = reader.rows()
	goal_rows = {}
	for _, row in ipairs(rows) do
		if row.kind == "goal" then
			goal_rows[#goal_rows + 1] = row.text
		end
	end
	local hard_split = false
	for _, line in ipairs(goal_rows) do
		if vim.fn.strdisplaywidth(line) == 42 and line ~= goal_rows[1] then
			hard_split = true
		end
	end
	ok(hard_split, "reader at 44: narrow width actually exercises the hard-split path")
	local cap_ok = true
	local bad_start = 0
	local total_cells = 0
	for _, line in ipairs(goal_rows) do
		local w = vim.fn.strdisplaywidth(line)
		total_cells = total_cells + w
		if w > 42 then
			cap_ok = false
		end
		local b = line:byte(1)
		if b and b >= 128 and b <= 191 then
			bad_start = bad_start + 1
		end
	end
	ok(cap_ok, "reader at 44: hard-split rows fit cap (width minus indent, not width)")
	ok(bad_start == 0, "reader at 44: no row begins mid-codepoint (byte-resume, got " .. bad_start .. ")")
	local goal_text = ""
	local readme_lines = vim.fn.readfile(HOSTILE .. "/PLAN_995_fixture_cjk/README.md")
	local in_goal = false
	for _, l in ipairs(readme_lines) do
		if l:find("^## ") then
			in_goal = l:find("Goal", 1, true) ~= nil
		elseif in_goal and l ~= "" then
			goal_text = goal_text == "" and l or (goal_text .. " " .. l)
		end
	end
	local function squash(s)
		return (s:gsub("%s", ""))
	end
	local wrapped_squashed = squash(table.concat(goal_rows, ""))
	ok(wrapped_squashed == squash(goal_text), "reader at 44: wrap keeps every goal byte (round-trip equal)")
	-- Exact bounds: every break adds the 2-cell indent; a soft break also
	-- consumes the 1-cell space it replaces, a hard-split break consumes
	-- nothing. So the budget sits in [goal + (n-1), goal + 2*(n-1)].
	-- Phantom cells (mid-codepoint resume rendering lone bytes at width
	-- 4) blow the ceiling; dropped bytes sink under the floor.
	local goal_cells = vim.fn.strdisplaywidth(goal_text)
	local breaks = #goal_rows - 1
	local floor_cells = goal_cells + breaks
	local ceil_cells = goal_cells + 2 * breaks
	ok(
		total_cells >= floor_cells and total_cells <= ceil_cells,
		"reader at 44: cell budget within exact bounds (got "
			.. total_cells
			.. ", bounds ["
			.. floor_cells
			.. ", "
			.. ceil_cells
			.. "])"
	)

	local shared_records = plans.scan({ SHARED })
	local blocked_rec = nil
	for _, r in ipairs(shared_records) do
		if r.blocked then
			blocked_rec = r
		end
	end
	ok(blocked_rec ~= nil, "reader: blocked fixture scans")
	reader.open(blocked_rec)
	vim.cmd("redraw")
	rows = reader.rows()
	local blocked_rows = {}
	for _, row in ipairs(rows) do
		if row.kind == "info" and row.text:find("Needs attention", 1, true) then
			blocked_rows[#blocked_rows + 1] = row.text
		end
	end
	ok(#blocked_rows >= 1, "reader at 60: blocked attention line renders")
	local blocked_fits = true
	for _, line in ipairs(blocked_rows) do
		if vim.fn.strdisplaywidth(line) > 58 then
			blocked_fits = false
		end
	end
	ok(blocked_fits, "reader at 60: blocked line wraps inside the width")
end

-- 5. Greeter: the bar/counts block starts at one column across plans
--    (width-aware padding, so CJK titles cannot break alignment).
do
	for _, roots in ipairs({ { HOSTILE }, { SHARED, HOSTILE } }) do
		local section = greeter.build(roots)
		local bar_cols = {}
		for _, entry in ipairs(section.plan_lines) do
			local line = entry.text
			-- A full bar has only filled cells and an empty one only
			-- hollow cells: either marks where the bar starts.
			local c = line:find("▰", 1, true) or line:find("▱", 1, true)
			ok(c ~= nil, "greeter: plan line carries a progress bar")
			if c then
				bar_cols[#bar_cols + 1] = vim.fn.strdisplaywidth(line:sub(1, c - 1))
			end
		end
		ok(#bar_cols >= 2, "greeter: at least two plan lines to align")
		ok(all_equal(bar_cols), "greeter: bar column identical across plan lines (F-07)")
	end
end

-- 6. Statusline degradation: narrower maxwidth truncates from the left
--    with the < marker and never loses the counts; no artifacts.
do
	local seg = statusline.segment({
		title = "Fixture running plan",
		name = "PLAN_991_fixture_running",
		icon = "◉",
		label = "Working",
		tasks_done = 2,
		tasks_total = 5,
	})
	for _, mw in ipairs({ 60, 30, 12, 8 }) do
		local evaluated = vim.api.nvim_eval_statusline(seg, { maxwidth = mw })
		local w = vim.fn.strdisplaywidth(evaluated.str)
		ok(w <= mw, string.format("statusline maxwidth %d: fits (%d)", mw, w))
		ok(evaluated.str:find("2/5", 1, true) ~= nil, string.format("statusline maxwidth %d: counts survive", mw))
		if mw < 40 then
			ok(evaluated.str:sub(1, 1) == "<", string.format("statusline maxwidth %d: truncation is visible (<)", mw))
		end
		ok(evaluated.str:find("%%", 1, true) == nil, string.format("statusline maxwidth %d: no stray %s", mw, "%"))
	end
end

-- 7. Resize re-render: narrowing the open window and refreshing re-fits
--    the rows (cap follows the window), and VimResized is wired.
do
	local win = open_at(120, { SHARED, HOSTILE })
	local before = screen_lines(win)
	local cols_before = marker_columns(before)
	vim.api.nvim_win_set_width(win, 36)
	sidebar.refresh()
	vim.cmd("redraw")
	ok(vim.api.nvim_win_get_width(win) == 36, "resize: window narrowed to 36")
	local after = screen_lines(win)
	local cols_after = marker_columns(after)
	ok(#cols_after >= 4, "resize: plan rows still render after re-fit")
	ok(all_equal(cols_after), "resize: block re-aligned at the new width")
	if cols_before[1] and cols_after[1] then
		ok(cols_after[1] < cols_before[1], "resize: title cap shrank with the window (no stale-width rows)")
	end
	local running = nil
	for _, line in ipairs(after) do
		if line:find("40%%%s*$") then
			running = line
			break
		end
	end
	ok(running ~= nil, "resize: percent still complete after re-fit")
	local good, _ = footer_on_expected_row(win, after)
	ok(good, "resize: footer on its expected row after re-fit")
	local autocmds = vim.api.nvim_get_autocmds({ group = "DwpSidebar", event = "VimResized" })
	ok(#autocmds >= 1, "resize: VimResized refresh is wired")
end

print(string.format("render smoke: %d assertions, %d failed", count, fails))
for _, msg in ipairs(failures) do
	print("FAIL: " .. msg)
end
if fails == 0 then
	print("assertions OK")
else
	print("ASSERTIONS FAILED")
end
