-- Consistency smoke: ONE record, FOUR surfaces, one vocabulary. For the
-- same plan record the sidebar row, reader header, statusline segment and
-- greeter line must agree on icon, status word, percent and counts — and
-- the spec'd divergences (bar cells per surface, title caps, counts
-- absent from the sidebar row by recorded amendment) must hold EXACTLY.
-- The consistency matrix in the UX audit is executable here.

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

local function first_char(s)
	return vim.fn.strcharpart(s, 0, 1)
end

-- The bar run inside a rendered line ("▰▱…"), wherever it starts.
-- Walks whole UTF-8 sequences, never single bytes and never pattern
-- classes: [▰▱] also matches UTF-8 continuation bytes inside CJK titles
-- and "…", and vim.split(line, "") yields single BYTES (harness bugs
-- caught on the CJK fixture).
local function bar_run(line)
	local best = ""
	local cur = ""
	local i = 1
	while i <= #line do
		local b = line:byte(i)
		local len = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
		local ch = line:sub(i, i + len - 1)
		i = i + len
		if ch == "▰" or ch == "▱" then
			cur = cur .. ch
		else
			if #cur > #best then
				best = cur
			end
			cur = ""
		end
	end
	if #cur > #best then
		best = cur
	end
	return best
end

local function expected_bar(done, total, cells)
	local filled = 0
	if total and total > 0 then
		filled = math.floor((done / total) * cells + 0.5)
	end
	if filled > cells then
		filled = cells
	end
	return string.rep("▰", filled) .. string.rep("▱", cells - filled)
end

-- Spec'd divergences, asserted as expected (UX_AUDIT §4 matrix).
local BAR_CELLS = { sidebar = 8, reader = 10, statusline = 6, greeter = 8 }
local TITLE_CAPS = { sidebar = 28, reader = 60, statusline = 20, greeter = 26 }

-- 1. Open the sidebar over every fixture and keep its buffer text.
vim.o.columns = 120
vim.o.lines = 40
vim.cmd("redraw")
sidebar.open({ SHARED, HOSTILE })
vim.cmd("redraw")
local sidebar_text
do
	local buf = -1
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local b = vim.api.nvim_win_get_buf(w)
		if vim.bo[b].filetype == "dwp-plans" then
			buf = b
		end
	end
	sidebar_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

