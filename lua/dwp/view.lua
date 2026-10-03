-- Plan browser panel: a two-level float in the house style (see
-- mapping/glossary.lua and scheme/picker.lua). Level 1 lists every plan
-- found under .dwp/plans with its derived state; Enter drills into the
-- plan's files; Enter again opens a file in a buffer. Esc clears the
-- search, then backs out one level, then closes. Type to search at both
-- levels; Ctrl-n/Ctrl-p or the arrows move the selection.

local plans = require("dwp.plans")

local V = {}

local ns = vim.api.nvim_create_namespace("muvim-plans")

local session = nil

local STATE_ORDER = { "draft", "approved", "in-flight", "completed", "unknown" }

local function display_len(text)
	local n = utf8 and utf8.len(text)
	if n then
		return n
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

local function matches(query, haystack)
	if query == "" then
		return true
	end
	return haystack:lower():find(query, 1, true) ~= nil
end

-- Row builders. Every visible row is { text = display, data = payload };
-- the selection marker is drawn at render time so filtering never moves
-- it into a hidden row invisibly.

local function plan_rows(list, query)
	local rows = {}
	for _, plan in ipairs(list) do
		local progress = "—"
		if plan.tasks_total then
			progress = string.format("%d/%d", plan.tasks_done or 0, plan.tasks_total)
		end
		local text = string.format("%s  %s  %s  %s", pad(plan.state, 9), plan.name, pad(progress, 5), plan.mtime)
		if matches(query, text) then
			rows[#rows + 1] = { text = text, kind = "plan", plan = plan }
		end
	end
	return rows
end

local function file_rows(plan, query)
	local rows = {}
	for _, group in ipairs(plans.file_groups(plan.path)) do
		for _, file in ipairs(group.files) do
			local text = string.format("%s  %s", pad(group.title, 8), file)
			if matches(query, plan.name .. " " .. text) then
				rows[#rows + 1] = { text = text, kind = "file", plan = plan, file = plan.path .. "/" .. file }
			end
		end
	end
	return rows
end

local function rows_now()
	if session.level == 1 then
		return plan_rows(session.list, session.query)
	end
	return file_rows(session.plan, session.query)
end

local function search_box(width, placeholder)
	local inner = width - 4
	local text = session.query == "" and placeholder or session.query
	local room = inner - 2
	if display_len(text) > room then
		text = text:sub(1, room - 1) .. "…"
	end
	return "╭" .. string.rep("─", inner) .. "╮",
		"│" .. pad(" " .. text, inner) .. "│",
		"╰" .. string.rep("─", inner) .. "╯"
end

local function header_text(width)
	if session.level == 1 then
		return " Deep Work Plans — Enter opens a plan's files "
	end
	return " " .. session.plan.name .. " — Enter opens the file "
end

local function render()
	if not vim.api.nvim_buf_is_valid(session.buf) then
		return
	end
	local width = session.width
	local top, mid, bot = search_box(width, session.level == 1 and "Search plans" or "Search files")
	local rows = rows_now()
	if #rows == 0 then
		rows = { { text = "No matches.", kind = "empty" } }
	end
	if session.selected > #rows then
		session.selected = #rows
	end
	if session.selected < 1 then
		session.selected = 1
	end

	local lines = { top, mid, bot, header_text(width), "" }
	for index, row in ipairs(rows) do
		local marker = index == session.selected and "❯ " or "  "
		lines[#lines + 1] = marker .. row.text
	end

	vim.bo[session.buf].modifiable = true
	vim.api.nvim_buf_set_lines(session.buf, 0, -1, false, lines)
	vim.bo[session.buf].modifiable = false
	pcall(vim.api.nvim_buf_clear_namespace, session.buf, ns, 0, -1)
	for _, row in ipairs({ 0, 1, 2 }) do
		vim.api.nvim_buf_set_extmark(session.buf, ns, row, 0, {
			end_row = row + 1,
			end_col = 0,
			hl_group = "MuvimSearchBorder",
			hl_eol = true,
		})
	end
	local header_hl = #top > 0 and 3 or 3
	vim.api.nvim_buf_set_extmark(session.buf, ns, header_hl, 0, {
		end_row = header_hl + 1,
		end_col = 0,
		hl_group = "Comment",
		hl_eol = true,
	})
	if rows[session.selected] and rows[session.selected].kind ~= "empty" then
		vim.api.nvim_buf_set_extmark(session.buf, ns, 4 + session.selected, 0, {
			end_row = 5 + session.selected,
			end_col = 0,
			hl_group = "PmenuSel",
			hl_eol = true,
		})
	end

	local text = session.query == "" and (session.level == 1 and "Search plans" or "Search files") or session.query
	local text_col = #"│ "
	vim.api.nvim_buf_set_extmark(session.buf, ns, 1, text_col, {
		end_col = text_col + #text,
		hl_group = session.query == "" and "Comment" or "MuvimSearch",
	})
	if session.win and vim.api.nvim_win_is_valid(session.win) then
		local col = math.min(text_col + #session.query, #mid - 1)
		vim.api.nvim_win_set_cursor(session.win, { 2, col })
	end
end

local function close()
	if session.saved_cursor then
		pcall(function()
			vim.o.guicursor = session.saved_cursor
		end)
	end
	if session.win and vim.api.nvim_win_is_valid(session.win) then
		vim.api.nvim_win_close(session.win, true)
	end
	pcall(vim.api.nvim_del_augroup_by_name, "MuvimPlansClose")
	session = nil
end

local function move_selection(step)
	local rows = rows_now()
	if #rows == 0 then
		return
	end
	session.selected = session.selected + step
	if session.selected > #rows then
		session.selected = 1
	end
	if session.selected < 1 then
		session.selected = #rows
	end
	render()
end

local function activate()
	local rows = rows_now()
	local row = rows[session.selected]
	if not row then
		return
	end
	if row.kind == "plan" then
		session.plan = row.plan
		session.level = 2
		session.query = ""
		session.selected = 1
		render()
	elseif row.kind == "file" then
		local path = row.file
		close()
		vim.cmd("edit " .. vim.fn.fnameescape(path))
	end
end

local function back()
	if session.query ~= "" then
		session.query = ""
		session.selected = 1
		render()
		return
	end
	if session.level == 2 then
		session.level = 1
		session.plan = nil
		session.selected = 1
		render()
		return
	end
	close()
end

--- Open the plan browser. Scans both plan roots at open time, so plans
--- created after the editor started appear on the next open.
function V.open()
	local list = plans.scan()
	session = {
		buf = vim.api.nvim_create_buf(false, true),
		win = nil,
		level = 1,
		query = "",
		selected = 1,
		list = list,
		plan = nil,
		width = math.min(92, vim.o.columns - 4),
	}
	vim.bo[session.buf].buftype = "nofile"
	vim.bo[session.buf].bufhidden = "wipe"
	vim.bo[session.buf].filetype = "muvim-plans"
	render()

	local height = math.max(10, math.min(vim.o.lines - 4, #session.list + 8))
	session.win = vim.api.nvim_open_win(session.buf, true, {
		relative = "editor",
		width = session.width,
		height = height,
		row = 1,
		col = math.max(0, math.floor((vim.o.columns - session.width) / 2)),
		style = "minimal",
		border = "rounded",
		title = " Plans ",
		title_pos = "center",
	})
	vim.wo[session.win].cursorline = false
	vim.wo[session.win].wrap = false
	vim.wo[session.win].scrolloff = 0
	session.saved_cursor = vim.o.guicursor
	vim.o.guicursor = "a:ver25-Cursor/lCursor"
	render()

	vim.api.nvim_create_autocmd({ "WinLeave", "WinScrolled" }, {
		group = vim.api.nvim_create_augroup("MuvimPlansClose", { clear = true }),
		callback = function()
			if not session or not session.win or not vim.api.nvim_win_is_valid(session.win) then
				return true
			end
			if vim.api.nvim_get_current_win() ~= session.win then
				close()
				return true
			end
		end,
	})

	local opts = { buffer = session.buf, silent = true, nowait = true }
	vim.keymap.set("n", "<Esc>", back, opts)
	vim.keymap.set("n", "<C-c>", close, opts)
	vim.keymap.set("n", "<CR>", activate, opts)
	vim.keymap.set("n", "<C-n>", function()
		move_selection(1)
	end, opts)
	vim.keymap.set("n", "<Down>", function()
		move_selection(1)
	end, opts)
	vim.keymap.set("n", "<C-p>", function()
		move_selection(-1)
	end, opts)
	vim.keymap.set("n", "<Up>", function()
		move_selection(-1)
	end, opts)
	vim.keymap.set("n", "<BS>", function()
		if session.query ~= "" then
			session.query = session.query:sub(1, #session.query - 1)
			render()
		end
	end, opts)
	vim.keymap.set("n", "<C-u>", function()
		session.query = ""
		render()
	end, opts)
	-- Leader is Space: swallow it so leader chords do not reach the query.
	vim.keymap.set("n", "<Space>", "<Nop>", opts)
	for i = 33, 126 do
		local char = string.char(i)
		vim.keymap.set("n", char, function()
			session.query = session.query .. char
			session.selected = 1
			render()
		end, opts)
	end
end

return V
