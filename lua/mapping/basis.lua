-- Set new keymap
local map = vim.keymap.set

-- Natives
map("n", "<Leader>w", ":w<CR>", { desc = "Save the file" })
map("n", "<Leader>q", function()
	require("mapping.quit").close()
end, { noremap = true, silent = true, desc = "Close panel, diff, window, or nvim" })
map("n", "<Leader>Q", ":qa!<CR>", { noremap = true, silent = true, desc = "Quit nvim" })
-- Replace
map("n", "<Leader>R", ":%s/_/_/gc", { desc = "Replace in the whole file" })
map("n", "U", "<C-r>", { desc = "Redo" })
-- Tabs motion
map("n", "<Leader>k", ":bnext<CR>", { desc = "Next buffer" })
map("n", "<Leader>h", ":bdelete!<CR>", { desc = "Close this buffer" })
map("n", "<Leader>j", ":bprevious<CR>", { desc = "Previous buffer" })
map("n", "K", "<C-u>", { desc = "Page up" })
map("n", "J", "<C-d>", { desc = "Page down" })
map("n", "<C-k>", "<C-b>", { desc = "Scroll up" })
map("n", "<C-j>", "<C-f>", { desc = "Scroll down" })
-- Buffers control
map("n", "<Leader>H", ":%bd | e# | bd#<CR>", { desc = "Close every other buffer" })
map("n", "<Leader>l", ":ls<CR>", { desc = "List open buffers" })
-- Split control
map("n", "<Leader>vv", ":on<CR>", { desc = "Close the other splits" })
map("n", "<Leader>vj", ":split<CR>", { desc = "Split horizontally" })
map("n", "<Leader>vk", ":vsplit<CR>", { desc = "Split vertically" })
-- Window
map("n", "<Leader><", ':exe "resize " . (winheight(0) * 3/2)<CR>', { desc = "Make this window taller" })
map("n", "<Leader>>", ':exe "resize " . (winheight(0) * 2/3)<CR>', { desc = "Make this window shorter" })
-- Folding
map("v", "f", "zf<CR>", { desc = "Fold the selection" })
map("n", "f", "za<CR>", { desc = "Fold or unfold this block" })
map("n", "fd", "zd<CR>", { desc = "Delete this fold" })
-- VS Code gestures. <C-a> selects the whole file like cmd+a; plain y (or
-- <leader>y) then copies it — clipboard is already system-wide
-- (clipboard=unnamedplus in settings.lua). Normal-mode <C-a> replaces
-- native number increment; visual <C-a> and g<C-a> stay native for that.
map("n", "<C-a>", "ggVG", { desc = "Select the whole file, then y or SPC y copies it" })
map("n", "<Leader>y", '"+y', { desc = "Copy to the system clipboard (then a motion: yy takes this line)" })
map("v", "<Leader>y", '"+y', { desc = "Copy the selection to the system clipboard" })
