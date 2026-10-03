-- Command glossary, generated from the live keymaps. Space is the leader,
-- written here as SPC.
--
-- The index is never hand-listed: every row comes from runtime
-- introspection (nvim_get_keymap / nvim_buf_get_keymap) at open time, so a
-- mapping defined anywhere in lua/mapping/ — or by a plugin, or ad hoc at
-- runtime — appears with zero registration. Descriptions come from each
-- map's `desc` option; group labels come from the ordered prefix rules
-- below (presentation metadata only: an unmatched key still shows, under
-- "Other").

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

-- Ordered rules: first match wins, so a longer prefix in the same namespace
-- must come earlier (SPC hh before SPC h, SPC ff before SPC f). A key that
-- matches nothing lands in "Other" — still listed. Adjust labels here when a
-- namespace gains a new meaning (e.g. SPC m p / SPC m r in the markdown
-- viewer).
local GROUP_RULES = {
	{ prefix = "SPC hh", title = "Start here" },
	{ prefix = "SPC P", title = "Deep Work Plans" },
	{ prefix = "Ctrl-a", title = "Select and copy" },
	{ prefix = "SPC y", title = "Select and copy" },
	{ prefix = "SPC g", title = "Git" },
	{ prefix = "SPC p", title = "Plugins" },
	{ prefix = "SPC ff", title = "Files and search" },
	{ prefix = "SPC fo", title = "Files and search" },
	{ prefix = "SPC fw", title = "Files and search" },
	{ prefix = "SPC f", title = "Save, quit, and file actions" },
	{ prefix = "SPC th", title = "Appearance" },
	{ prefix = "SPC t", title = "Files and search" },
	{ prefix = "SPC n", title = "Files and search" },
	{ prefix = "SPC s", title = "Files and search" },
	{ prefix = "SPC b", title = "Files and search" },
	{ prefix = "SPC w", title = "Save, quit, and file actions" },
	{ prefix = "SPC q", title = "Save, quit, and file actions" },
	{ prefix = "SPC Q", title = "Save, quit, and file actions" },
	{ prefix = "SPC R", title = "Save, quit, and file actions" },
	{ prefix = "SPC r", title = "Save, quit, and file actions" },
	{ prefix = "SPC x", title = "Save, quit, and file actions" },
	{ prefix = "SPC a", title = "Save, quit, and file actions" },
	{ prefix = "SPC k", title = "Buffers, windows, tabs" },
	{ prefix = "SPC j", title = "Buffers, windows, tabs" },
	{ prefix = "SPC h", title = "Buffers, windows, tabs" },
	{ prefix = "SPC H", title = "Buffers, windows, tabs" },
	{ prefix = "SPC l", title = "Buffers, windows, tabs" },
	{ prefix = "SPC v", title = "Buffers, windows, tabs" },
	{ prefix = "SPC m", title = "Tabs and panels" },
	{ prefix = "SPC <", title = "Buffers, windows, tabs" },
	{ prefix = "SPC >", title = "Buffers, windows, tabs" },
	{ prefix = "Ctrl-t", title = "Buffers, windows, tabs" },
	{ prefix = "J", title = "Move and fold" },
	{ prefix = "K", title = "Move and fold" },
	{ prefix = "Ctrl-j", title = "Move and fold" },
	{ prefix = "Ctrl-k", title = "Move and fold" },
	{ prefix = "f", title = "Move and fold" },
	{ prefix = "U", title = "Move and fold" },
	{ prefix = "u", title = "Move and fold" },
	{ prefix = "gd", title = "Code (language server)" },
	{ prefix = "gD", title = "Code (language server)" },
	{ prefix = "gi", title = "Code (language server)" },
	{ prefix = "gr", title = "Code (language server)" },
}
local OTHER_TITLE = "Other"

-- Turn a raw lhs into the display form used everywhere here:
-- "<leader>x" / " x" (nvim_get_keymap returns a decoded leader byte) /
-- "<Space>x" all become "SPC x"; "<C-t>" becomes "Ctrl-t"; "<M-t>"
-- becomes "Alt-t"; "<lt>" becomes "<". Note the "%-" in the chord
-- patterns: a bare "-" after a class is the lazy-repetition operator,
-- which would wrongly turn "<lt>" into "Ctrl-lt".
local function display_key(lhs)
	local key = lhs:gsub("^ ", "SPC "):gsub("<[Ll]eader>%s?", "SPC "):gsub("<[Ss]pace>%s?", "SPC ")
	key = key:gsub("<([Cc])%-([A-Za-z0-9]+)>", function(_, chord)
		return "Ctrl-" .. chord:lower()
	end)
	key = key:gsub("<([Mm])%-([A-Za-z0-9]+)>", function(_, chord)
		return "Alt-" .. chord:lower()
	end)
	return (key:gsub("<lt>", "<"))
