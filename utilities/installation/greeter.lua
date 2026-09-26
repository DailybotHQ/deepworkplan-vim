--[[
  utilities/installation/greeter.lua

  Port of greeter.sh. Centering uses the original /8 and /2 shifts so the
  banner looks the same as the bash installer.
]]

local M = {}

local TITLE = "Hey there, thanks for giving DeepWorkPlan Vim a try. Welcome to"

local BANNER = {
  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⡆⡆⠀⠀⠀⠀⠀⠀⠜⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠀⢠⠁⢰⠀⠀⠀⠀⢀⠊⢠⠀⠀⢠⠀⠀⠀⠀⢠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠀⠘⠀⠀⡆⠀⠀⠠⠃⠀⡘⠀⠀⡘⠀⠀⠀⠀⡘⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⢰⠀⡰⠁⠀⠀⠇⠀⠀⡇⠀⠀⠀⢀⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠰⠀⠀⠀⠀⠞⠀⠀⠀⠰⠀⠀⢰⠑⠤⠤⠔⠱⠀⣿⡆⠀⠀⠀⣾⡗⠀⠀⠰⣿⠆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡌⠀⠀⠀⠀⠀⠀⠸⣿⡄⠀⣸⣿⠁⠀⣴⣶⣶⡄⠀⠀⢰⣦⣶⣤⣴⣶⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣷⢠⣿⠇⠀⠀⠀⠀⣿⡇⠀⠀⢸⣿⠀⣿⡏⠈⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⡟⠀⠀⠀⠀⠀⣿⡇⠀⠀⢸⣿⠀⣿⡇⠀⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠿⠁⠀⠀⠀⠀⠀⠿⠿⠿⠀⠸⠟⠀⠻⠇⠀⠿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
  "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
}

-- Terminal width via tput cols; 80 if there is no tty.
local function term_width()
  local handle = io.popen("tput cols 2>/dev/null < /dev/tty", "r")
  if not handle then return 80 end
  local out = handle:read("*l")
  handle:close()
  local width = tonumber(out)
  return width or 80
end

-- Character length so the braille banner centers the same as in bash.
-- Lua 5.1, which Debian still ships as `lua`, has no utf8 library.
local function display_len(s)
  if utf8 and utf8.len then
    return utf8.len(s) or #s
  end
  local _, count = s:gsub("[\192-\255]", "")
  return #s - count
end

-- printf '%*s' right-justifies `text` inside a field of width `field_width`,
-- i.e. it pads with (field_width - len(text)) spaces, NOT `field_width`
-- spaces followed by the text. Replicated here explicitly since Lua has no
-- direct equivalent to bash's `%*s`.
local function right_justify(text, field_width)
  local pad = field_width - display_len(text)
  if pad < 0 then pad = 0 end
  return string.rep(" ", pad) .. text
end

function M.greeter()
  local width = term_width()
  local title_shift = math.floor((display_len(TITLE) + width) / 8)
  local banner_shift = math.floor((display_len(BANNER[1]) + width) / 2)

  io.write(right_justify(TITLE, title_shift) .. "\n")

  for _, line in ipairs(BANNER) do
    io.write(right_justify(line, banner_shift) .. "\n")
  end

  return true
end

return M
