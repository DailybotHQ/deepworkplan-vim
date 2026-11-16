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
		{ plan = "PLAN_990_first", after = vim.NIL, state = "done", lead = vim.NIL, start = "prompt-lead" },
		{ plan = "PLAN_991_second", after = "PLAN_990_first", state = "started", lead = "local:wP:p2", start = "prompt-lead" },
		{ plan = "PLAN_992_third", after = "PLAN_991_second", state = "queued", lead = vim.NIL, start = "launch" },
	},
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
-- Validation is all-or-nothing, exactly like the pack's valid_doc: any
-- bad item rejects the whole document, so no hand-edited value (a
-- newline in a state, say) ever reaches a buffer.
local function item(over)
	local base = { plan = "PLAN_990_first", after = vim.NIL, state = "queued", lead = vim.NIL, start = "prompt-lead" }
	for k, v in pairs(over or {}) do
		base[k] = v
	end
	return base
end
local function rejects(items, msg, extra)
	local doc = { schema = "dwp-queue-v1", updated_at = "2026-11-16T00:00:00Z", items = items }
	for k, v in pairs(extra or {}) do
		doc[k] = v
	end
	write(root .. "/.dwp/strict.json", vim.json.encode(doc))
	ok(queue.read(root .. "/.dwp/strict.json") == nil, msg)
end
rejects({ item({ state = "x\ny" }) }, "a state with a newline rejects the document")
rejects({ item({ state = "weird" }) }, "an unknown state rejects the document")
rejects({ item({ start = "later" }) }, "an unknown start rejects the document")
rejects({ { plan = "PLAN_990_first", state = "queued", start = "prompt-lead" } }, "an item missing a base key rejects the document")
rejects({ item({ extra = 1 }) }, "an unknown item key rejects the document")
rejects({ item({ state = "started" }) }, "a started item without a lead rejects the document")
rejects({ item({ state = "started", lead = "wP:p2" }) }, "a lead that is not a full pane address rejects the document")
rejects({ item({ plan = "-bad" }) }, "a plan id outside the pack's form rejects the document")
rejects({ item({ plan = "PLAN_\195\169" }) }, "a non-ASCII plan id rejects the document (ASCII classes, like the pack)")
rejects({ item(), item() }, "a duplicate plan rejects the document")
rejects({ item({ note = "   " }) }, "a blank note rejects the document")
rejects({ item() }, "a non-boolean parallel rejects the document", { parallel = "yes" })
rejects({ item() }, "an unknown document key rejects the document", { owner = "me" })
local many = {}
for n = 1, 65 do
	many[n] = item({ plan = "PLAN_" .. n })
end
rejects(many, "more than 64 items rejects the document")
write(root .. "/.dwp/noted.json", vim.json.encode({
	schema = "dwp-queue-v1",
	updated_at = "2026-11-16T00:00:00Z",
	items = { item({ state = "skipped", note = "superseded by PLAN_992" }) },
	parallel = true,
}))
q = queue.read(root .. "/.dwp/noted.json")
ok(q and #q.items == 1 and q.items[1].state == "skipped" and q.parallel == true, "a skipped item with a note and parallel=true read")
write(root .. "/.dwp/huge.json", '{"schema":"dwp-queue-v1","items":[],"updated_at":"' .. string.rep("x", 70000) .. '"}')
ok(queue.read(root .. "/.dwp/huge.json") == nil, "a file above 64 KiB reads as no queue")
write(queue_path, VALID_QUEUE)
vim.uv.fs_symlink(queue_path, root .. "/.dwp/link.json")
ok(queue.read(root .. "/.dwp/link.json") == nil, "a symlinked queue file is not followed")
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
	blocker = { reason = "waiting on the design review", class = "C3", resolver = "lead" },
}), true)
-- The posture lives in the plan's v8 contract (plan-contract/v8 autonomy
-- block), reached through the manifest pointer — never in state.json.
local function contract(name, doc)
	write(plans_root .. "/" .. name .. "/manifest.json", '{"plan":"' .. name .. '","contract":{"path":"contract.json"}}')
	write(plans_root .. "/" .. name .. "/contract.json", vim.json.encode(doc))
end
contract("PLAN_991_second", {
	schema = "https://deepworkplan.com/schema/plan-contract/v8.json",
	autonomy = { stall_budget = 5, brain = false, promptable = { "local:w1:p2" }, notify = { "dailybot" }, queue = "prompt-lead" },
})
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
ok(records["PLAN_991_second"] and records["PLAN_991_second"].blocker_class == "C3", "the class is derived")
ok(
	records["PLAN_991_second"] and state.posture(records["PLAN_991_second"].path) ~= nil
		and state.posture(records["PLAN_991_second"].path).brain == false
		and state.posture(records["PLAN_991_second"].path).stall_budget == 5,
	"the posture is derived from the v8 contract's autonomy block"
)
ok(records["PLAN_991_second"] and records["PLAN_991_second"].posture == nil,
	"a plans scan pays no contract read: the posture is the reader's, on demand")
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
ok(rtext:find("stall budget: 5", 1, true) ~= nil, "present posture facts render")
ok(rtext:find("brain may act: no", 1, true) ~= nil, "brain-may-act renders its truth, not idle")
ok(rtext:find("promptable: local:w1:p2", 1, true) ~= nil, "the promptable panes render")
ok(rtext:find("notify: dailybot", 1, true) ~= nil, "the notify targets render")
ok(rtext:find("queue start: prompt-lead", 1, true) ~= nil, "the queue start mode renders")
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
-- A class outside C1–C7 is not a class (herdr-peers 2.1.0 reads the same set).
write(plans_root .. "/PLAN_991_second/state.json", vim.json.encode({
	tasks = { { id = "t1", title = "waiting task", status = "in_progress", started_seq = 1 } },
	blocker = { reason = "odd class", class = "C9" },
}))
for _, r in ipairs(plans.scan({ plans_root })) do
	if r.name == "PLAN_991_second" then
		ok(r.blocker_class == nil, "a class outside C1-C7 is ignored")
	end
