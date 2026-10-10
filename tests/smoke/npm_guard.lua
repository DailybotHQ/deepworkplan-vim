-- npm guard smoke: a pnpm stand-in named `npm` is detected and the real npm
-- is put first on PATH (lua/lsp/npm_guard.lua). Everything happens inside a
-- throwaway directory; nothing outside it is touched. Run via
-- tests/smoke/run.sh.

local guard = require("lsp.npm_guard")

local count, fails = 0, 0
local function ok(cond, msg)
	count = count + 1
	if not cond then
		fails = fails + 1
		print("FAIL: " .. msg)
	end
end

local root = vim.fn.tempname()
local function write(path, text, exec)
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
	local f = assert(io.open(path, "w"))
	f:write(text)
	f:close()
	if exec then
		vim.uv.fs_chmod(path, tonumber("755", 8))
	end
end

local SHIM = '#!/bin/bash\necho "[npm→pnpm] Redirecting \\"npm $*\\" to pnpm." >&2\nexec corepack pnpm "$@"\n'
local REAL = "#!/usr/bin/env node\n// the real npm entry point\n"

-- 1. Detection on file contents.
write(root .. "/shim/npm", SHIM, true)
write(root .. "/real/npm", REAL, true)
write(root .. "/binary/npm", "\127ELF....", true)
ok(guard.is_shim(root .. "/shim/npm"), "a script that forwards to pnpm is a stand-in")
ok(not guard.is_shim(root .. "/real/npm"), "npm's own entry point is not")
ok(not guard.is_shim(root .. "/binary/npm"), "a binary is not")
ok(not guard.is_shim(root .. "/missing/npm"), "a missing file is not")
ok(not guard.is_shim(nil), "nil is not")

-- 2. A stand-in first on PATH, a real npm beside node: the link is made.
write(root .. "/prefix/bin/node", "#!/bin/sh\nexit 0\n", true)
write(root .. "/prefix/lib/node_modules/npm/bin/npm-cli.js", REAL, true)
local saved = vim.env.PATH
vim.env.PATH = root .. "/shim:" .. root .. "/prefix/bin:" .. saved
local res = guard.ensure(root .. "/data")
ok(res.ok and res.fixed == root .. "/data/dwp-bin", "ensure reports the link directory")
ok(
	vim.uv.fs_readlink(root .. "/data/dwp-bin/npm") == root .. "/prefix/lib/node_modules/npm/bin/npm-cli.js",
	"the link points at the real npm entry point"
)
ok(vim.env.PATH:sub(1, #(root .. "/data/dwp-bin")) == root .. "/data/dwp-bin", "the link directory is first on PATH")
ok(vim.fn.exepath("npm") == root .. "/data/dwp-bin/npm", "npm now resolves to the real one")

-- 3. Idempotent: a second call neither duplicates PATH nor fails.
local before = vim.env.PATH
local again = guard.ensure(root .. "/data")
ok(again.ok and vim.env.PATH == before, "a second ensure changes nothing")

-- 4. A real npm first on PATH: nothing to fix.
vim.env.PATH = root .. "/real:" .. saved
local clean = guard.ensure(root .. "/data2")
ok(clean.ok and clean.fixed == nil, "a real npm is left alone")
ok(vim.fn.isdirectory(root .. "/data2/dwp-bin") == 0, "and no directory is created")

-- 5. A stand-in with no real npm beside node: reported, not guessed.
vim.env.PATH = root .. "/shim:" .. saved
write(root .. "/lonely/bin/node", "#!/bin/sh\nexit 0\n", true)
vim.env.PATH = root .. "/shim:" .. root .. "/lonely/bin:" .. saved
local stuck = guard.ensure(root .. "/data3")
ok(not stuck.ok and stuck.reason:find("stand%-in") ~= nil, "no real npm: reported with a reason")

-- 6. No npm at all.
vim.env.PATH = root .. "/prefix/bin"
local none = guard.ensure(root .. "/data4")
ok(not none.ok and none.reason:find("not found") ~= nil, "no npm on PATH: reported")

vim.env.PATH = saved
vim.fn.delete(root, "rf")

if fails > 0 then
	print(("NPM GUARD SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("NPM GUARD SMOKE: %d assertions OK"):format(count))
end
