-- Self-containment smoke: lua/dwp/ must stay extractable as a standalone
-- plugin (the deepworkplan.nvim extraction). Every module under lua/dwp/
-- may require only dwp.* modules (Neovim's vim.* APIs are globals and need
-- no require); no dynamic require, dofile, loadfile, luafile or
-- package.loaded reach-around that a static scan could not prove. In the
-- other direction, the rest of the editor reaches dwp only lazily (inside
-- functions or command strings, never at a file's top level), so boot never
-- depends on it. The scanner proves itself on synthetic violations first.
-- Run via tests/smoke/run.sh.

local repo = vim.uv.cwd()

local count, fails = 0, 0

local function ok(cond, msg)
	count = count + 1
	if not cond then
		fails = fails + 1
		print("FAIL: " .. msg)
	end
end

-- Drop comments (block first, then line) so prose like "never required
-- here" cannot match. Naive about "--" inside strings, which is the safe
-- direction: it can only hide code, and the dwp tree has no such string
-- holding a require.
local function strip_comments(src)
	src = src:gsub("%-%-%[(=*)%[.-%]%1%]", "")
	src = src:gsub("%-%-[^\n]*", "")
	return src
end

local ALLOWED = function(name)
	return name == "dwp" or name:sub(1, 4) == "dwp."
end

-- Returns a list of violations (strings) for one source text.
local function scan(src)
	local code = strip_comments(src)
	local bad = {}
	-- Every require token must be followed by a literal module name:
	-- require("x"), require "x", require 'x', require[[x]], or appear as
	-- pcall(require, "x").
	local pos = 1
	while true do
		local s, e = code:find("%f[%w_]require%f[^%w_]", pos)
		if not s then
			break
		end
		local rest = code:sub(e + 1)
		local name = rest:match("^%s*%(%s*[\"'](.-)[\"']%s*%)")
			or rest:match("^%s*[\"'](.-)[\"']")
			or rest:match("^%s*%[%[(.-)%]%]")
		if not name then
			-- pcall(require, "x") / xpcall(require, h, "x")
			local before = code:sub(math.max(1, s - 40), s - 1)
			if before:match("pcall%s*%(%s*$") then
				name = rest:match("^%s*,%s*[\"'](.-)[\"']") or rest:match("^%s*,%s*[%w_.]+%s*,%s*[\"'](.-)[\"']")
			end
		end
		if not name then
			bad[#bad + 1] = "dynamic or unreadable require near: " .. rest:sub(1, 30):gsub("\n", " ")
		elseif not ALLOWED(name) then
			bad[#bad + 1] = "requires a module outside dwp.*: " .. name
		end
		pos = e + 1
	end
	for _, word in ipairs({ "dofile", "loadfile", "luafile" }) do
		if code:find("%f[%w_]" .. word .. "%f[^%w_]") then
			bad[#bad + 1] = "uses " .. word .. " (unprovable dependency)"
		end
	end
	if code:find("package%.loaded") or code:find("package%.preload") then
		bad[#bad + 1] = "reaches into package.loaded/preload"
	end
	return bad
end

-- 1. The scanner discriminates: each synthetic violation is caught, each
--    allowed shape passes.
local must_flag = {
	'local g = require("mapping.glossary")',
	"local t = require 'scheme.theme'",
	"local l = require[[lsp]]",
	'local ok, m = pcall(require, "setUp.greeter")',
	"local m = require(name)",
	'dofile("x.lua")',
	'local x = package.loaded["mapping"]',
	"vim.cmd('luafile x.lua')",
}
for _, src in ipairs(must_flag) do
	ok(#scan(src) > 0, "scanner flags: " .. src)
end
local must_pass = {
	'local plans = require("dwp.plans")',
	"local s = require 'dwp.state'",
	'local ok, r = pcall(require, "dwp.reader")',
	"-- the sidebar is never required here; require('mapping') is prose",
	"--[[ require('lsp') ]] local x = vim.fn.getcwd()",
	"local required = true",
}
for _, src in ipairs(must_pass) do
	ok(#scan(src) == 0, "scanner allows: " .. src)
end

-- A column-0 statement (first char not whitespace) that requires dwp:
-- a bare `require("dwp.x")...`, an assignment `local x = require(...)`,
-- or a keyword form `return require(...)`. Indented lines are lazy.
local DWP_REQ = "require%s*%(?%s*[\"']dwp[\"%.]"
local EAGER = { "\n" .. DWP_REQ, "\n[%a_][%w_ ,.]*=%s*" .. DWP_REQ, "\n[%a_][%w_]*%s+" .. DWP_REQ }
local function eager_in(src)
	local text = "\n" .. strip_comments(src)
	for _, pattern in ipairs(EAGER) do
		if text:find(pattern) then
			return true
		end
	end
	return false
end
ok(eager_in('local s = require("dwp.sidebar")\n'), "eager check flags a top-level dwp require")
ok(eager_in("require('dwp.sidebar').setup()\n"), "eager check flags a bare top-level dwp call")
ok(not eager_in('map("n", "x", function()\n\trequire("dwp.sidebar").toggle()\nend)\n'), "eager check allows a lazy require inside a function")
ok(not eager_in('\t\treturn require("dwp.statusline").segment()\n'), "eager check allows an indented return")
ok(eager_in('return require("dwp.state")\n'), "eager check flags a top-level return of a dwp module")

-- 2. The real tree: every lua/dwp module is self-contained, and every
--    dwp.* module it requires exists.
local files = vim.fn.globpath(repo .. "/lua/dwp", "**/*.lua", false, true)
ok(#files >= 6, "lua/dwp has its modules (found " .. #files .. ")")
for _, path in ipairs(files) do
	local handle = io.open(path, "r")
	local src = handle and handle:read("*a") or ""
	if handle then
		handle:close()
	end
	local rel = path:sub(#repo + 2)
	local bad = scan(src)
	ok(#bad == 0, rel .. " is self-contained" .. (#bad > 0 and (": " .. table.concat(bad, "; ")) or ""))
	for name in strip_comments(src):gmatch("require%s*%(?%s*[\"'](dwp[%w_.]*)[\"']") do
		local target = repo .. "/lua/" .. name:gsub("%.", "/") .. ".lua"
		ok(vim.uv.fs_stat(target) ~= nil, rel .. " requires " .. name .. ", which exists")
	end
end

-- 3. The other direction: outside lua/dwp, dwp is reached only lazily —
--    no top-level (column-0) require of a dwp module anywhere in lua/ or
--    init.lua, so the editor boots without loading it.
local outside = vim.fn.globpath(repo .. "/lua", "**/*.lua", false, true)
outside[#outside + 1] = repo .. "/init.lua"
local referencing = 0
for _, path in ipairs(outside) do
	if not path:find("/lua/dwp/", 1, true) then
		local handle = io.open(path, "r")
		local src = handle and strip_comments(handle:read("*a")) or ""
		if handle then
			handle:close()
		end
		if src:find("dwp%.") then
			referencing = referencing + 1
		end
		ok(not eager_in(src), path:sub(#repo + 2) .. " reaches dwp only lazily (no top-level require)")
	end
end
ok(referencing > 0, "the editor does reference dwp somewhere (the lazy check is not vacuous)")

if fails > 0 then
	print(("SELF-CONTAINED SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("SELF-CONTAINED SMOKE: %d assertions OK"):format(count))
end
