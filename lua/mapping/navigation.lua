local map = vim.keymap.set

-- easymotion
map("n", "<Leader>ss", "<Plug>(easymotion-s2)", { desc = "Jump to two characters on screen" })

-- bufferline
map("n", "<Leader>mk", ":BufferLineMoveNext<CR>", { desc = "Move this tab right" })
map("n", "<Leader>mj", ":BufferLineMovePrev<CR>", { desc = "Move this tab left" })

-- NvimTree
map("n", "<leader>n", ":NvimTreeToggle<CR>", { desc = "File tree" })

-- DWP plan browser (lazy: the module loads on first use, never at boot)
map("n", "<Leader>P", function()
	require("dwp.view").open()
end, { desc = "Browse Deep Work Plans" })
-- Terminal-independent entry point: :DwpPlans always works, even where a
-- leader chord misfires (exotic terminals, dashboard buffers).
vim.api.nvim_create_user_command("DwpPlans", function()
	require("dwp.view").open()
end, { desc = "Browse Deep Work Plans" })

-- Telescope
map("n", "<Leader>t", ":Telescope<CR>", { desc = "Open Telescope (every finder)" })
map("n", "<Leader>tf", ":Telescope fd<CR>", { desc = "Find files" })
map("n", "<Leader>tt", ":Telescope live_grep<CR>", { desc = "Live search in the project" })
map("n", "<Leader>ts", ":Telescope grep_string<CR>", { desc = "Search the word under the cursor" })
-- Same finders the start screen buttons run.
map("n", "<Leader>ff", ":Telescope find_files<CR>", { desc = "Find a file by name" })
map("n", "<Leader>fo", ":Telescope oldfiles<CR>", { desc = "Recent files" })
map("n", "<Leader>fw", ":Telescope live_grep<CR>", { desc = "Search text in the project" })
map("n", "<Leader>bm", ":Telescope marks<CR>", { desc = "Bookmarks (marks)" })
