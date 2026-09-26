-- Full command glossary. Space is the leader, written here as SPC.
-- Keep this list next to lua/mapping/*.lua. A mapping that is not here
-- will not show up on the start screen.

local function display_len(text)
	if utf8 and utf8.len then
		local n = utf8.len(text)
		if n then
			return n
		end
	end
	return #text
end

local function pad(text, width)
	local gap = width - display_len(text)
	if gap < 1 then
		return text
	end
	return text .. string.rep(" ", gap)
end

local groups = {
	{
		title = "Start here",
		rows = {
			{ "SPC h h", "Open this glossary" },
			{ "SPC t", "Open Telescope (every finder)" },
			{ "SPC t h", "Pick a color theme" },
			{ ":checkhealth", "See what is missing" },
		},
	},
	{
		title = "Files and search",
		rows = {
			{ "SPC f f", "Find a file by name" },
			{ "SPC f o", "Recent files" },
			{ "SPC f w", "Search text in the project" },
			{ "SPC b m", "Bookmarks (marks)" },
			{ "SPC t f", "Find files" },
			{ "SPC t t", "Live search in the project" },
			{ "SPC t s", "Search the word under the cursor" },
			{ "SPC n", "File tree" },
			{ "SPC s s", "Jump to two characters on screen" },
		},
	},
	{
		title = "File tree (cursor in the tree)",
		rows = {
			{ "a", "Create a file or folder. End the name with / for a folder" },
			{ "e", "Rename, including the extension" },
			{ "d", "Delete" },
			{ "c", "Copy" },
			{ "x", "Cut" },
			{ "p", "Paste" },
			{ "g?", "Show every tree shortcut" },
		},
	},
	{
		title = "Save, quit, edit",
		rows = {
			{ "SPC w", "Save the file" },
			{ "SPC q", "Close panel, diff, window, or quit nvim" },
			{ "SPC Q", "Quit nvim" },
			{ "SPC f", "Format the file" },
			{ "SPC a w", "Toggle autosave" },
			{ "SPC R", "Replace in the whole file" },
			{ "u", "Undo" },
			{ "U", "Redo" },
			{ "SPC r", "Insert a color" },
			{ "SPC x", "Run or preview the current file" },
		},
	},
	{
		title = "Buffers and windows",
		rows = {
			{ "SPC k", "Next buffer" },
			{ "SPC j", "Previous buffer" },
			{ "SPC h", "Close this buffer" },
			{ "SPC H", "Close every other buffer" },
			{ "SPC l", "List open buffers" },
			{ "SPC m k", "Move this tab right" },
			{ "SPC m j", "Move this tab left" },
			{ "SPC v j", "Split horizontally" },
			{ "SPC v k", "Split vertically" },
			{ "SPC v v", "Close the other splits" },
			{ "SPC <", "Make this window taller" },
			{ "SPC >", "Make this window shorter" },
			{ "Ctrl-t", "Open a terminal on the left" },
		},
	},
	{
		title = "Move and fold",
		rows = {
			{ "J", "Page down" },
			{ "K", "Page up" },
			{ "Ctrl-j", "Scroll down" },
			{ "Ctrl-k", "Scroll up" },
			{ "f", "Fold or unfold this block" },
			{ "f d", "Delete this fold" },
		},
	},
	{
		title = "Code (when a language server is attached)",
		rows = {
			{ "g d", "Go to definition" },
			{ "g D", "Go to declaration" },
			{ "g i", "Go to implementation" },
			{ "g r", "Find references" },
			{ "K", "Hover docs, when the server provides them" },
		},
	},
	{
		title = "Git",
		rows = {
			{ "SPC g s t", "Status" },
			{ "SPC g a a", "Stage everything" },
			{ "SPC g a p", "Stage this file in hunks" },
			{ "SPC g c", "Commit" },
			{ "SPC g p s", "Push" },
			{ "SPC g p l", "Pull" },
			{ "SPC g p p", "Push the current branch" },
			{ "SPC g p x", "Push and set upstream" },
			{ "SPC g l l", "Pull the current branch" },
			{ "SPC g d", "Open or close the diff view" },
			{ "d", "In the diff file list: discard that file (asks first)" },
			{ "X", "In the diff file list: discard that file, no prompt" },
			{ "SPC g b l", "Blame" },
			{ "SPC g s h", "Show the last commit" },
			{ "SPC g s w", "Switch branch (type the name)" },
			{ "SPC g c o", "Checkout (type the name)" },
			{ "SPC g c b", "Create a branch (type the name)" },
			{ "SPC g r v", "Show remotes" },
			{ "SPC g i i", "Init a repository" },
			{ "SPC g g g", "Type any git command" },
		},
	},
	{
		title = "Plugins",
		rows = {
			{ "SPC p i", "Install plugins" },
			{ "SPC p u", "Sync plugins" },
			{ "SPC p c", "Remove unused plugins" },
		},
	},
}

local M = {}

local KEY_WIDTH = 14

local function row_text(row)
	return "  " .. pad(row[1], KEY_WIDTH) .. "  " .. row[2]
end

local function matches(query, row, title)
	if query == "" then
		return true
	end
	local hay = (row[1] .. " " .. row[2] .. " " .. title):lower()
	return hay:find(query, 1, true) ~= nil
end

function M.filtered(query)
	query = (query or ""):lower()
	local out = {}
	local hits = 0
	for _, group in ipairs(groups) do
		local block = {}
		for _, row in ipairs(group.rows) do
			if matches(query, row, group.title) then
				table.insert(block, row_text(row))
				hits = hits + 1
			end
		end
		if #block > 0 then
			table.insert(out, "  " .. group.title)
			for _, line in ipairs(block) do
				table.insert(out, line)
			end
			table.insert(out, "")
		end
	end
	if hits == 0 then
		table.insert(out, "  No commands match.")
		table.insert(out, "")
	end
	return out, hits
end

function M.lines()
	local body = M.filtered("")
	local out = {
		"  Command glossary",
		"  Type to search. Esc clears the search, then closes. Space q closes from anywhere.",
		"",
	}
	for _, line in ipairs(body) do
		table.insert(out, line)
	end
	return out
end

local ns = vim.api.nvim_create_namespace("muvim-glossary")

function M.open()
	local buf = vim.api.nvim_create_buf(false, true)
	local query = ""
	local win
	local width = math.min(86, vim.o.columns - 4)

	local function search_box()
		-- Inset by one cell. A box as wide as the window clips the right
		-- corner, because ╮ is a double-width glyph drawn on the last column.
		local inner = width - 4
		local text = query == "" and "Search commands" or query
		local room = inner - 2
		if display_len(text) > room then
			text = text:sub(1, room - 1) .. "…"
		end
		return "╭" .. string.rep("─", inner) .. "╮",
			"│" .. pad(" " .. text, inner) .. "│",
			"╰" .. string.rep("─", inner) .. "╯"
	end

	local function render()
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local top, mid, bot = search_box()
		local body = M.filtered(query)
		local lines = { top, mid, bot, "" }
		for _, line in ipairs(body) do
			table.insert(lines, line)
		end
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false
		pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
		for _, row in ipairs({ 0, 1, 2 }) do
			vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
				end_row = row + 1,
				end_col = 0,
				hl_group = "MuvimSearchBorder",
				hl_eol = true,
			})
		end
		-- "│" is 3 bytes. Cursor and extmark columns are bytes, not characters,
		-- so a character count lands on the border, left of the box.
		local text_col = #"│ "
		local text = query == "" and "Search commands" or query
		vim.api.nvim_buf_set_extmark(buf, ns, 1, text_col, {
			end_col = text_col + #text,
			hl_group = query == "" and "Comment" or "MuvimSearch",
		})
		if win and vim.api.nvim_win_is_valid(win) then
			local col = math.min(text_col + #query, #mid - 1)
			vim.api.nvim_win_set_cursor(win, { 2, col })
		end
	end

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "muvim-glossary"
	render()

	local height = math.max(8, vim.o.lines - 4)
	win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = 1,
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		style = "minimal",
		border = "rounded",
		title = " Commands ",
		title_pos = "center",
	})
	vim.wo[win].cursorline = false
	vim.wo[win].wrap = false
	vim.wo[win].scrolloff = 0
	-- Thin caret, so it does not paint the glyph under it. guicursor is
	-- global — a window-local set errors and aborts before the keymaps exist.
	local saved_cursor = vim.o.guicursor
	vim.o.guicursor = "a:ver25-Cursor/lCursor"

	local function close()
		vim.o.guicursor = saved_cursor
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	render()

	-- Click anywhere that is not this panel: close it.
	vim.api.nvim_create_autocmd({ "WinLeave", "WinScrolled" }, {
		group = vim.api.nvim_create_augroup("MuvimGlossaryClose", { clear = true }),
		callback = function()
			if not win or not vim.api.nvim_win_is_valid(win) then
				return true
			end
			if vim.api.nvim_get_current_win() ~= win then
				close()
				return true
			end
		end,
	})

	local function type_char(char)
		query = query .. char
		render()
	end

	local function backspace()
		if query == "" then
			return
		end
		query = query:sub(1, #query - 1)
		render()
	end

	local opts = { buffer = buf, silent = true, nowait = true }
	vim.keymap.set("n", "<Esc>", function()
		if query ~= "" then
			query = ""
			render()
			return
		end
		close()
	end, opts)
	vim.keymap.set("n", "<C-c>", close, opts)
	vim.keymap.set("n", "<BS>", backspace, opts)
	vim.keymap.set("n", "<C-u>", function()
		query = ""
		render()
	end, opts)
	-- Leader is Space. Swallow it so Space q (and any other leader chord)
	-- does not append a space to the query while this panel is focused.
	-- q itself is searchable; Space q still closes, even after a click outside.
	vim.keymap.set("n", "<Space>", "<Nop>", opts)
	for i = 33, 126 do
		local char = string.char(i)
		vim.keymap.set("n", char, function()
			type_char(char)
		end, opts)
	end
end

return M
