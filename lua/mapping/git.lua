local custom = require("mapping.util.extention")
local map = vim.keymap.set

local opts = { noremap = true, silent = true }

-- vim-fugitive (git support)
map("n", "<Leader>gpl", ":Git pull<CR>", { desc = "Pull" })
map("n", "<Leader>gps", ":Git push<CR>", { desc = "Push" })
map("n", "<Leader>gii", ":Git init<CR>", { desc = "Init a repository" })
map("n", "<Leader>gsh", ":Git show<CR>", { desc = "Show the last commit" })
map("n", "<Leader>gbl", ":Git blame<CR>", { desc = "Blame" })
map("n", "<Leader>gc", ":Git commit<CR>", { desc = "Commit" })
map("n", "<Leader>gst", ":Git status<CR>", { desc = "Status" })
map("n", "<Leader>gaa", ":Git add --all<CR>", { desc = "Stage everything" })
map("n", "<Leader>gap", ":Git add % -p<CR>", { desc = "Stage this file in hunks" })
map("n", "<Leader>grv", ":Git remote -v<CR>", { desc = "Show remotes" })

-- Commands that need specification
map("n", "<Leader>gsw", ":Git switch<Space>", { desc = "Switch branch (type the name)" })
map("n", "<Leader>gco", ":Git checkout<Space>", { desc = "Checkout (type the name)" })
map("n", "<Leader>gcb", ":Git checkout -b<Space>", { desc = "Create a branch (type the name)" })

-- Custom action
map("n", "<Leader>gll", function()
	custom.HandleGitCustomActions("pull")
end, { noremap = true, silent = true, desc = "Pull the current branch" })
map("n", "<Leader>gpp", function()
	custom.HandleGitCustomActions("push")
end, { noremap = true, silent = true, desc = "Push the current branch" })
map("n", "<Leader>gpx", function()
	custom.HandleGitCustomActions("push-commit")
end, { noremap = true, silent = true, desc = "Push and set upstream" })


-- To performe different actions
map("n", "<Leader>ggg", ":Git<Space>", { desc = "Type any git command" })

map("n", "<Leader>gd", function()
  local ok, lib = pcall(require, "diffview.lib")
  if ok and lib.get_current_view() then
    vim.cmd("DiffviewClose")
  else
    vim.cmd("DiffviewOpen")
  end
end, { noremap = true, silent = true, desc = "Open or close the diff view" })
