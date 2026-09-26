-- Space q: close the thing in front of you, then the window, then nvim.
-- Used from normal mode and from the terminal split.

local M = {}

local function close_muvim_float()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local cfg = vim.api.nvim_win_get_config(win)
			if cfg.relative ~= nil and cfg.relative ~= "" then
				local buf = vim.api.nvim_win_get_buf(win)
				local ft = vim.bo[buf].filetype
				if ft == "muvim-glossary" or ft == "muvim-theme" then
					vim.api.nvim_win_close(win, true)
					return true
				end
			end
		end
	end
	return false
end

function M.close()
	-- A click outside leaves focus in another window, but the leader map
	-- that fires Space q belongs to that window. Close the panel first,
	-- from wherever the cursor is.
	if close_muvim_float() then
		return
	end

	local diff_ok, lib = pcall(require, "diffview.lib")
	if diff_ok and lib.get_current_view() then
		vim.cmd("DiffviewClose")
		return
	end

	local listed = 0
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[buf].buflisted and vim.api.nvim_buf_is_loaded(buf) then
			listed = listed + 1
		end
	end
	if #vim.api.nvim_tabpage_list_wins(0) <= 1 and listed <= 1 then
		vim.cmd("qa!")
		return
	end
	vim.cmd("q!")
end

return M
