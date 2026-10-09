-- Plugin lock smoke: every plugin lua/plugin_specs.lua declares (requires
-- included) and pckr itself has a full-commit entry in pckr/lockfile.lua,
-- the lock names nothing else, the file keeps pckr's exact sorted format
-- (so `:Pckr lock` and scripts/update-plugin-lock.sh write identical
-- files), and lua/plugin_lock.lua injects each pin into the spec pckr
-- receives. Adding a plugin without refreshing the lock fails here.
-- Run via tests/smoke/run.sh.

local repo = vim.uv.cwd()
local plugin_lock = require("plugin_lock")

local count, fails = 0, 0

local function ok(cond, msg)
	count = count + 1
	if not cond then
		fails = fails + 1
		print("FAIL: " .. msg)
	end
end

local lock_path = repo .. "/pckr/lockfile.lua"
local specs = dofile(repo .. "/lua/plugin_specs.lua")
local lock = plugin_lock.read(lock_path)

-- Coverage: no plugin without a pin, no pin without a plugin.
local missing, stale = plugin_lock.coverage(specs, lock)
for _, url in ipairs(missing) do
	ok(false, "no lock entry (refresh: bash scripts/update-plugin-lock.sh): " .. url)
end
for _, url in ipairs(stale) do
	ok(false, "lock entry for an undeclared plugin: " .. url)
end
ok(#missing == 0 and #stale == 0, "lock covers the specs exactly")

local urls = plugin_lock.urls(specs)
ok(#urls >= 40, "the specs name the curated set (" .. #urls .. " repositories)")
ok(plugin_lock.commit(lock, plugin_lock.PCKR_URL) ~= nil, "pckr itself is pinned")

-- File format: pckr's own `:Pckr lock` output, sorted, one entry per line.
local lines = vim.fn.readfile(lock_path)
ok(lines[1] == "return {" and lines[#lines] == "}", "lockfile is a `return { ... }` table")
local keys, prev = 0, ""
for i = 2, #lines - 1 do
	local url = lines[i]:match('^  %["(https://github%.com/[%w%._%-]+/[%w%._%-]+)"%] = { commit = "%x+" },$')
	ok(url ~= nil, "line " .. i .. " has pckr's lock format: " .. lines[i])
	ok(url == nil or url > prev, "line " .. i .. " is sorted")
	prev = url or prev
	keys = keys + 1
end
ok(keys == #urls + 1, ("one line per repository (%d lines, %d repositories + pckr)"):format(keys, #urls))

-- Injection: what pckr receives carries each repository's pin exactly once
-- (on a table spec when the repository has one), requires included, and no
-- repository is given by two table ("non-simple") specs — pckr warns about
-- that on every start.
local pinned = plugin_lock.pin_all(specs, lock)
local function walk(spec, fn)
	fn(spec)
	if type(spec) == "table" and type(spec.requires) == "table" then
		for _, dep in ipairs(spec.requires) do
			walk(dep, fn)
		end
	end
end
local pins, tables = {}, {}
for _, spec in ipairs(pinned) do
	walk(spec, function(s)
		local url = plugin_lock.url(type(s) == "table" and s[1] or s)
		if type(s) == "table" then
			tables[url] = (tables[url] or 0) + 1
			if s.commit ~= nil then
				pins[url] = (pins[url] or 0) + 1
				ok(s.commit == plugin_lock.commit(lock, url), "pin injected: " .. url)
			end
		end
	end)
end
local pinned_urls = 0
for _, url in ipairs(urls) do
	ok(pins[url] == 1, "pinned exactly once: " .. url .. " (" .. tostring(pins[url]) .. ")")
	ok((tables[url] or 0) <= 1, "one non-simple spec: " .. url .. " (" .. tostring(tables[url]) .. ")")
	pinned_urls = pinned_urls + (pins[url] == 1 and 1 or 0)
end
ok(pinned_urls == #urls, ("every repository pinned (%d of %d)"):format(pinned_urls, #urls))
local hooks = 0
for i, spec in ipairs(specs) do
	if type(spec) == "table" and (spec.run or spec.config) then
		hooks = hooks + 1
		ok(pinned[i].run == spec.run and pinned[i].config == spec.config, "hooks survive pinning: " .. spec[1])
	end
end
ok(hooks >= 3, "run/config hooks checked")

-- The check bites: a plugin added without a lock entry is reported, and
-- pckr would receive it unpinned.
local extra = vim.list_extend(vim.deepcopy(specs), { { "example/new-plugin.nvim", requires = "example/dep.nvim" } })
local m2 = plugin_lock.coverage(extra, lock)
ok(#m2 == 2, "an unlocked plugin and its unlocked dependency are reported")
ok(plugin_lock.pin(extra[#extra], lock).commit == nil, "an unlocked plugin gets no commit")
local s2 = select(2, plugin_lock.coverage(specs, vim.tbl_extend("force", lock, { ["https://github.com/x/y"] = { commit = string.rep("a", 40) } })))
ok(#s2 == 1, "a stale lock entry is reported")
ok(plugin_lock.commit({ u = { commit = "abc123" } }, "u") == nil, "a short sha is not a pin")
ok(next(plugin_lock.read(repo .. "/no/such/lockfile.lua")) == nil, "a missing lockfile reads as no pins")

if fails > 0 then
	print(("PLUGIN LOCK SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("PLUGIN LOCK SMOKE: %d assertions OK"):format(count))
end
