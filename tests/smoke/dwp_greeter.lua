-- Greeter smoke: the plans-overview builder, proven headlessly with no
-- alpha session (the wiring in setUp/greeter.lua is parse-gated and
-- boot-probed; the builder is the testable part). Run via
-- tests/smoke/run.sh.

local greeter_plans = require("dwp.greeter_plans")

local FIXTURES = vim.uv.cwd() .. "/tests/fixtures/dwp_plans"
local NO_PLANS = vim.uv.cwd() .. "/tests" -- a dir with no PLAN_* entries

local count, fails = 0, 0

local function ok(cond, msg)
	count = count + 1
	if not cond then
		fails = fails + 1
		print("FAIL: " .. msg)
	end
end

-- 1. Fixtures: header, top-3 rows, each icon + title + bar + counts +
--    status word, plus the hint.
local section = greeter_plans.build({ FIXTURES })
ok(section.header == "Your plans", "header phrasing is the frozen one")
ok(#section.plan_lines == 3, "top-3 rendered, not all five (got " .. #section.plan_lines .. ")")

-- scan order for the fixtures (same-day mtimes, name tiebreak):
-- 990 draft, 991 running, 992 done.
local first, second = section.plan_lines[1], section.plan_lines[2]
ok(first.text:find("Fixture draft plan", 1, true) ~= nil, "first row is the newest draft plan")
ok(first.text:find("○", 1, true) ~= nil, "draft row carries its icon")
ok(first.text:find("Not started", 1, true) ~= nil, "rows are status-worded (draft)")
ok(second.text:find("Fixture running plan", 1, true) ~= nil, "second row is the running plan")
ok(second.text:find("◉", 1, true) ~= nil, "running row carries its icon")
ok(second.text:find("▰▰▰▱▱▱▱▱ 2/5", 1, true) ~= nil, "running row carries the 8-cell bar and counts")
ok(second.text:find("2/5 · 40%", 1, true) ~= nil, "running row carries the percent beside the counts (F-01)")
ok(second.text:find("Working", 1, true) ~= nil, "rows are status-worded (working)")
ok(section.plan_lines[3].text:find("Done", 1, true) ~= nil, "third row is status-worded (done)")
ok(first.record ~= nil and first.record.name ~= nil, "rows carry their records for the reader gesture")

-- 1b. Alignment: alpha centres each row on its own, so every row must have
--     the same display width or the columns drift (counts and status words
--     differ per plan: 2/5 vs 11/11, Done vs Working).
local w1 = vim.fn.strdisplaywidth(section.plan_lines[1].text)
for i, row in ipairs(section.plan_lines) do
	ok(vim.fn.strdisplaywidth(row.text) == w1, "plan row " .. i .. " has the same width as row 1 (columns align)")
end

-- 2. Title truncation holds at the greeter's 26-char cap.
local long = greeter_plans.plan_line({
	title = "A very long plan title that clearly exceeds the cap",
	name = "PLAN_x",
	icon = "○",
	label = "Not started",
	tasks_done = 0,
	tasks_total = 9,
})
ok(long:find("A very long plan title th…", 1, true) ~= nil, "titles truncate with an ellipsis at 26")

-- 3. Hint line names the gesture.
ok(section.hint:find("Space P", 1, true) ~= nil, "hint names Space P (UX2-01: first exposure spells the space bar)")
ok(section.hint_click and section.hint_click:find("click", 1, true) ~= nil, "hint teaches the statusline click (F-04)")

-- 4. Empty state: the friendly line, zero rows, and (per the spec) the
--    wiring omits the [e] button when there are no rows.
local empty = greeter_plans.build({ NO_PLANS })
ok(#empty.plan_lines == 0, "planless roots render no rows")
ok(
	empty.empty_line
		== "No plans yet — ask your agent to plan work (open the editor in your project folder).",
	"empty-state teaches the project folder (F-02)"
)

if fails > 0 then
	print(("GREETER SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("GREETER SMOKE: %d assertions OK"):format(count))
end
