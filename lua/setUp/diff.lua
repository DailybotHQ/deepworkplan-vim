local ok, diffview = pcall(require, "diffview")
if not ok then
  return
end

local function confirm_restore(callback)
  local actions = require("diffview.actions")
  vim.ui.select({ "Discard changes", "Keep" }, {
    prompt = "Discard this file's changes?",
  }, function(choice)
    if choice == "Discard changes" then
      actions.restore_entry()
    end
    if callback then
      callback()
    end
  end)
end

diffview.setup({
  enhanced_diff_hl = true,
  keymaps = {
    file_panel = {
      -- d and right-click discard the file under the cursor. X stays as the
      -- plugin default, without a prompt.
      { "n", "d", confirm_restore, { desc = "Discard this file's changes" } },
      {
        "n",
        "<RightMouse>",
        function()
          local actions = require("diffview.actions")
          actions.select_entry()
          confirm_restore()
        end,
        { desc = "Discard the file under the pointer" },
      },
    },
  },
})

-- Space+g+d uses Diffview* groups. Those are created once, with `default`,
-- so a later :MuvimTheme / Space+t+h never reaches them. Re-apply after
-- every palette paint, and force the groups that enhanced mode remaps
-- (filler dashes, deleted side) onto the active theme instead of Comment.
local function paint_diff()
  local hl_ok, hl = pcall(require, "diffview.hl")
  if hl_ok then
    hl.setup()
  end
  local p = vim.g.muvim_palette
  if type(p) ~= "table" or not p.fg or not p.bg then
    return
  end
  local function mix(top, alpha)
    local function chans(hex)
      hex = hex:gsub("#", "")
      return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
    end
    local tr, tg, tb = chans(top)
    local br, bgc, bb = chans(p.bg)
    local function blend(t, b)
      return math.floor(b + (t - b) * alpha + 0.5)
    end
    return string.format("#%02x%02x%02x", blend(tr, br), blend(tg, bgc), blend(tb, bb))
  end
  local add_line = mix(p.green or p.fg, 0.34)
  local del_line = mix(p.red or p.fg, 0.34)
  local chg_line = mix(p.yellow or p.fg, 0.28)
  local chg_word = mix(p.yellow or p.fg, 0.55)
  local function set(name, spec)
    vim.api.nvim_set_hl(0, name, spec)
  end
  set("DiffAdd", { bg = add_line, fg = p.fg })
  set("DiffDelete", { bg = del_line, fg = p.red or p.fg })
  set("DiffChange", { bg = chg_line, fg = p.fg })
  set("DiffText", { bg = chg_word, fg = p.fg })
  set("DiffviewDiffAddAsDelete", { bg = del_line, fg = p.fg })
  -- Filler rows and the deleted side. Comment is too dim on a tinted line.
  set("DiffviewDiffDeleteDim", { fg = p.fg, bg = del_line })
  set("DiffviewDiffDelete", { fg = p.fg, bg = del_line })
  set("DiffviewDiffAdd", { bg = add_line, fg = p.fg })
  set("DiffviewDiffChange", { bg = chg_line, fg = p.fg })
  set("DiffviewDiffText", { bg = chg_word, fg = p.fg })
end

paint_diff()

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("MuvimDiffTheme", { clear = true }),
  callback = function()
    vim.schedule(paint_diff)
  end,
})
