--[[
  utilities/installation/installer.lua

  Install Neovim deps for pacman, apt, dnf, Homebrew, and winget.
  Package names are remapped per manager. pnpm is a core requirement;
  if the distro has no pnpm package, npm installs it under the user prefix
  (no downloaded script is ever piped into a shell).
]]

local util = require("utilities.installation.util")

local M = {}

-- Display names used in the extras checklist (manager-agnostic).
M.EXTRA_PACKAGES = {
  { name = "zenity", desc = "GUI dialogs used by some scripts (Linux)" },
  { name = "shfmt", desc = "Shell script formatter" },
  { name = "stylua", desc = "Lua formatter" },
  { name = "black", desc = "Python formatter" },
}

local CORE_BY_MANAGER = {
  pacman = { "neovim", "nodejs", "pnpm", "ripgrep", "fd", "python-neovim", "luarocks" },
  ["apt-get"] = { "neovim", "nodejs", "ripgrep", "fd-find", "python3-neovim", "luarocks" },
  dnf = { "neovim", "nodejs", "ripgrep", "fd-find", "python3-neovim", "luarocks" },
  brew = { "neovim", "node", "pnpm", "ripgrep", "fd", "luarocks" },
}

local EXTRA_BY_MANAGER = {
  pacman = { zenity = "zenity", shfmt = "shfmt", stylua = "stylua", black = "python-black" },
  ["apt-get"] = { zenity = "zenity", shfmt = "shfmt", black = "black" },
  dnf = { zenity = "zenity", shfmt = "shfmt", black = "python3-black" },
  brew = { shfmt = "shfmt", stylua = "stylua", black = "black" },
}

-- winget uses package ids, not distro names.
local WINGET_CORE = {
  { id = "Neovim.Neovim", name = "neovim" },
  { id = "OpenJS.NodeJS.LTS", name = "nodejs" },
  { id = "pnpm.pnpm", name = "pnpm" },
  { id = "BurntSushi.ripgrep.MSVC", name = "ripgrep" },
  { id = "sharkdp.fd", name = "fd" },
}

local WINGET_EXTRA = {
  shfmt = "mvdan.Shfmt",
  stylua = "JohnnyMorganz.StyLua",
}

local function exec_ok(cmd)
  return util.exec_ok(cmd)
end

-- Defined further down; ensure_pnpm needs it to add npm on demand.
local install_unix_packages

-- pnpm major this config installs when the system has none, and the oldest
-- Node.js that runs it.
M.PNPM_SPEC = "pnpm@10"
M.PNPM_MIN_NODE = 18

-- Major version of the node on PATH, or nil when it cannot be read.
function M.node_major()
  local handle = io.popen("node --version 2>/dev/null")
  if not handle then
    return nil
  end
  local out = handle:read("*a") or ""
  handle:close()
  return tonumber(out:match("^v(%d+)"))
end

-- Escape a value for use inside a double-quoted POSIX shell word.
local function sh_dq(value)
  return (value:gsub('[\\"$`]', "\\%0"))
end

function M.core_packages(manager)
  return CORE_BY_MANAGER[manager] or {}
end

