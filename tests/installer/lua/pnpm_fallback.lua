-- tests/installer/lua/pnpm_fallback.lua — runs the REAL
-- utilities/installation/installer.lua ensure_pnpm() with a stubbed util
-- (no command runs) and prints what it would execute, one line per call:
--   RESULT <true|false>
--   EXEC <command>
-- Usage: lua5.4 pnpm_fallback.lua <repo> <unix|windows> <npm|no-npm>
local repo, os_kind, npm = arg[1], arg[2], arg[3]
package.path = repo .. "/?.lua;" .. package.path

local execs = {}
package.preload["utilities.installation.util"] = function()
  return {
    is_windows = function() return os_kind == "windows" end,
    has_command = function(cmd) return cmd == "npm" and npm == "npm" end,
    exec_ok = function(cmd) execs[#execs + 1] = cmd; return true end,
    mkdir_p = function() return true end,
    home = function() return "/home/u" end,
    path_join = function(...) return table.concat({ ... }, "/") end,
    data_home = function() return "/home/u/.local/share" end,
  }
end

local installer = require("utilities.installation.installer")
local ok = installer.ensure_pnpm()
print("RESULT " .. tostring(ok))
for _, cmd in ipairs(execs) do
  print("EXEC " .. cmd)
end