end
write(plans_root .. "/PLAN_991_second/state.json", vim.json.encode({
	tasks = { { id = "t1", title = "waiting task", status = "in_progress", started_seq = 1 } },
	blocker = { reason = "waiting on the design review" },
}))
-- A v8 contract with no autonomy block: every recorded default applies.
contract("PLAN_991_second", { schema = "https://deepworkplan.com/schema/plan-contract/v8.json" })
records = {}
for _, r in ipairs(plans.scan({ plans_root })) do
	records[r.name] = r
end
rec = records["PLAN_991_second"]
ok(state.posture(rec.path) ~= nil and state.posture(rec.path).stall_budget == 3 and state.posture(rec.path).brain == false
	and state.posture(rec.path).promptable == nil and state.posture(rec.path).notify == nil and state.posture(rec.path).queue == "none",
	"an absent autonomy block on a v8 contract means all five defaults")
-- Out-of-range and wrong-shape keys fall back to their own defaults.
contract("PLAN_991_second", {
	schema = "https://deepworkplan.com/schema/plan-contract/v8.json",
	autonomy = { stall_budget = 99, brain = "yes", promptable = {}, queue = "sometimes" },
})
records = {}
for _, r in ipairs(plans.scan({ plans_root })) do
	records[r.name] = r
end
rec = records["PLAN_991_second"]
ok(state.posture(rec.path) and state.posture(rec.path).stall_budget == 3 and state.posture(rec.path).brain == false
	and state.posture(rec.path).promptable == nil and state.posture(rec.path).queue == "none",
	"malformed keys fall back to their defaults")
-- A v7 contract has no posture: the plan renders exactly as before.
contract("PLAN_991_second", {
	schema = "https://deepworkplan.com/schema/plan-contract/v7.json",
	autonomy = { stall_budget = 5 },
})
records = {}
for _, r in ipairs(plans.scan({ plans_root })) do
	records[r.name] = r
end
rec = records["PLAN_991_second"]
ok(state.posture(rec.path) == nil, "a v7 contract derives no posture, even with a stray autonomy key")
-- After an amendment the live contract is the highest contracts/ revision
-- (V6_LIFECYCLE section 5), never the manifest's first-written pointer.
contract("PLAN_991_second", {
	schema = "https://deepworkplan.com/schema/plan-contract/v8.json",
	autonomy = { stall_budget = 2 },
})
write(plans_root .. "/PLAN_991_second/contracts/contract.r1.json", vim.json.encode({
	schema = "https://deepworkplan.com/schema/plan-contract/v8.json",
	autonomy = { stall_budget = 2 },
}))
write(plans_root .. "/PLAN_991_second/contracts/contract.r2.json", vim.json.encode({
	schema = "https://deepworkplan.com/schema/plan-contract/v8.json",
	autonomy = { stall_budget = 7 },
}))
write(plans_root .. "/PLAN_991_second/contracts/.contract.r3.json.pending", vim.json.encode({
	schema = "https://deepworkplan.com/schema/plan-contract/v8.json",
	autonomy = { stall_budget = 9 },
}))
ok(state.posture(rec.path) and state.posture(rec.path).stall_budget == 7,
	"the posture follows the highest contracts/ revision, ignoring a staged .pending")
vim.fn.delete(plans_root .. "/PLAN_991_second/contracts", "rf")
contract("PLAN_991_second", {
	schema = "https://deepworkplan.com/schema/plan-contract/v7.json",
})
-- A lead resolver with a class a lead may not clear (C1) is the human's.
write(plans_root .. "/PLAN_991_second/state.json", vim.json.encode({
	tasks = { { id = "t1", title = "waiting task", status = "in_progress", started_seq = 1 } },
	blocker = { reason = "needs an approval", class = "C1", resolver = "lead" },
}))
for _, r in ipairs(plans.scan({ plans_root })) do
	if r.name == "PLAN_991_second" then
		ok(r.blocker_resolver == "human" and r.blocker_class == "C1", "lead with a class outside C3/C4/C7 reads as human")
	end
end
write(plans_root .. "/PLAN_991_second/state.json", vim.json.encode({
	tasks = { { id = "t1", title = "waiting task", status = "in_progress", started_seq = 1 } },
	blocker = { reason = "waiting on the design review" },
}))
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
