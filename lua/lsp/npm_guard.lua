-- Mason installs most language servers with `npm` (npm init, npm install).
-- Some environments put an `npm` on PATH that is not npm: a shell script that
-- forwards to pnpm ("this repo uses pnpm"). pnpm rejects npm's flags
-- (`npm init --scope=mason` -> "unexpected argument '--scope'"), so every npm
-- based server fails to install, on every start. This module detects such a
-- stand-in and puts the real npm first on PATH, for Neovim and the processes
-- Mason spawns. Pure functions plus one `ensure`; cheap (two small file reads).
local M = {}

-- The first bytes of the file behind `path`, or nil.
local function head(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local s = f:read(512)
  f:close()
  return s
end

--- True when `path` is a script that stands in for npm (forwards to pnpm).
function M.is_shim(path)
  local s = path and head(path)
  if not s or s:sub(1, 2) ~= "#!" then
    return false
  end
  return s:find("pnpm", 1, true) ~= nil or s:find("Redirecting", 1, true) ~= nil
end

--- The real npm entry point that ships next to `node`, or nil.
function M.real_npm_cli()
  local node = vim.fn.exepath("node")
  if node == "" then
    return nil
  end
  local prefix = vim.fn.fnamemodify(vim.uv.fs_realpath(node) or node, ":h:h")
  local cli = prefix .. "/lib/node_modules/npm/bin/npm-cli.js"
  if vim.uv.fs_stat(cli) then
    return cli
  end
  return nil
end

--- Make `npm` the real npm for this Neovim session.
--- Returns { ok = true } when npm was already fine, { ok = true, fixed = dir }
--- after putting a real-npm link first on PATH, or { ok = false, reason = ... }
--- when npm is a stand-in and no real npm can be found.
--- Mason snapshots the environment when its process module first loads, so this
--- must run before anything requires mason-registry (lsp/init.lua runs it first).
--- The default call is memoised: later callers get the same answer.
---@param data_dir string|nil where the link directory lives (default stdpath("data"))
function M.ensure(data_dir)
  if data_dir == nil and M._state then
    return M._state
  end
  local state = M._ensure(data_dir)
  if data_dir == nil then
    M._state = state
  end
  return state
end

function M._ensure(data_dir)
  local npm = vim.fn.exepath("npm")
  if npm == "" then
    return { ok = false, reason = "npm was not found on PATH" }
  end
  if not M.is_shim(npm) then
    return { ok = true }
  end
  local cli = M.real_npm_cli()
  -- A link to a file that cannot be executed would fail every Mason npm call
  -- silently: treat it as "no real npm" so the warning explains it.
  if cli and not vim.uv.fs_access(cli, "X") then
    cli = nil
  end
  if not cli then
    return { ok = false, reason = "npm on PATH is a pnpm stand-in (" .. npm .. ") and no real npm was found next to node" }
  end
  local dir = (data_dir or vim.fn.stdpath("data")) .. "/dwp-bin"
  vim.fn.mkdir(dir, "p")
  local link = dir .. "/npm"
  local current = vim.uv.fs_readlink(link)
  if current ~= cli then
    vim.uv.fs_unlink(link)
    local ok = vim.uv.fs_symlink(cli, link)
    if not ok then
      return { ok = false, reason = "could not link the real npm into " .. dir }
    end
  end
  if not (vim.env.PATH or ""):find(dir, 1, true) then
    vim.env.PATH = dir .. ":" .. (vim.env.PATH or "")
  end
  return { ok = true, fixed = dir }
end

return M
