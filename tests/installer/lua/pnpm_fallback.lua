-- tests/installer/lua/pnpm_fallback.lua — runs the REAL
-- utilities/installation/installer.lua ensure_pnpm() with a stubbed util
-- (no command runs) and prints what it would execute, one line per call:
--   RESULT <true|false>
--   EXEC <command>
-- Usage: lua5.4 pnpm_fallback.lua <repo> <unix|windows> <npm|no-npm|apt-adds-npm> [node-major] [home]
--   apt-adds-npm: npm is missing until an apt install of it runs.
local repo, os_kind, npm, node, home = arg[1], arg[2], arg[3], arg[4], arg[5] or "/stub-home"
package.path = repo .. "/?.lua;" .. package.path

local execs = {}
local npm_present = npm == "npm"
package.preload["utilities.installation.util"] = function()
  return {
    is_windows = function() return os_kind == "windows" end,
    is_root = function() return false end,
    has_command = function(cmd) return cmd == "npm" and npm_present end,
    exec_ok = function(cmd)
      execs[#execs + 1] = cmd
      if npm == "apt-adds-npm" and cmd:find("apt-get install -y npm", 1, true) then
        npm_present = true
      end
      return true
    end,
    mkdir_p = function() return true end,
    home = function() return home end,
    path_join = function(...) return table.concat({ ... }, "/") end,
    data_home = function() return home .. "/.local/share" end,
  }
end

local installer = require("utilities.installation.installer")
installer.node_major = function() return tonumber(node or "") end
local ok = installer.ensure_pnpm(os_kind == "windows" and "winget" or "apt-get")
print("RESULT " .. tostring(ok))
for _, cmd in ipairs(execs) do
  print("EXEC " .. cmd)
end
