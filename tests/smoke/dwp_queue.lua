-- Queue smoke: the pack-8.0 read-only plan surfaces — the dwp-queue-v1
-- reader (.dwp/queue.json), the structured-blocker badge (resolver
-- lead|human + blocker class), and the autonomy-posture block — over a
-- throwaway plan tree, plus the surfaces' degradation: no queue file,
-- a corrupt file, a wrong schema, and a 7.x-shaped plan must all
-- render exactly as before. Run via tests/smoke/run.sh.

local queue = require("dwp.queue")
local state = require("dwp.state")
local plans = require("dwp.plans")
local sidebar = require("dwp.sidebar")
local reader = require("dwp.reader")

local count, fails = 0, 0
local function ok(cond, msg)
	count = count + 1
	if not cond then
		fails = fails + 1
		print("FAIL: " .. msg)
	end
end

local function write(path, text)
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
	local f = assert(io.open(path, "w"))
	f:write(text)
	f:close()
end

local root = vim.fn.tempname()
local plans_root = root .. "/.dwp/plans"
local queue_path = root .. "/.dwp/queue.json"

local VALID_QUEUE = vim.json.encode({
	schema = "dwp-queue-v1",
	updated_at = "2026-11-16T00:00:00Z",
	items = {
		{ plan = "PLAN_990_first", after = vim.NIL, state = "done", lead = vim.NIL, start = vim.NIL },
		{ plan = "PLAN_991_second", after = "PLAN_990_first", state = "started", lead = "wP:p2", start = "prompt-lead" },
		{ plan = "PLAN_992_third", after = "PLAN_991_second", state = "queued", lead = vim.NIL, start = "launch" },
	},
	parallel = vim.NIL,
})

-- ---------------------------------------------------------- reader unit --

