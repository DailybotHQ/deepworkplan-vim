-- Markdown viewing, first-class. One implementation, three entries:
-- SPC m p (browser preview), SPC m r (in-buffer render), and the markdown
-- branch of SPC x (run/preview dispatch) all land here, so the gesture
-- behaves the same no matter how it is invoked.

local map = vim.keymap.set

local M = {}

local function only_markdown(what)
	if vim.bo.filetype ~= "markdown" then
		vim.notify(what .. " only works in a markdown buffer", vim.log.levels.INFO)
		return false
	end
	return true
end

function M.preview()
	if not only_markdown("The markdown preview") then
		return
	end
	local ok = pcall(vim.cmd, [[MarkdownPreviewToggle]])
	if not ok then
		vim.notify("markdown-preview is not available yet — run SPC p i, then restart", vim.log.levels.WARN)
	end
end

function M.render()
	if not only_markdown("The in-buffer render") then
		return
	end
	local ok = pcall(vim.cmd, [[RenderMarkdown toggle]])
	if not ok then
		vim.notify("render-markdown is not available yet — run SPC p i, then restart", vim.log.levels.WARN)
	end
end

map("n", "<Leader>mp", function()
	M.preview()
end, { desc = "Open or close the markdown preview in the browser" })
map("n", "<Leader>mr", function()
	M.render()
end, { desc = "Render or unrender the markdown in this buffer" })

return M
