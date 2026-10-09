-- Model smoke: behavioral assertions over dwp.state / dwp.plans against
-- the synthetic fixtures in tests/fixtures/dwp_plans. Run headlessly via
-- tests/smoke/run.sh. Success prints "MODEL SMOKE: <n> assertions OK"
-- and exits 0; any mismatch prints a FAIL line and exits 1.

local state = require("dwp.state")
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

local function eq(actual, expected, msg)
	ok(actual == expected, ("%s (expected %s, got %s)"):format(msg, vim.inspect(expected), vim.inspect(actual)))
end

local function plan(name)
	return FIXTURES .. "/" .. name
end

-- Machine-state compatibility: derive() keeps its five v1 values for
-- every fixture (this is the byte-compatibility assertion).
local MACHINE = {
	["PLAN_990_fixture_draft"] = "draft",
	["PLAN_991_fixture_running"] = "in-flight",
	["PLAN_992_fixture_done"] = "completed",
	["PLAN_993_fixture_blocked"] = "in-flight",
	["PLAN_994_fixture_corrupt"] = "unknown",
}
for name, expected in pairs(MACHINE) do
	eq(state.derive(plan(name)), expected, "derive() machine state for " .. name)
end

-- Rich derivation per the frozen vocabulary (DESIGN_SPEC § Status
-- vocabulary, § Friendly-name derivation).
local r990 = state.derive_rich(plan("PLAN_990_fixture_draft"))
eq(r990.label, "Not started", "draft label")
eq(r990.icon, "○", "draft icon")
eq(r990.highlight, "Comment", "draft highlight")
eq(r990.tasks_done, 1, "draft done count")
eq(r990.tasks_total, 3, "draft total count")
eq(r990.percent, 33, "draft percent (1/3)")
eq(r990.blocked, false, "draft not blocked")
eq(r990.current_task, nil, "draft has no current task")
eq(r990.title, "Fixture draft plan", "draft title (README heading, Plan: prefix stripped)")

local r991 = state.derive_rich(plan("PLAN_991_fixture_running"))
eq(r991.label, "Working", "running label")
eq(r991.icon, "◉", "running icon")
eq(r991.highlight, "MoreMsg", "running highlight")
eq(r991.tasks_done, 2, "running done count (README checkboxes)")
eq(r991.tasks_total, 5, "running total count")
eq(r991.percent, 40, "running percent (2/5)")
eq(r991.blocked, false, "running not blocked")
eq(r991.current_task, "T-design", "running current task (started, not completed)")
eq(r991.title, "Fixture running plan", "running title")

local r992 = state.derive_rich(plan("PLAN_992_fixture_done"))
eq(r992.label, "Done", "done label")
eq(r992.icon, "✓", "done icon")
eq(r992.highlight, "Special", "done highlight")
eq(r992.percent, 100, "done percent (5/5)")
eq(r992.current_task, nil, "done has no current task")
eq(r992.title, "Fixture done plan", "done title")

local r993 = state.derive_rich(plan("PLAN_993_fixture_blocked"))
eq(r993.machine, "in-flight", "blocked machine state stays in-flight")
eq(r993.label, "Needs attention", "blocked label overlay")
eq(r993.icon, "⚠", "blocked icon")
eq(r993.highlight, "WarningMsg", "blocked highlight")
eq(r993.blocked, true, "blocked signal true")
eq(r993.blocker_reason, "waiting for design review", "blocked reason carried")
eq(r993.current_task, "T-design", "blocked keeps its current task")

local r994 = state.derive_rich(plan("PLAN_994_fixture_corrupt"))
eq(r994.machine, "unknown", "corrupt machine state")
eq(r994.label, "Unknown", "corrupt label")
eq(r994.icon, "·", "corrupt icon")
eq(r994.title, "Fixture corrupt plan", "corrupt title still resolves (README readable)")

-- The scan carries the rich fields so surfaces render without
-- re-deriving per row, keeps the v1 field names, and never hides a plan.
local records = plans.scan({ FIXTURES })
ok(#records == 5, "scan lists all five fixtures (got " .. #records .. ")")
local by_name = {}
for _, rec in ipairs(records) do
	by_name[rec.name] = rec
end
for name, expected in pairs(MACHINE) do
	local rec = by_name[name]
	ok(rec ~= nil, "scan lists " .. name)
	if rec then
		eq(rec.state, expected, "scan machine state for " .. name)
		eq(type(rec.title), "string", "scan carries title for " .. name)
		eq(type(rec.label), "string", "scan carries label for " .. name)
		eq(type(rec.icon), "string", "scan carries icon for " .. name)
		eq(type(rec.percent), "number", "scan carries percent for " .. name)
		eq(type(rec.blocked), "boolean", "scan carries blocked for " .. name)
	end
end
local rec991 = by_name["PLAN_991_fixture_running"]
if rec991 then
	eq(rec991.label, "Working", "scan label for running")
	eq(rec991.current_task, "T-design", "scan current task for running")
	eq(rec991.tasks_done, 2, "scan done count for running")
end
local rec993 = by_name["PLAN_993_fixture_blocked"]
if rec993 then
	eq(rec993.label, "Needs attention", "scan label for blocked")
	eq(rec993.blocker_reason, "waiting for design review", "scan blocker reason")
end

if fails > 0 then
	print(("MODEL SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("MODEL SMOKE: %d assertions OK"):format(count))
end
