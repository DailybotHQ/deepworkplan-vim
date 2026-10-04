-- Plans sidebar: the single plan surface (DESIGN_SPEC § Wireframes).
-- A persistent left split like the file tree, filtered to plans — one
-- row per plan (status icon · friendly title · progress bar · counts),
-- grouped most-attention-first (Working → Needs attention → Ready →
-- Not started → Done → Unknown), expandable to the task checklist and
-- the plan's files. Keyboard and mouse both work; `?` explains the keys
-- in plain language. Read-only toward `.dwp/` — every action opens a
-- buffer, nothing under the plan folder is ever written.
--
-- Lazy by contract: the module is required only inside mapping and
-- command callbacks (mapping/navigation.lua), never at boot.

local plans = require("dwp.plans")

local S = {}

local MAX_WIDTH = 48 -- full row = cap + ~19 cells; 46 clipped the counts at
-- the default width (render harness, UX_AUDIT F-03)
local MIN_WIDTH = 34
local TITLE_CAP = 28 -- frozen in DESIGN_SPEC § Information architecture (the cap at full width)
local BAR_CELLS = 8
local NS = vim.api.nvim_create_namespace("dwp-sidebar")

-- Most-attention-first section order (DESIGN_SPEC § Information
-- architecture). Sections key on the plain-language label.
local SECTION_ORDER = { "Working", "Needs attention", "Ready", "Not started", "Done", "Unknown" }

local st = {
	win = nil,
	buf = nil,
	rows = {},
	expanded = {}, -- plan name -> bool (survives close/reopen)
	collapsed_sections = {}, -- label -> bool
	roots = nil, -- test override; nil means default roots
	help_win = nil,
	help_buf = nil,
}

local refresh_timer = nil

-- ---------------------------------------------------------------- util --

local function display_width(text)
	return vim.fn.strdisplaywidth(text)
end

-- Cut by display cells, not characters: CJK counts two cells per
-- character, and a character-count cut let a 60-cell title overflow the
-- window (render harness, UX_AUDIT F-12).
local function truncate(text, cap)
	if display_width(text) <= cap then
		return text
	end
	local out, used = "", 0
	for _, ch in ipairs(vim.split(text, "")) do
		local cw = display_width(ch)
		if used + cw > cap - 1 then
			break
		end
		out = out .. ch
		used = used + cw
	end
	return out .. "…"
end

-- Sidebar width: the full 48 columns on comfortable terminals, and a
-- proportional share (never below the readable floor) once the terminal
-- is too narrow to spare it — at the old fixed width a 60-column
-- terminal gave the sidebar 77% of the screen (UX_AUDIT F-03).
local function layout_width()
	local cols = vim.o.columns
	local w = MAX_WIDTH
	if cols < MAX_WIDTH * 2 - 14 then
		w = math.max(MIN_WIDTH, math.floor(cols * 0.55))
	end
	return math.min(w, math.max(20, cols - 2))
end

-- Title cap follows the actual window so a plan row always fits on one
-- screen line: counts may never clip (F-03), so the cap gives up cells
-- before anything else does. Cap rule recorded in UX_AUDIT F-03/F-07.
local function title_cap(win_width)
	return math.min(TITLE_CAP, math.max(10, win_width - 20))
end

local function progress_bar(done, total)
	local filled = 0
	if total and total > 0 then
		filled = math.floor((done / total) * BAR_CELLS + 0.5)
	end
	if filled > BAR_CELLS then
		filled = BAR_CELLS
	end
	return string.rep("▰", filled) .. string.rep("▱", BAR_CELLS - filled)
end

-- -------------------------------------------------------------- render --