end

-- Plain prefix: display keys spell the leader once and then the whole
-- chord ("SPC gaa"), so there is no separator to anchor a word boundary on.
local function in_group(key, prefix)
	return key:sub(1, #prefix) == prefix
end

local function group_of(key)
	for _, rule in ipairs(GROUP_RULES) do
		if in_group(key, rule.prefix) then
			return rule.title
		end
	end
	return OTHER_TITLE
end

-- Order groups by their first rule's position; "Other" always last.
local function group_order()
	local order, seen = {}, {}
	for _, rule in ipairs(GROUP_RULES) do
		if not seen[rule.title] then
			seen[rule.title] = true
			table.insert(order, rule.title)
		end
	end
	table.insert(order, OTHER_TITLE)
	return order
end

-- A readable fallback when a map carries no desc: show a cleaned rhs.
local function rhs_summary(rhs)
	if type(rhs) ~= "string" or rhs == "" then
		return nil
	end
	local text = rhs:gsub("^<cmd>", ""):gsub("^:", ""):gsub("<[Cc][Rr]>$", ""):gsub("^%s+", "")
	if text == "" or #text > 60 then
		return nil
	end
	return text
end

local function interesting(lhs)
	if lhs == nil or lhs == "" then
		return false
	end
	if lhs:find("<SNR", 1, true) or lhs:find("<Plug>", 1, true) then
		return false
	end
	if lhs:find("Mouse", 1, true) or lhs:find("Scroll", 1, true) then
		return false
	end
	return true
end

-- Introspect the live keymaps. Global maps for normal and visual mode, plus
-- the current buffer's local maps (LSP after attach, the file tree when
-- focused) marked with a bullet.
local ITEMS = {}

local function collect_mode(maps, mode, tag)
	for _, m in ipairs(maps) do
		if interesting(m.lhs) then
			local desc = m.desc and m.desc ~= "" and m.desc or rhs_summary(m.rhs) or "(no description)"
			if tag then
				desc = desc .. "  · this buffer"
			end
			table.insert(ITEMS, {
				mode = mode,
				key = display_key(m.lhs),
				desc = desc,
			})
		end
	end
end

local M = {}

function M.collect()
	ITEMS = {}
	collect_mode(vim.api.nvim_get_keymap("n"), "n", false)
	collect_mode(vim.api.nvim_get_keymap("v"), "v", false)
	collect_mode(vim.api.nvim_buf_get_keymap(0, "n"), "n", true)
	return ITEMS
end

local KEY_WIDTH = 16

local function row_text(item)
	local key = item.key
	if item.mode == "v" then
		key = key .. " (v)"
	end
	return "  " .. pad(key, KEY_WIDTH) .. "  " .. item.desc
end

local function matches(query, item, title)
	if query == "" then
		return true
	end
	local hay = (item.key .. " " .. item.desc .. " " .. title):lower()
	return hay:find(query, 1, true) ~= nil
end

function M.filtered(query)
	query = (query or ""):lower()
	local items = M.collect()
	local by_group = {}
	for _, item in ipairs(items) do
		local title = group_of(item.key)
		by_group[title] = by_group[title] or {}
		table.insert(by_group[title], item)
	end
	local out, hits = {}, 0
	for _, title in ipairs(group_order()) do
		local group_items = by_group[title]
		if group_items then
			table.sort(group_items, function(a, b)
				if a.key == b.key then
					return a.mode < b.mode
				end
				return a.key < b.key
			end)
			local block = {}
			for _, item in ipairs(group_items) do
				if matches(query, item, title) then
					table.insert(block, row_text(item))
					hits = hits + 1
				end
			end
			if #block > 0 then
				table.insert(out, "  " .. title)
				for _, line in ipairs(block) do
					table.insert(out, line)
				end
				table.insert(out, "")
			end
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
		"  Command glossary — generated from the live mappings",
		"  Type to search. Esc clears the search, then closes. Space q closes from anywhere.",
		"  :checkhealth  See what is missing.",
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