write(queue_path, VALID_QUEUE)
local q = queue.read(queue_path)
ok(q ~= nil, "a valid dwp-queue-v1 document reads")
ok(q and #q.items == 3, "all items are kept in file order")
ok(q and q.parallel == false, "parallel defaults to one plan at a time")
ok(q and q.updated_at == "2026-11-16T00:00:00Z", "updated_at is carried")

local summary = queue.summary(q)
ok(summary and summary.done == 1 and summary.started == 1 and summary.queued == 1, "summary counts by state")
ok(summary and summary.total == 3 and summary.parallel == false, "summary carries the total and the parallel flag")

local view = queue.for_plan(q, "PLAN_992_third")
ok(view and view.state == "queued" and view.position == 3, "a queued plan's position is its file-order place")
ok(view and view.ahead == 1 and view.total == 3, "ahead counts the plans before it still queued or started")
ok(view and view.start == "launch" and view.lead == nil, "start and lead come through when present")
ok(queue.for_plan(q, "PLAN_absent") == nil, "a plan outside the queue has no view")
ok(queue.line(view) == "queue: queued · #3 of 3, 1 ahead", "the plain-language line carries state, place and ahead")
ok(queue.line(queue.for_plan(q, "PLAN_991_second")) == "queue: started · #2 of 3", "a started plan with nothing ahead stays brief")

-- Degradation: absence, corruption, wrong schema, broken shape.
ok(queue.read(root .. "/.dwp/missing.json") == nil, "a missing file reads as no queue")
write(root .. "/.dwp/bad.json", "{ not json")
ok(queue.read(root .. "/.dwp/bad.json") == nil, "a corrupt file reads as no queue")
write(root .. "/.dwp/future.json", '{"schema":"dwp-queue-v2","items":[]}')
ok(queue.read(root .. "/.dwp/future.json") == nil, "a future schema is not guessed at")
write(root .. "/.dwp/noitems.json", '{"schema":"dwp-queue-v1","updated_at":"x"}')
ok(queue.read(root .. "/.dwp/noitems.json") == nil, "a document without items reads as no queue")
write(queue_path, vim.json.encode({
	schema = "dwp-queue-v1",
	updated_at = "2026-11-16T00:00:00Z",
	items = {
		{ plan = "PLAN_990_first", state = "queued", start = "prompt-lead" },
		{ plan = "PLAN_991_second", state = "weird", lead = "wP:p9" },
		{ plan = "PLAN_992_third" },
	},
}))
q = queue.read(queue_path)
ok(q ~= nil and #q.items == 3, "tolerant items: every plan stays visible")
ok(q and q.items[1].after == nil and q.items[1].start == "prompt-lead", "optional fields default to nil")
ok(q and q.items[2].state == "weird", "an unknown state surfaces verbatim, never hidden")
ok(q and q.items[3].state == "queued" and q.items[3].start == nil, "a bare item defaults its state")
ok(queue.find_for_roots({ plans_root }) ~= nil, "find_for_roots locates the queue beside a plans root")
ok(queue.find_for_roots({ root .. "/elsewhere/plans" }) == nil, "a root without a queue finds none")

-- ------------------------------------------------------------ badge unit --

ok(state.blocker_badge("lead", "C2") == "C2 · resolvable by: lead", "a lead-resolvable blocker says so")
ok(state.blocker_badge("human", "C2") == "C2 · needs: human", "a human blocker says so")
ok(state.blocker_badge(nil, "C7") == "C7 · needs: human", "an absent resolver means human (PLAN_024)")
ok(state.blocker_badge("lead", nil) == "resolvable by: lead", "a badge without a class still renders")
ok(state.blocker_badge(nil, nil) == nil, "no structured fields, no badge — a 7.x plan is unchanged")

-- ------------------------------------------------------- plan surfaces --

-- One 8.0-shaped plan (structured blocker + posture) and one 7.x-shaped
-- plan (string blocker), under the same queue.
local function plan_dir(name, state_json, in_flight)
	write(plans_root .. "/" .. name .. "/state.json", state_json)
	write(
		plans_root .. "/" .. name .. "/README.md",
		"# Plan: Queue fixture\n\n## Goal\n\nProve the 8.0 surfaces render.\n\n- [ ] one task\n"
	)
	if in_flight then
		-- manifest + one task_start make the plan in-flight, so a blocker
		-- overlays the label as Needs attention (the state vocabulary).
		write(plans_root .. "/" .. name .. "/manifest.json", '{"plan":"' .. name .. '"}')
		write(plans_root .. "/" .. name .. "/journal.ndjson", '{"type":"task_start","task":"t1"}\n')
	end
end
plan_dir("PLAN_990_first", vim.json.encode({
	tasks = { { id = "t1", title = "only task", status = "completed", started_seq = 1 } },
	blocker = nil,
}))
plan_dir("PLAN_991_second", vim.json.encode({
	tasks = { { id = "t1", title = "waiting task", status = "in_progress", started_seq = 1 } },
	blocker = { reason = "waiting on the design review", blocker_class = "C2", resolver = "lead" },
	posture = { stall_budget = 90, brain_may_act = false, promptable_scope = "lead-only" },
}), true)
plan_dir("PLAN_993_legacy", vim.json.encode({
	tasks = { { id = "t1", title = "legacy task", status = "in_progress", started_seq = 1 } },
	blocker = "waiting for a human decision",
}))

local records = {}
for _, rec in ipairs(plans.scan({ plans_root })) do
	records[rec.name] = rec
end
ok(records["PLAN_991_second"] ~= nil, "the 8.0-shaped plan scans")
ok(records["PLAN_991_second"] and records["PLAN_991_second"].blocker_resolver == "lead", "the resolver is derived")
ok(records["PLAN_991_second"] and records["PLAN_991_second"].blocker_class == "C2", "the class is derived")
ok(
	records["PLAN_991_second"] and records["PLAN_991_second"].posture ~= nil
		and records["PLAN_991_second"].posture.brain_may_act == false,
	"the posture is derived from the snapshot"
)
ok(
	records["PLAN_993_legacy"] and records["PLAN_993_legacy"].blocked == true
		and records["PLAN_993_legacy"].blocker_resolver == nil,
	"a 7.x string blocker derives no resolver"
)

-- Sidebar: the badge and the queue line ride under the plan rows.
write(queue_path, VALID_QUEUE)
sidebar.open({ plans_root })
local buf = nil
for _, b in ipairs(vim.api.nvim_list_bufs()) do
	if vim.bo[b].filetype == "dwp-plans" then
		buf = b
	end
end
local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
ok(text:find("resolvable by: lead", 1, true) ~= nil, "the sidebar renders the lead-resolvable badge")
ok(text:find("Needs attention", 1, true) ~= nil, "the blocked in-flight plan overlays as Needs attention")
ok(text:find("queue: started · #2 of 3", 1, true) ~= nil, "the sidebar renders the plan's queue line")
ok(text:find("queue: done · #1 of 3", 1, true) ~= nil, "a done plan still shows its queue place")
sidebar.close()

-- Reader: the posture block beside the goal, the badge under the warning.
local rec = records["PLAN_991_second"]
reader.open(rec)
local rbuf = nil
for _, b in ipairs(vim.api.nvim_list_bufs()) do
	if vim.bo[b].filetype == "dwp-plan" then
		rbuf = b
	end
end
local rtext = rbuf and table.concat(vim.api.nvim_buf_get_lines(rbuf, 0, -1, false), "\n") or ""
ok(rtext:find("Autonomy posture", 1, true) ~= nil, "the reader renders the posture block beside the goal")
ok(rtext:find("stall budget: 90", 1, true) ~= nil, "present posture facts render")
ok(rtext:find("brain may act: no", 1, true) ~= nil, "brain-may-act renders its truth, not idle")
ok(rtext:find("promptable: lead-only", 1, true) ~= nil, "the promptable scope renders")
ok(rtext:find("queue: started · #2 of 3", 1, true) ~= nil, "the reader carries the queue line too")
ok(rtext:find("resolvable by: lead", 1, true) ~= nil, "the reader renders the badge under the warning")
reader.close()

-- Degradation on the surfaces: delete the queue, strip the posture — the
-- badge goes with the structured fields, everything else stays.
vim.fn.delete(queue_path)
vim.fn.delete(plans_root .. "/PLAN_991_second/state.json")
write(plans_root .. "/PLAN_991_second/state.json", vim.json.encode({
	tasks = { { id = "t1", title = "waiting task", status = "in_progress", started_seq = 1 } },
	blocker = { reason = "waiting on the design review" },
}))
records = {}
for _, r in ipairs(plans.scan({ plans_root })) do
	records[r.name] = r
end
rec = records["PLAN_991_second"]
ok(rec.blocker_resolver == nil and rec.blocker_class == nil, "a blocker without structure derives no badge fields")
ok(rec.posture == nil, "a snapshot without a posture derives none")
sidebar.open({ plans_root })
text = table.concat(vim.api.nvim_buf_get_lines((function()
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[b].filetype == "dwp-plans" then
			return b
		end
	end
end)(), 0, -1, false), "\n")
ok(text:find("resolvable by", 1, true) == nil, "no structured fields, no badge line")
ok(text:find("queue:", 1, true) == nil, "no queue file, no queue line")
ok(text:find("Needs attention", 1, true) ~= nil, "the blocked plan still reads as Needs attention")
sidebar.close()

reader.open(records["PLAN_991_second"])
rbuf = nil
for _, b in ipairs(vim.api.nvim_list_bufs()) do
	if vim.bo[b].filetype == "dwp-plan" then
		rbuf = b
	end
end
rtext = rbuf and table.concat(vim.api.nvim_buf_get_lines(rbuf, 0, -1, false), "\n") or ""
ok(rtext:find("Autonomy posture", 1, true) == nil, "no posture data, no posture block")
reader.close()

vim.fn.delete(root, "rf")

if fails > 0 then
	print(("QUEUE SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("QUEUE SMOKE: %d assertions OK"):format(count))
end