local function task_rows(record)
	-- Checklist source of truth: the state.json projection (id, title,
	-- status) when the plan has one; the README's checkboxes otherwise
	-- (no current-task marker is derivable there). Recorded choice for
	-- the task log: state-first, README fallback, no dead branch.
	local rows = {}
	local handle = io.open(record.path .. "/state.json", "r")
	if handle then
		local content = handle:read("*a")
		handle:close()
		local ok, snapshot = pcall(vim.json.decode, content)
		if ok and type(snapshot) == "table" and type(snapshot.tasks) == "table" then
			for _, task in ipairs(snapshot.tasks) do
				if type(task) == "table" and task.id then
					local mark, hl = "○", nil
					if task.status == "completed" then
						mark, hl = "✓", "Comment"
					elseif task.id == record.current_task then
						mark, hl = "▸", "MoreMsg"
					end
					rows[#rows + 1] = {
						text = "  " .. mark .. " " .. (task.title or task.id),
						hl = hl,
						kind = "task",
						title = task.title or task.id,
						plan = record,
					}
				end
			end
			if #rows > 0 then
				return rows
			end
		end
	end
	local readme = io.open(record.path .. "/README.md", "r")
	if not readme then
		return rows
	end
	for line in readme:lines() do
		local checked, title = line:match("^%s*%- %[([ x])%]%s+(.+)")
		if title then
			rows[#rows + 1] = {
				text = "  " .. (checked == "x" and "✓" or "○") .. " " .. title,
				hl = checked == "x" and "Comment" or nil,
				kind = "task",
				title = title,
				plan = record,
			}
		end
	end
	readme:close()
	return rows
end

local function file_rows(record)
	local rows = {
		{ text = "  Files", hl = "Comment", kind = "label" },
	}
	for _, group in ipairs(plans.file_groups(record.path)) do
		for _, file in ipairs(group.files) do
			rows[#rows + 1] = {
				text = string.format("    %-8s %s", group.title, file),
				hl = nil,
				kind = "file",
				file = record.path .. "/" .. file,
			}
		end
	end
	return rows
end

local function plan_row(record, cap)
	local title = truncate(record.title or record.name, cap)
	local counts = string.format("%d/%d", record.tasks_done or 0, record.tasks_total or 0)
	local marker = st.expanded[record.name] and "▾" or "▸"
	return {
		text = string.format(
			"%s %s  %s %s",
			record.icon or "·",
			title .. string.rep(" ", math.max(1, cap - display_width(title) + 2)),
			marker .. progress_bar(record.tasks_done or 0, record.tasks_total or 0),
			counts
		),
		hl = record.highlight or "Comment",
		kind = "plan",
		plan = record,
	}
end

