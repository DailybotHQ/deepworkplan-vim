local custom = require("mapping.util.extention")
-- Set new keymap
local map = vim.keymap.set

-- Options
local opts = { noremap = true, silent = true }

-- vCoolor
map("n", "<Leader>r", ":VCoolIns ra<CR>", { desc = "Insert a color" })

-- Auto save
map("n", "<leader>aw", ":ASToggle<CR>", { desc = "Toggle autosave" })

-- Formatter
map("n", "<leader>f", ":Format<CR>", { desc = "Format the file" })

-- Extentions
map("n", "<Leader>hh", function()
	require("mapping.glossary").open()
end, { desc = "Open the command glossary" })
map("n", "<Leader>th", function()
	require("scheme.picker").open()
end, { desc = "Pick a color theme" })

map("n", "<Leader>x", function()
	custom.OpenFileServer()
end, { desc = "Run or preview the current file (markdown: browser preview)" })

-- Terminal
map("n", "<C-t>", function()
	custom.OpenTerminal()
end, { noremap = true, silent = true, desc = "Open a terminal on the left" })
