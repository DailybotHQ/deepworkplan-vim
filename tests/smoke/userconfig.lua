-- User-config smoke: lua/userconfig.lua over temporary directories — the three
-- layers, validation, malformed files, the globals lua/dwp reads, and the
-- shipped dwpvim.json. Nothing outside the temp directories is read. Run via
-- tests/smoke/run.sh.

local uc = require("userconfig")

local count, fails = 0, 0
local function ok(cond, msg)
	count = count + 1
	if not cond then
		fails = fails + 1
		print("FAIL: " .. msg)
	end
end

local root = vim.fn.tempname()
local function dir(name)
	vim.fn.mkdir(root .. "/" .. name, "p")
	return root .. "/" .. name
end
local function write(path, text)
	local f = assert(io.open(path, "w"))
	f:write(text)
	f:close()
end
local function has(list, needle)
	for _, p in ipairs(list) do
		if p:find(needle, 1, true) then
			return true
		end
	end
	return false
end

-- 1. No files: the built-in defaults, no problems.
local cfg, proj = dir("cfg1"), dir("proj1")
local st = uc.load(cfg, proj)
ok(st.values.tree.side == "left" and st.values.tree.width == 40, "defaults: the tree is on the left, 40 wide")
ok(st.values.plans.side == "left" and st.values.plans.width == 48, "defaults: the plans sidebar is on the left, 48 wide")
ok(#st.problems == 0 and st.sources["tree.side"] == "default", "defaults: no problems, source is 'default'")

-- 2. The shipped file layer overrides the defaults.
cfg = dir("cfg2")
write(cfg .. "/dwpvim.json", '{ "tree": { "side": "right", "width": 55 }, "plans": { "width": 60 } }')
st = uc.load(cfg, dir("proj2"))
ok(st.values.tree.side == "right" and st.values.tree.width == 55, "the config file sets the tree side and width")
ok(st.values.plans.width == 60 and st.values.plans.side == "left", "keys it does not set keep their default")
ok(st.sources["tree.side"] == cfg .. "/dwpvim.json", "the source of a value is the file it came from")

-- 3. The project file wins over the config file.
proj = dir("proj3")
write(proj .. "/.dwpvim.json", '{ "tree": { "side": "left" } }')
st = uc.load(cfg, proj)
ok(st.values.tree.side == "left", "the project file overrides the config file")
ok(st.values.tree.width == 55, "a key the project file omits still comes from the config file")
ok(st.sources["tree.side"] == proj .. "/.dwpvim.json", "its source is the project file")

-- 4. Validation: each bad value is ignored and reported, the rest still apply.
cfg = dir("cfg4")
write(
	cfg .. "/dwpvim.json",
	'{ "tree": { "side": "top", "width": 5 }, "plans": { "side": "right", "width": "wide" }, "x": {}, "tree2": 1 }'
)
st = uc.load(cfg, dir("proj4"))
ok(st.values.tree.side == "left" and st.values.tree.width == 40, "invalid side and too-small width fall back to the defaults")
ok(st.values.plans.side == "right", "a valid key next to an invalid one still applies")
ok(st.values.plans.width == 48, "a non-numeric width falls back")
ok(has(st.problems, "tree.side"), "the invalid side is reported")
ok(has(st.problems, "tree.width"), "the too-small width is reported")
ok(has(st.problems, "plans.width"), "the non-numeric width is reported")
ok(has(st.problems, 'unknown section "x"'), "an unknown section is reported")
write(cfg .. "/dwpvim.json", '{ "tree": { "width": 40.5 } }')
ok(uc.load(cfg, dir("proj4b")).values.tree.width == 40, "a fractional width is rejected")
write(cfg .. "/dwpvim.json", '{ "tree": { "width": 500 } }')
ok(uc.load(cfg, dir("proj4c")).values.tree.width == 40, "a too-large width is rejected")
write(cfg .. "/dwpvim.json", '{ "tree": { "colour": "red" } }')
ok(has(uc.load(cfg, dir("proj4d")).problems, "unknown key tree.colour"), "an unknown key is reported")

-- 5. Documentation keys are ignored silently; broken files never crash.
write(cfg .. "/dwpvim.json", '{ "$comment": "note", "_x": 1, "tree": { "side": "right" } }')
st = uc.load(cfg, dir("proj5"))
ok(#st.problems == 0 and st.values.tree.side == "right", "$comment and _keys are documentation, not problems")
write(cfg .. "/dwpvim.json", "{ not json")
st = uc.load(cfg, dir("proj5b"))
ok(st.values.tree.side == "left" and has(st.problems, "invalid JSON"), "malformed JSON: defaults kept, problem reported")
write(cfg .. "/dwpvim.json", "[1, 2]")
ok(has(uc.load(cfg, dir("proj5c")).problems, "top level must be an object"), "an array at the top level is reported")
write(cfg .. "/dwpvim.json", '{ "tree": 3 }')
ok(has(uc.load(cfg, dir("proj5d")).problems, "tree must be an object"), "a non-object section is reported")

-- 6. apply(): publishes what lua/dwp reads, and defines :DwpConfig.
cfg = dir("cfg6")
write(cfg .. "/dwpvim.json", '{ "plans": { "side": "right", "width": 52 } }')
uc.apply(cfg, dir("proj6"))
ok(vim.g.dwp_plans_side == "right" and vim.g.dwp_plans_width == 52, "apply() sets vim.g.dwp_plans_side and _width")
ok(uc.get("plans.side") == "right" and uc.get("tree.side") == "left", "get() answers from the applied state")
ok(vim.fn.exists(":DwpConfig") == 2, ":DwpConfig is defined")
local text = table.concat(uc.describe(), "\n")
ok(text:find("tree.side", 1, true) and text:find("plans.width", 1, true) and text:find("(default)", 1, true), "describe() lists every key and its source")
ok(text:find("No problems.", 1, true) ~= nil, "describe() says so when there are no problems")

-- 6b. sidebars.exclusive: default true, accepts false, rejects non-booleans.
ok(uc.load(dir("cfg6b"), dir("proj6b")).values.sidebars.exclusive == true, "sidebars.exclusive defaults to true")
cfg = dir("cfg6c")
write(cfg .. "/dwpvim.json", '{ "sidebars": { "exclusive": false } }')
ok(uc.load(cfg, dir("proj6c")).values.sidebars.exclusive == false, "sidebars.exclusive = false is honoured")
write(cfg .. "/dwpvim.json", '{ "sidebars": { "exclusive": "no" } }')
st = uc.load(cfg, dir("proj6d"))
ok(st.values.sidebars.exclusive == true and has(st.problems, "sidebars.exclusive"), "a non-boolean exclusive is ignored and reported")

-- 7. The shipped file parses and validates cleanly, with the documented defaults.
local repo = vim.uv.cwd()
st = uc.load(repo, dir("proj7"))
ok(#st.problems == 0, "the shipped dwpvim.json has no problems")
ok(
	st.values.tree.side == "left"
		and st.values.tree.width == 40
		and st.values.plans.side == "left"
		and st.values.plans.width == 48
		and st.values.sidebars.exclusive == true,
	"the shipped file ships the documented defaults"
)

vim.fn.delete(root, "rf")
-- Leave the globals the way the next smoke expects them.
vim.g.dwp_plans_side, vim.g.dwp_plans_width = nil, nil

if fails > 0 then
	print(("USERCONFIG SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("USERCONFIG SMOKE: %d assertions OK"):format(count))
end