local function build_rows(records, cap)
	local by_section = {}
	for _, record in ipairs(records) do
		local label = record.label or "Unknown"
		by_section[label] = by_section[label] or {}
		by_section[label][#by_section[label] + 1] = record
	end

	local rows = {
		{ text = "Plans", hl = "Title", kind = "header" },
		{ text = "", kind = "blank" },
	}
	local any = false
	for _, label in ipairs(SECTION_ORDER) do
		local group = by_section[label]
		if group then
			any = true
			-- Collapsed sections keep their header (with a count marker):
			-- the header row is the only way back, so removing it made
			-- collapse a one-way trap (final-review finding 1).
			local collapsed = st.collapsed_sections[label]
			rows[#rows + 1] = {
				text = collapsed and string.format("%s ▸ %d hidden", label, #group) or label,
				hl = "Comment",
				kind = "section",
				label = label,
			}
			if not collapsed then
				for _, record in ipairs(group) do
					rows[#rows + 1] = plan_row(record, cap)
					if st.expanded[record.name] then
						local sub = task_rows(record)
						for _, row in ipairs(sub) do
							rows[#rows + 1] = row
						end
						for _, row in ipairs(file_rows(record)) do
							rows[#rows + 1] = row
						end
					end
				end
			end
		end
	end
	if not any then
		rows[#rows + 1] = { text = "No plans yet — ask your agent to plan work.", hl = "Comment", kind = "blank" }
	end
	rows[#rows + 1] = { text = "", kind = "blank" }
	rows[#rows + 1] = { text = "? help · r refresh · Enter open · Tab expand", hl = "Comment", kind = "footer" }
	rows[#rows + 1] = { text = "click a plan to expand · double-click opens it", hl = "Comment", kind = "footer" }
	return rows
end

local function render()
	if not st.buf or not vim.api.nvim_buf_is_valid(st.buf) then
		return
	end
	local lines = {}
	for _, row in ipairs(st.rows) do
		lines[#lines + 1] = row.text
	end
	vim.bo[st.buf].modifiable = true
	vim.api.nvim_buf_set_lines(st.buf, 0, -1, false, lines)
	vim.bo[st.buf].modifiable = false
	pcall(vim.api.nvim_buf_clear_namespace, st.buf, NS, 0, -1)
	for i, row in ipairs(st.rows) do
		if row.hl then
			vim.api.nvim_buf_set_extmark(st.buf, NS, i - 1, 0, {
				end_row = i,
				end_col = 0,
				hl_group = row.hl,
				hl_eol = true,
			})
		end
	end
	if st.win and vim.api.nvim_win_is_valid(st.win) then
		local line = vim.api.nvim_win_get_cursor(st.win)[1]
		if line > #st.rows then
			vim.api.nvim_win_set_cursor(st.win, { math.max(1, #st.rows), 0 })
		end
	end
end

-- -------------------------------------------------------------- public --

function S.is_open()
	return st.win ~= nil and vim.api.nvim_win_is_valid(st.win)
end

--- Rescan the roots and redraw. Safe to call when closed (no-op).
--- Rows re-fit the current window width, so a resize followed by a
--- refresh never leaves stale-width (clipped or over-padded) rows.
function S.refresh()
	if not S.is_open() then
		return
	end
	local records = plans.scan(st.roots)
	st.rows = build_rows(records, title_cap(vim.api.nvim_win_get_width(st.win)))
	render()
end

function S.close()
	if st.win and vim.api.nvim_win_is_valid(st.win) then
		if #vim.api.nvim_list_wins() == 1 then
			-- Closing would take the editor down with it (E444): swap in a
			-- scratch buffer instead and keep the window.
			local scratch = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_win_set_buf(st.win, scratch)
		else
			vim.api.nvim_win_close(st.win, true)
		end
	end
	if st.buf and vim.api.nvim_buf_is_valid(st.buf) then
		pcall(vim.api.nvim_buf_delete, st.buf, { force = true })
	end
	pcall(vim.api.nvim_del_augroup_by_name, "DwpSidebar")
	if refresh_timer then
		refresh_timer:stop()
		refresh_timer = nil
	end
	S.close_help()
	st.win, st.buf, st.rows = nil, nil, {}
end

--- Toggle one plan's expanded state (task checklist + files) and redraw.
function S.toggle_expand(plan_name)
	st.expanded[plan_name] = not st.expanded[plan_name]
	S.refresh()
end

--- Open the sidebar. `roots` is a test hook: nil scans the default
--- plan roots (working dir + config dir).
local set_keys -- forward-declared: defined with the actions below
function S.open(roots)
	st.roots = roots
	if S.is_open() then
		vim.api.nvim_set_current_win(st.win)
		S.refresh()
		return
	end
	st.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[st.buf].buftype = "nofile"
	vim.bo[st.buf].bufhidden = "hide"
	vim.bo[st.buf].buflisted = false
	vim.bo[st.buf].filetype = "dwp-plans"
	vim.bo[st.buf].swapfile = false

	vim.cmd("topleft vertical " .. layout_width() .. "split")
	st.win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(st.win, st.buf)
	vim.wo[st.win].wrap = false
	vim.wo[st.win].cursorline = true
	vim.wo[st.win].number = false
	vim.wo[st.win].relativenumber = false
	vim.wo[st.win].signcolumn = "no"
	vim.wo[st.win].fillchars = "eob: "

	local records = plans.scan(st.roots)
	st.rows = build_rows(records, title_cap(vim.api.nvim_win_get_width(st.win)))
	render()
	set_keys()

	-- Plans appear as agent sessions work: refresh on focus, debounced
	-- cancel-and-rearm (the pending timer is stopped, not just dropped —
	-- the statusline module's pattern) so a burst of events costs one scan.
	-- A terminal resize re-fits the rows the same way (F-03: the cap
	-- follows the actual window, so stale-width rows are a defect).
	vim.api.nvim_create_autocmd({ "FocusGained", "VimResized" }, {
		group = vim.api.nvim_create_augroup("DwpSidebar", { clear = true }),
		callback = function()
			if not S.is_open() then
				return true
			end
			if refresh_timer then
				refresh_timer:stop()
			end
			refresh_timer = vim.defer_fn(function()
				refresh_timer = nil
				S.refresh()
			end, 400)
		end,
	})
end

function S.toggle()
	if S.is_open() then
		S.close()
	else
		-- Reopen with the roots in force before the close (the test hook
		-- survives a toggle instead of silently falling back to defaults).
		S.open(st.roots)
	end
end

-- ------------------------------------------------------------- actions --

local function current_row()
	if not st.win or not vim.api.nvim_win_is_valid(st.win) then
		return nil
	end
	local line = vim.api.nvim_win_get_cursor(st.win)[1]
	return st.rows[line], line
end

local function open_plan_reader(record)
	-- The comprehension surface (Task 4): Enter on a plan explains it in
	-- plain language instead of dropping the reader into raw markdown.
	require("dwp.reader").open(record)
end

local function activate()
	local row = current_row()
	if not row then
		return
	end
	if row.kind == "plan" then
		open_plan_reader(row.plan)
	elseif row.kind == "task" then
		vim.cmd("edit " .. vim.fn.fnameescape(row.plan.path .. "/README.md"))
		pcall(vim.fn.search, "\\V" .. vim.fn.escape(row.title or "", "\\"), "w")
	elseif row.kind == "file" then
		vim.cmd("edit " .. vim.fn.fnameescape(row.file))
	elseif row.kind == "section" then
		st.collapsed_sections[row.label] = not st.collapsed_sections[row.label]
		S.refresh()
	end
end

local function on_click()
	-- The click has already moved the cursor to this line.
	local row = current_row()
	if row and row.kind == "plan" then
		S.toggle_expand(row.plan.name)
	end
end

local function on_double_click()
	local row = current_row()
	if row and row.kind == "plan" then
		open_plan_reader(row.plan)
	end
end

local HELP_LINES = {
	"Plans sidebar — keys",
	"",
	"Enter    open the plan under the cursor",
	"         (on a section name: show or hide that group)",
	"Tab      show or hide a plan's tasks and files",
	"j / k    move up and down (or the arrow keys)",
	"r        refresh the list",
	"?        close this help",
	"q / Esc  close the sidebar",
	"",
	"Mouse: click a plan to expand it,",
	"double-click to open it.",
	"",
	"The sidebar never changes your plans —",
	"it only reads and explains them.",
}

function S.close_help()
	if st.help_win and vim.api.nvim_win_is_valid(st.help_win) then
		vim.api.nvim_win_close(st.help_win, true)
	end
	if st.help_buf and vim.api.nvim_buf_is_valid(st.help_buf) then
		pcall(vim.api.nvim_buf_delete, st.help_buf, { force = true })
	end
	st.help_win, st.help_buf = nil, nil
end

function S.help()
	if st.help_win and vim.api.nvim_win_is_valid(st.help_win) then
		S.close_help()
		return
	end
	st.help_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[st.help_buf].buftype = "nofile"
	vim.bo[st.help_buf].bufhidden = "wipe"
	vim.bo[st.help_buf].buflisted = false
	vim.api.nvim_buf_set_lines(st.help_buf, 0, -1, false, HELP_LINES)
	local width = 0
	for _, line in ipairs(HELP_LINES) do
		width = math.max(width, display_width(line))
	end
	st.help_win = vim.api.nvim_open_win(st.help_buf, true, {
		relative = "editor",
		width = math.min(width + 2, vim.o.columns - 4),
		height = #HELP_LINES,
		row = math.max(1, math.floor((vim.o.lines - #HELP_LINES) / 3)),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		style = "minimal",
		border = "rounded",
		title = " Plans ",
		title_pos = "center",
	})
	local opts = { buffer = st.help_buf, silent = true, nowait = true }
	for _, key in ipairs({ "?", "q", "<Esc>", "<CR>" }) do
		vim.keymap.set("n", key, S.close_help, opts)
	end
end

function set_keys()
	local opts = { buffer = st.buf, silent = true, nowait = true }
	vim.keymap.set("n", "<CR>", activate, opts)
	vim.keymap.set("n", "<Tab>", function()
		local row = current_row()
		if row and row.kind == "plan" then
			S.toggle_expand(row.plan.name)
		end
	end, opts)
	vim.keymap.set("n", "r", S.refresh, opts)
	vim.keymap.set("n", "?", S.help, opts)
	vim.keymap.set("n", "q", S.close, opts)
	vim.keymap.set("n", "<Esc>", S.close, opts)
	vim.keymap.set("n", "<LeftMouse>", on_click, opts)
	vim.keymap.set("n", "<2-LeftMouse>", on_double_click, opts)
end

return S
