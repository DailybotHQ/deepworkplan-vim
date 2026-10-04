-- Statusline smoke: the ambient segment, proven headlessly — active-plan
-- rendering with the click wrapper, the empty case, the no-scan-per-
-- redraw cache proof (the assertion, not a hope), event-driven refresh
-- after the fixtures change on disk, and the click handler opening the
-- sidebar. Full mouse rendering is a manual check, recorded as such in
-- the plan log. Run via tests/smoke/run.sh.

local statusline = require("dwp.statusline")
local plans = require("dwp.plans")

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

local function sidebar_open()
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local b = vim.api.nvim_win_get_buf(w)
		if vim.bo[b].filetype == "dwp-plans" then
			return true
		end
	end
	return false
end

-- 1. Loading the module performs no scan (lazy init).
ok(statusline.scan_count() == 0, "no scan at module load")

-- 2. Seeded refresh picks the in-flight plan: fixtures sorted by mtime
-- then name put 991 (Working) ahead of 993 (Needs attention).
statusline.refresh({ FIXTURES })
ok(statusline.scan_count() == 1, "explicit refresh scans once")
local cached = statusline.cached()
ok(cached ~= nil and cached.name == "PLAN_991_fixture_running", "active plan is the in-flight one (991, not the blocked 993)")

-- 3. The segment renders icon, title, bar, counts, click wrapper.
local seg = statusline.segment()
ok(seg:find("^%%@v:lua%.DwpPlansClick@", 1) ~= nil, "segment is wrapped in the click expression")
ok(seg:sub(-1) == "@", "click expression is closed")
ok(seg:find("Fixture running plan", 1, true) ~= nil, "segment carries the friendly title")
ok(seg:find("◉", 1, true) ~= nil, "segment carries the working icon")
ok(seg:find("▰▰▱▱▱▱ 2/5", 1, true) ~= nil, "segment carries the 6-cell bar and counts")

-- 4. The hot-path proof: repeated renders add no scans.
for _ = 1, 3 do
	statusline.segment()
end
ok(statusline.scan_count() == 1, "4 renders, still 1 scan (cache, not scan)")
ok(statusline.has_plan() == true, "has_plan true with an active plan")
ok(statusline.scan_count() == 1, "has_plan is also pure cache")

-- 5. Empty case: no plans anywhere → segment hides (lualine cond false).
statusline.refresh({ NO_PLANS })
ok(statusline.scan_count() == 2, "second refresh scans again")
ok(statusline.cached() == nil, "no active plan under a planless root")
ok(statusline.segment() == "", "segment renders empty with no active plan")
ok(statusline.has_plan() == false, "cond is false with no active plan")

-- 6. Fixture change on disk + the declared event repopulates the cache.
statusline.refresh({ FIXTURES })
ok(statusline.scan_count() == 3, "back on fixtures, scan 3")
vim.uv.fs_rename(
	FIXTURES .. "/PLAN_991_fixture_running",
	FIXTURES .. "/PLAN_996_fixture_running_backup"
)
-- The wiring exists because segment() ran; fire the real autocmd.
ok(statusline.segment():find("Fixture running plan", 1, true) ~= nil, "stale cache still serves (no eager scan)")
vim.api.nvim_exec_autocmds("BufEnter", { buffer = 0 })
vim.wait(900, function()
	return statusline.scan_count() > 3
end, 50)
ok(statusline.scan_count() == 4, "BufEnter fired the debounced refresh (one scan)")
local seg2 = statusline.segment()
ok(seg2:find("⚠", 1, true) ~= nil, "refreshed segment shows the blocked plan (993 now active)")
ok(seg2:find("Fixture running plan", 1, true) ~= nil, "and still the in-flight family, not a done plan")
vim.uv.fs_rename(
	FIXTURES .. "/PLAN_996_fixture_running_backup",
	FIXTURES .. "/PLAN_991_fixture_running"
)
statusline.refresh({ FIXTURES })
ok(statusline.segment():find("◉", 1, true) ~= nil, "fixture restored; working plan active again")

-- 7. The click handler opens (and closes) the sidebar without error.
ok(type(_G.DwpPlansClick) == "function", "global click handler exists")
_G.DwpPlansClick()
ok(sidebar_open(), "click handler opens the sidebar")
_G.DwpPlansClick()
ok(not sidebar_open(), "click handler toggles it closed")

if fails > 0 then
	print(("STATUSLINE SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("STATUSLINE SMOKE: %d assertions OK"):format(count))
end