function M.resolve_extras(manager, chosen)
  local mapped = {}
  local table_for = EXTRA_BY_MANAGER[manager] or {}
  for _, name in ipairs(chosen) do
    if manager == "winget" then
      if WINGET_EXTRA[name] then
        mapped[#mapped + 1] = { kind = "winget", id = WINGET_EXTRA[name] }
      end
    elseif table_for[name] then
      mapped[#mapped + 1] = table_for[name]
    end
  end
  return mapped
end

M.PCKR_URL = "https://github.com/lewis6991/pckr.nvim"

-- pckr's pinned commit from the config's pckr/lockfile.lua (a plain
-- `return { [url] = { commit = sha } }` table), or nil when the config
-- carries no lock (releases before v0.5.1). Only a full 40-hex sha is
-- returned: the value reaches a shell command.
function M.pckr_pin(config_dir)
  if not config_dir then
    return nil
  end
  local ok, lock = pcall(dofile, util.path_join(config_dir, "pckr", "lockfile.lua"))
  local entry = ok and type(lock) == "table" and lock[M.PCKR_URL] or nil
  local sha = type(entry) == "table" and entry.commit or nil
  if type(sha) == "string" and sha:match("^%x+$") and #sha == 40 then
    return sha
  end
  return nil
end

function M.install_pckr(config_dir)
  -- Same path plugins.lua uses: stdpath("data")/pckr/pckr.nvim — where
  -- stdpath("data") follows the ACTIVE appname, which is the checkout's
  -- basename for a custom DWP_VIM_DIR (install.sh composes the same way
  -- for its bootstrap). Compose it from the config dir this installer
  -- runs from instead of hard-coding "nvim".
  local appname = (config_dir and config_dir:match("[^/\\]+$")) or "nvim"
  local pckr_dir = util.path_join(util.data_home(), appname, "pckr", "pckr.nvim")

  if util.dir_exists(pckr_dir) then
    io.write("pckr.nvim already present, skipping clone\n")
    return true
  end

  util.mkdir_p(pckr_dir:match("(.+)[/\\][^/\\]+$") or pckr_dir)
  local ok = exec_ok('git clone --filter=blob:none ' .. M.PCKR_URL .. ' "' .. pckr_dir .. '"')
  if not ok then
    io.stderr:write("Failed to clone pckr.nvim\n")
    return false
  end
  -- Check out the commit the config's lock pins. A failure is a warning,
  -- the same policy as lua/plugins.lua, which retries on the installer's
  -- headless bootstrap (fetching first); install.sh --strict then fails if
  -- pckr is still away from its pin.
  local pin = M.pckr_pin(config_dir)
  if pin and not exec_ok('git -C "' .. pckr_dir .. '" checkout -q ' .. pin) then
    io.stderr:write("Warning: could not check out pckr.nvim at its pinned commit " .. pin .. "\n")
  end
  return true
end

function M.pnpm_home()
  if util.is_windows() then
    return util.path_join(util.data_home(), "pnpm")
  end
  return util.path_join(util.home(), ".local", "share", "pnpm")
end

function M.pnpm_bin()
  return util.path_join(M.pnpm_home(), "bin")
end

-- pnpm 10+ refuses `pnpm add -g` unless PNPM_HOME/bin is on PATH
-- (ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH). The home directory alone is not enough.
function M.pnpm_env()
  local home = M.pnpm_home()
  local bin = M.pnpm_bin()
  if util.is_windows() then
    return string.format('set PNPM_HOME=%s&& set PATH=%s;%%PATH%%&& ', home, bin)
  end
  return string.format('PNPM_HOME="%s" PATH="%s:$PATH" ', home, bin)
end

-- npm installs pnpm from the registry: no downloaded script is ever piped
-- into a shell. On Unix it goes under the user prefix PNPM_HOME, whose bin/
-- pnpm_env() puts on PATH. `manager` (optional) adds a missing npm first —
-- separately from the core batch, because Debian's npm package conflicts
-- with the npm NodeSource's nodejs already bundles.
function M.ensure_pnpm(manager)
  util.mkdir_p(M.pnpm_home())
  if util.has_command("pnpm") then
    return true
  end
  if not util.has_command("npm") and manager and manager ~= "winget" and not util.is_windows() then
    io.write("npm is not on PATH, installing it with " .. manager .. "\n")
    install_unix_packages(manager, { "npm" })
  end
  if not util.has_command("npm") then
    io.stderr:write("pnpm is missing and npm is not available to install it: install Node.js with npm, then rerun\n")
    return false
  end
  local major = M.node_major()
  if major and major < M.PNPM_MIN_NODE then
    io.stderr:write(
      string.format(
        "Node.js %d is too old for %s (needs %d+): install a newer Node.js, then rerun\n",
        major,
        M.PNPM_SPEC,
        M.PNPM_MIN_NODE
      )
    )
    return false
  end
  io.write("pnpm is not on PATH, installing " .. M.PNPM_SPEC .. " with npm (user prefix)\n")
  if util.is_windows() then
    return exec_ok("npm install -g --ignore-scripts " .. M.PNPM_SPEC)
  end
  return exec_ok(
    string.format('npm install -g --ignore-scripts --prefix "%s" %s', sh_dq(M.pnpm_home()), M.PNPM_SPEC)
  )
end

-- Global pnpm packages go under the user prefix. A system PNPM_HOME
-- under /usr/local is not writable and fails with "create global install dir".
function M.ensure_formatters()
  local status = true
  local env = M.pnpm_env()
  if not util.has_command("biome") then
    io.write("Installing biome with pnpm (user prefix)\n")
    if not exec_ok(env .. "pnpm add -g @biomejs/biome") then
      io.stderr:write("Could not install biome with pnpm\n")
      status = false
    end
  end
  if not util.has_command("black") then
    io.write("Installing black with pip\n")
    if not exec_ok("pip3 install --user black") and not exec_ok("pip install --user black") and not exec_ok("brew install black") then
      io.stderr:write("Could not install black\n")
      status = false
    end
  end
  return status
end

install_unix_packages = function(manager, packages)
  local pkg_list = table.concat(packages, " ")
  -- Root (common in containers) has no sudo binary and needs none.
  local sudo = util.is_root() and "" or "sudo "
  local commands = {
    ["apt-get"] = sudo .. "apt-get update && " .. sudo .. "apt-get install -y " .. pkg_list,
    pacman = sudo .. "pacman -Sy --noconfirm " .. pkg_list,
    dnf = sudo .. "dnf install -y " .. pkg_list,
    -- brew exits non-zero when a keg is already present but not linked
    -- (node@22 leaves a corepack pnpm symlink). The packages are installed.
    brew = "brew install " .. pkg_list .. " || brew list --formula " .. pkg_list .. " >/dev/null",
  }
  local command = commands[manager]
  if command == nil then
    return false
  end
  return exec_ok(command)
end

local function install_winget(id)
  return exec_ok(
    'winget install -e --id ' .. id .. " --accept-package-agreements --accept-source-agreements"
  )
end

function M.installDependencies(manager, extra_names, config_dir)
  extra_names = extra_names or {}
  if manager == nil or manager == "" then
    io.stderr:write("installDependencies: expected a package manager name\n")
    return false
  end

  local status = true

  if not M.install_pckr(config_dir) then
    status = false
  end

  if manager == "winget" then
    for _, pkg in ipairs(WINGET_CORE) do
      io.write("winget install " .. pkg.id .. "\n")
      if not install_winget(pkg.id) then
        io.stderr:write("winget failed for " .. pkg.id .. "\n")
        status = false
      end
    end
    for _, extra in ipairs(M.resolve_extras("winget", extra_names)) do
      io.write("winget install " .. extra.id .. "\n")
      if not install_winget(extra.id) then
        status = false
      end
    end
    if not exec_ok("pip install --user pynvim") and not exec_ok("pip3 install --user pynvim") then
      io.write("Could not pip-install pynvim; :checkhealth will say so.\n")
    end
  else
    local packages = {}
    for _, name in ipairs(M.core_packages(manager)) do
      packages[#packages + 1] = name
    end
    for _, name in ipairs(M.resolve_extras(manager, extra_names)) do
      packages[#packages + 1] = name
    end
    if #packages == 0 then
      io.stderr:write("installDependencies: no packages mapped for " .. manager .. "\n")
      return false
    end
    io.write("Installing with " .. manager .. ": " .. table.concat(packages, " ") .. "\n")
    if not install_unix_packages(manager, packages) then
      status = false
    end
    if manager == "brew" then
      exec_ok("pip3 install --user pynvim")
    end
  end

  if not M.ensure_pnpm(manager) then
    io.stderr:write("Could not install pnpm\n")
    status = false
  end

  if not M.ensure_formatters() then
    status = false
  end

  return status
end

function M.install_font(font_path)
  if not util.file_exists(font_path) then
    io.stderr:write("[ERROR] Font source not found: " .. font_path .. "\n")
    return false
  end

  local fonts_dir
  if util.is_windows() then
    fonts_dir = util.path_join(util.data_home(), "Microsoft", "Windows", "Fonts")
  elseif util.is_darwin() then
    fonts_dir = util.path_join(util.home(), "Library", "Fonts")
  else
    fonts_dir = util.path_join(util.home(), ".local", "share", "fonts")
  end

  if not util.mkdir_p(fonts_dir) then
    io.stderr:write("The fonts directory could not load: " .. fonts_dir .. "\n")
    return false
  end

  if not util.copy_file(font_path, fonts_dir) then
    io.stderr:write("[ERROR] The font was not added " .. fonts_dir .. "\n")
    return false
  end

  if not util.is_darwin() and not util.is_windows() and util.has_command("fc-cache") then
    exec_ok('fc-cache -f "' .. fonts_dir .. '" >/dev/null 2>&1')
  end

  return true
end

return M