-- 2. Per record: the four surfaces must tell the same story.
local records = plans.scan({ SHARED, HOSTILE })
ok(#records == 7, "seven fixture records for the matrix (got " .. #records .. ")")

for _, record in ipairs(records) do
	local name = record.name
	local icon = record.icon or "·"
	local label = record.label or "Unknown"
	local done, total = record.tasks_done or 0, record.tasks_total or 0
	local percent = record.percent or 0
	local counts = string.format("%d/%d", done, total)
	-- Needle built with format: string literals do not escape %, so a
	-- plain find for `percent .. "%%"` searches two percent signs and
	-- never matches (harness bug — every percent assertion failed).
	local pct = string.format("%d%%", percent)

	-- Sidebar row: found by icon + title head (icons disambiguate the
	-- two same-titled running/blocked fixtures; 12 chars separate the
	-- "Fixture …" fixtures, and 12 CJK chars = 24 cells still fit the
	-- sidebar's 28-cell title cap at this width — a longer head cannot
	-- appear inside the truncated row).
	local title_head = vim.fn.strcharpart(record.title or record.name, 0, 12)
	local side_row = nil
	for line in sidebar_text:gmatch("[^\n]+") do
		if first_char(line) == icon and line:find(title_head, 1, true) then
			side_row = line
			break
		end
	end
	ok(side_row ~= nil, name .. ": sidebar row found")

	if side_row then
		ok(side_row:find(pct, 1, true) ~= nil, name .. ": sidebar row shows the record percent (" .. pct .. ")")
		ok(bar_run(side_row) == expected_bar(done, total, BAR_CELLS.sidebar), name .. ": sidebar bar is the 8-cell spec")
		if total > 0 then
			ok(side_row:find(counts, 1, true) == nil, name .. ": sidebar row carries percent, not counts (recorded amendment)")
		end
		ok(sidebar_text:find("\n" .. label, 1, true) ~= nil, name .. ": sidebar groups it under its status word")
	end

	-- Reader header.
	local reader_ok, reader_rows = pcall(function()
		reader.open(record)
		return reader.rows()
	end)
	ok(reader_ok, name .. ": reader opens")
	if reader_ok then
		local header = reader_rows[2] and reader_rows[2].text or ""
		ok(first_char(header) == icon, name .. ": reader icon matches the record")
		ok(header:find(label, 1, true) ~= nil, name .. ": reader says the status word")
		ok(header:find(counts, 1, true) ~= nil, name .. ": reader shows counts")
		ok(header:find(pct, 1, true) ~= nil, name .. ": reader shows the same percent")
		ok(bar_run(header) == expected_bar(done, total, BAR_CELLS.reader), name .. ": reader bar is the 10-cell spec")
	end

	-- Statusline segment.
	local seg = statusline.segment(record)
	if total > 0 then
		ok(seg:find(counts, 1, true) ~= nil, name .. ": statusline shows counts")
	end
	ok(bar_run(seg) == expected_bar(done, total, BAR_CELLS.statusline), name .. ": statusline bar is the 6-cell spec")
	if record.blocked then
		ok(seg:find("needs attention", 1, true) ~= nil, name .. ": blocked statusline says the word (F-08)")
	else
		ok(seg:find("needs attention", 1, true) == nil, name .. ": working statusline stays compact")
	end

	-- Greeter line.
	local gline = greeter.plan_line(record)
	ok(first_char(gline) == icon, name .. ": greeter icon matches the record")
	ok(gline:find(label, 1, true) ~= nil, name .. ": greeter says the status word")
	if total > 0 then
		ok(gline:find(counts, 1, true) ~= nil, name .. ": greeter shows counts")
		ok(gline:find("· " .. pct, 1, true) ~= nil, name .. ": greeter shows the same percent beside the counts")
	end
	ok(bar_run(gline) == expected_bar(done, total, BAR_CELLS.greeter), name .. ": greeter bar is the 8-cell spec")
end

-- 3. The blocked overlay is one story everywhere: the fixture shares its
--    title with the running one; the word and the ⚠ separate them.
do
	local blocked = nil
	for _, r in ipairs(records) do
		if r.blocked then
			blocked = r
		end
	end
	ok(blocked and blocked.label == "Needs attention", "blocked record overlays as Needs attention")
	ok(blocked and blocked.icon == "⚠", "blocked record carries the ⚠")
	local seg = statusline.segment(blocked)
	ok(seg:find("⚠", 1, true) ~= nil, "statusline blocked segment keeps the ⚠ beside the word")
end

-- 4. Title caps are the spec'd divergence and never exceed their surface
--    cap (display cells, CJK included).
ok(TITLE_CAPS.sidebar == 28 and TITLE_CAPS.reader == 60 and TITLE_CAPS.statusline == 20 and TITLE_CAPS.greeter == 26,
	"title caps are the frozen spec (28/60/20/26)")
for _, record in ipairs(records) do
	local gline = greeter.plan_line(record)
	local title = record.title or record.name
	if vim.fn.strdisplaywidth(title) > TITLE_CAPS.greeter then
		-- Strip the icon prefix by character, not `^.` — a dot matches
		-- one BYTE, so a multibyte icon (○) makes the match fail.
		local body = gline:sub(#first_char(gline) + 2)
		local shown = body:match("^(.-)  ")
		-- Truncation must FILL the cap as well as respect it: a byte-wise
		-- walk counted 4 phantom cells per CJK byte and collapsed titles
		-- to a fraction of the cap (defect D-4). "…" is 1 cell.
		local w = shown and vim.fn.strdisplaywidth(shown) or -1
		ok(w <= TITLE_CAPS.greeter, record.name .. ": greeter title within cap (got " .. w .. ")")
		ok(w >= TITLE_CAPS.greeter - 2, record.name .. ": greeter title FILLS the cap — no phantom-cell under-fill (got " .. w .. ")")
	end
end

print(string.format("consistency smoke: %d assertions, %d failed", count, fails))
for _, msg in ipairs(failures) do
	print("FAIL: " .. msg)
end
if fails == 0 then
	print("assertions OK")
else
	print("ASSERTIONS FAILED")
end
