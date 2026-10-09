--[[
  utilities/installation/util.lua

  OS detection, portable paths, and package-manager lookup.
  Linux: pacman, apt-get, dnf. macOS: Homebrew. Windows: winget.
]]

local cli = require("utilities.installation.cli")

local M = {}

function M.pwd()
  local cmd = M.is_windows() and "cd" or "pwd -P"
  local handle = io.popen(cmd .. " 2>/dev/null")
  if not handle then
    return ""
  end
  local dir = handle:read("*l") or ""
  handle:close()
  return dir
end

function M.make_absolute(path)
  if not path or path == "" or path == "." or path == "./" then
    return M.realpath(M.pwd())
  end
  if M.is_absolute(path) then
    return M.realpath(path)
  end
  path = path:gsub("^%./", "")
  return M.realpath(M.path_join(M.pwd(), path))
end

function M.path_is_under(child, parent)
  if child == "" or parent == "" then
    return false
  end
  if child == parent then
    return true
  end
  local prefix = parent
  if not prefix:match("[/\\]$") then
    prefix = prefix .. (M.is_windows() and "\\" or "/")
  end
  return child:sub(1, #prefix) == prefix
end

-- Run from $HOME so brew/pip/pnpm still work if the config dir was moved.
function M.exec_ok(cmd)
  local root = M.home()
  if root ~= "" then
    if M.is_windows() then
      cmd = string.format('cd /d "%s" && %s', root, cmd)
    else
      cmd = string.format('cd "%s" && %s', root, cmd)
    end
  end
  local a = os.execute(cmd)
  if type(a) == "number" then
    return a == 0
  end
  return a == true
end

function M.is_windows()
  if (os.getenv("OS") or ""):match("Windows") then
    return true
  end
  return package.config:sub(1, 1) == "\\"
end

function M.uname()
  if M.is_windows() then
    return "Windows"
  end
  local handle = io.popen("uname -s 2>/dev/null")
  if not handle then
    return "Linux"
  end
  local name = handle:read("*l") or ""
  handle:close()
  return name
end

function M.is_darwin()
  return M.uname() == "Darwin"
end

function M.home()
  local home = os.getenv("HOME") or os.getenv("USERPROFILE") or ""
  return home
end

function M.data_home()
  if M.is_windows() then
    return os.getenv("LOCALAPPDATA") or (M.home() .. "\\AppData\\Local")
  end
  local xdg = os.getenv("XDG_DATA_HOME")
  if xdg and xdg ~= "" then
    return xdg
  end
  return M.home() .. "/.local/share"
end

function M.path_join(...)
  local sep = M.is_windows() and "\\" or "/"
  local parts = {}
  for i = 1, select("#", ...) do
    local part = select(i, ...)
    if part and part ~= "" then
      part = part:gsub("[/\\]+$", "")
      parts[#parts + 1] = part
    end
  end
  return table.concat(parts, sep)
end

function M.nvim_config_dir()
  if M.is_windows() then
    return M.path_join(M.data_home(), "nvim")
  end
  return M.path_join(M.home(), ".config", "nvim")
end

function M.file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

function M.dir_exists(path)
  if M.is_windows() then
    return M.exec_ok(string.format('if exist "%s\\" (exit 0) else (exit 1)', path))
  end
  return M.exec_ok(string.format('[ -d "%s" ]', path))
end

function M.path_exists(path)
  if M.is_windows() then
    return M.exec_ok(string.format('if exist "%s" (exit 0) else (exit 1)', path))
  end
  return M.exec_ok(string.format('[ -e "%s" ]', path))
end

function M.has_command(cmd)
  if M.is_windows() then
    return M.exec_ok(string.format('where %s >nul 2>nul', cmd))
  end
  return M.exec_ok("command -v " .. cmd .. " >/dev/null 2>&1")
end

function M.mkdir_p(path)
  if M.is_windows() then
    return M.exec_ok(string.format('mkdir "%s" 2>nul', path)) or M.dir_exists(path)
  end
  return M.exec_ok(string.format('mkdir -p -- "%s"', path))
end

function M.copy_file(src, dest_dir)
  if M.is_windows() then
    return M.exec_ok(string.format('copy /Y "%s" "%s"', src, dest_dir))
  end
  return M.exec_ok(string.format('cp -- "%s" "%s/"', src, dest_dir))
end

function M.mv(src, dest)
  if M.is_windows() then
    return M.exec_ok(string.format('move /Y "%s" "%s"', src, dest))
  end
  return M.exec_ok(string.format('mv -- "%s" "%s"', src, dest))
end

function M.rm_rf(path)
  if M.is_windows() then
    return M.exec_ok(string.format('rmdir /S /Q "%s"', path))
      or M.exec_ok(string.format('del /F /Q "%s"', path))
  end
  return M.exec_ok(string.format('rm -rf -- "%s"', path))
end

function M.is_absolute(path)
  if M.is_windows() then
    return path:match("^[%a]:") or path:match("^\\\\")
  end
  return path:sub(1, 1) == "/"
end

-- Pure-Lua path resolution for when GNU `realpath -m` is unavailable —
-- macOS BSD realpath rejects -m, and some minimal images ship no realpath
-- at all. Expands a leading ~ to $HOME, makes the path absolute against
-- the physical cwd, and collapses `.` / `..` / duplicate separators. It
-- does NOT resolve symlinks: callers use the result for prefix
-- comparisons (the run-from-inside guard), where syntactic normalization
-- is what the comparison needs (installer audit I-7).
local function resolve_in_lua(path)
  local p = path
  local home = M.home()
  if p == "~" then
    p = home
  elseif p:sub(1, 2) == "~/" then
    p = home .. p:sub(2)
  end
  if not M.is_absolute(p) then
    local cwd = M.pwd()
    if cwd ~= "" then
      p = cwd .. "/" .. p
    end
  end
  local parts = {}
  local leading = (p:sub(1, 1) == "/") and "/" or ""
  for seg in p:gmatch("[^/]+") do
    if seg ~= "." then
      if seg == ".." then
        if #parts > 0 then
          table.remove(parts)
        end
      else
        parts[#parts + 1] = seg
      end
    end
  end
  local resolved = leading .. table.concat(parts, "/")
  if resolved == "" then
    resolved = "/"
  end
  return resolved
end

function M.realpath(path)
  if M.is_windows() then
    return path
  end
  local handle = io.popen('realpath -m -- "' .. path .. '" 2>/dev/null')
  if handle then
    local resolved = handle:read("*l")
    handle:close()
    -- GNU realpath -m prints an absolute path even for non-existent
    -- input; a rejecting or missing realpath prints nothing at all —
    -- fall through to the Lua resolution instead of returning the input
    -- unresolved.
    if resolved and resolved ~= "" and resolved:sub(1, 1) == "/" then
      return resolved
    end
  end
  return resolve_in_lua(path)
end

function M.get_package_manager()
  if M.is_windows() then
    if M.has_command("winget") then
      return "winget"
    end
    return nil, "Install winget (App Installer from Microsoft Store)"
  end
  if M.is_darwin() then
    if M.has_command("brew") then
      return "brew"
    end
    return nil, "Install Homebrew from https://brew.sh"
  end
  if M.has_command("pacman") then
    return "pacman"
  end
  if M.has_command("apt-get") then
    return "apt-get"
  end
  if M.has_command("dnf") then
    return "dnf"
  end
  local release_files = {
    { "/etc/arch-release", "pacman" },
    { "/etc/debian_version", "apt-get" },
    { "/etc/redhat-release", "dnf" },
    { "/etc/fedora-release", "dnf" },
  }
  for _, entry in ipairs(release_files) do
    if M.file_exists(entry[1]) then
      return entry[2]
    end
  end
  return nil, "No supported package manager detected (need pacman, apt, dnf, brew, or winget)"
end

function M.needs_sudo(manager)
  return manager == "pacman" or manager == "apt-get" or manager == "dnf"
end

-- Root (the usual case inside containers) has no sudo binary and needs
-- none; package commands must then run bare. Windows never gets here.
function M.is_root()
  if M.is_windows() then
    return false
  end
  local handle = io.popen("id -u 2>/dev/null")
  if not handle then
    return false
  end
  local uid = handle:read("*l")
  handle:close()
  return uid == "0"
end

function M.replace_old(target, backup_dir)
  if not M.path_exists(target) then
    return true
  end

  -- An existing config is never moved or deleted by a run that cannot
  -- ask (piped without a terminal) — the same rule install.sh enforces.
  -- Before this gate, a headless run auto-answered the prompt and moved
  -- the config; declining (rm_rf) was reachable by EOF as well. R4
  -- (PLAN_004 final review) closed the Windows gap: can_ask is
  -- unconditionally true there (no /dev/tty convention), so the ask is
  -- attempted and ABSENT INPUT (EOF) is refused below — neither branch
  -- of the question may be auto-taken.
  local can_ask = false
  if package.config:sub(1, 1) == "\\" then
    can_ask = true -- Windows line input: ask optimistically; EOF aborts below
  else
    local tty = io.open("/dev/tty", "r")
    if tty then
      tty:close()
      can_ask = true
    end
  end
  if not can_ask then
    io.stderr:write(
      "A previous config exists at " .. target .. " and this run has no terminal to ask what to do.\n" ..
      "Move it aside first (mv '" .. target .. "' '" .. backup_dir .. "') or rerun interactively. Nothing was touched.\n"
    )
    return false
  end

  while true do
    local keep, source = cli.confirm(
      "A previous config exists at " .. target .. ". Keep it as a backup?",
      true
    )
    if source == "eof" then
      -- Absent input is not an answer: Yes moves the config and No
      -- deletes it, so the run aborts exactly like the cannot-ask gate.
      io.stderr:write(
        "A previous config exists at " .. target .. " and the question got no answer (input ended).\n" ..
        "Move it aside first (mv '" .. target .. "' '" .. backup_dir .. "') or rerun interactively. Nothing was touched.\n"
      )
      return false
    end

    if keep then
      local parent = backup_dir:match("(.+)[/\\]") or "."
      if not M.mkdir_p(parent) then
        io.stderr:write("Could not create the parent directory of " .. backup_dir .. "\n")
        return false
      end
      if M.path_exists(backup_dir) then
        io.stderr:write("Backup destination already exists: " .. backup_dir .. "\n")
        return false
      end
      io.write("Backing up the existing config to " .. backup_dir .. "\n")
      return M.mv(target, backup_dir)
    else
      io.write("Removing the previous config\n")
      return M.rm_rf(target)
    end
  end
end

return M
