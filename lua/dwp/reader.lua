-- Plan reader: the comprehension surface (DESIGN_SPEC § Wireframes 2).
-- Enter on a plan (sidebar) opens a rendered, read-only view — title,
-- goal in one sentence, status badge, progress, task checklist with the
-- current task marked, a plain-language jump list into the plan's own
-- files, and the resume one-liner. Defensive by the same contract as
-- dwp.state: any unreadable artifact degrades to what is known, a
-- corrupt plan renders as Unknown with the files that exist — never an
-- error. Read-only toward `.dwp/`: it opens buffers, writes nothing.

local plans = require("dwp.plans")

local R = {}

local NS = vim.api.nvim_create_namespace("dwp-reader")
local BAR_CELLS = 10
local JUMP_CAP = 14 -- keep the jump list one screen; extras summarized

local st = {
	buf = nil,
	rows = {}, -- row index -> { text, hl, kind, file? }
}

-- What each well-known file is, in P1 words. Anything unknown gets its
-- group's description; task files get their own heading.
local FILE_PURPOSE = {
	["README.md"] = "the plan itself",
	["PROGRESS.md"] = "where it is right now",
	["PROMPTS.md"] = "ready-to-use prompts for this plan",
	["ORCHESTRATOR_MANIFEST.md"] = "how agents share this plan",
	["manifest.json"] = "the plan's identity record",
	["contract.json"] = "what was agreed (the contract)",
	["journal.ndjson"] = "the history, in order",
	["state.json"] = "the ledger's current view",
}
local GROUP_PURPOSE = {
	Plan = "the plan documents",
	Tasks = "one file per task",
	Records = "the ledger records",
	Evidence = "the evidence files",
}

local function truncate(text, cap)
	if vim.fn.strdisplaywidth(text) <= cap then
		return text
	end
	return vim.fn.strcharpart(text, 0, math.max(1, cap - 1)) .. "…"
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

-- Goal in one sentence: the first paragraph under the README's Goal
-- heading (any level-2 heading mentioning "goal"), else the contract's
-- outcome statement, else an honest "not stated" line.
local function goal_sentence(record)
	local handle = io.open(record.path .. "/README.md", "r")
	if handle then
		local in_goal, lines = false, {}
		for line in handle:lines() do
			local heading = line:match("^##%s+(.-)%s*$")
			if heading then
				if in_goal then
					break
				end
				in_goal = heading:lower():find("goal", 1, true) ~= nil
			elseif in_goal and line:match("%S") then
				lines[#lines + 1] = line
			elseif in_goal and #lines > 0 then
				break -- paragraph ended
			end
		end
		handle:close()
		if #lines > 0 then
			return table.concat(lines, " ")
		end
	end
	local ok, decoded = pcall(vim.json.decode, function()
		local h = io.open(record.path .. "/contract.json", "r")
		if not h then
			return ""
		end
		local c = h:read("*a")
		h:close()
		return c
	end)
	if ok and type(decoded) == "table" and type(decoded.outcome) == "table" then
		local statement = decoded.outcome.statement
		if type(statement) == "string" and statement ~= "" then
			return truncate(statement, 400)
		end
	end
	return "No goal recorded in this plan."
end

-- Task checklist rows: state.json first (titles + status + current
-- marker), README checkboxes as the fallback — same choice the sidebar
-- recorded in Task 3; kept in one place per surface, not shared state.
local function task_rows(record)
	local rows = {}
	local handle = io.open(record.path .. "/state.json", "r")
	if handle then
		local content = handle:read("*a")
		handle:close()
		local ok, snapshot = pcall(vim.json.decode, content)
		if ok and type(snapshot) == "table" and type(snapshot.tasks) == "table" then
			for _, task in ipairs(snapshot.tasks) do
				if type(task) == "table" and task.id then
					local text = "  " .. (task.title or task.id)
					if task.status == "completed" then
						rows[#rows + 1] = { text = "✓ " .. text:sub(3), hl = "Comment" }
					elseif task.id == record.current_task then
						rows[#rows + 1] = { text = "▸ " .. text:sub(3) .. "  ← working on this now", hl = "MoreMsg" }
					else
						rows[#rows + 1] = { text = "○ " .. text:sub(3) }
					end
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
				text = (checked == "x" and "✓ " or "○ ") .. title,
				hl = checked == "x" and "Comment" or nil,
			}
		end
	end
	readme:close()
	return rows
end

local function heading_of(path)
	local handle = io.open(path, "r")
	if not handle then
		return nil
	end
	local first = handle:read("*l")
	handle:close()
	return first and first:match("^#%s+(.-)%s*$")
end

-- The jump list, in plain language: every file the plan offers with a
-- one-line description of what it is. Bounded by JUMP_CAP; the tail
-- becomes an honest summary line instead of a wall of filenames.
local function jump_rows(record)
	local rows = {}
	local overflow = 0
	for _, group in ipairs(plans.file_groups(record.path)) do
		for _, file in ipairs(group.files) do
			if #rows >= JUMP_CAP then
				overflow = overflow + 1
			else
				local purpose = FILE_PURPOSE[file]
				if not purpose then
					purpose = heading_of(record.path .. "/" .. file) or GROUP_PURPOSE[group.title] or "a plan file"
				end
				rows[#rows + 1] = {
					text = string.format("  %-34s — %s", truncate(file, 34), truncate(purpose, 44)),
					kind = "jump",
					file = record.path .. "/" .. file,
				}
			end
		end
	end
	if overflow > 0 then
		rows[#rows + 1] = {
			text = string.format("  … and %d more files under analysis_results/", overflow),
			hl = "Comment",
			kind = "info",
		}
	end
	return rows
end

local function build_rows(record)
	local rows = {
		{ text = truncate(record.title or record.name, 60), hl = "Title", kind = "header" },
		{
			text = string.format(
				"%s %s · %s %d/%d · %d%% · updated %s",
				record.icon or "·",
				record.label or "Unknown",
				progress_bar(record.tasks_done or 0, record.tasks_total or 0),
				record.tasks_done or 0,
				record.tasks_total or 0,
				record.percent or 0,
				record.mtime or ""
			),
			hl = record.highlight or "Comment",
			kind = "header",
		},
		{ text = "", kind = "blank" },
		{ text = "What this plan is about", hl = "Underlined", kind = "label" },
		{ text = truncate(goal_sentence(record), 90), kind = "goal" },
		{ text = "", kind = "blank" },
		{ text = "Tasks", hl = "Underlined", kind = "label" },
	}
	local tasks = task_rows(record)
	if #tasks == 0 then
		rows[#rows + 1] = { text = "  No task list recorded yet.", hl = "Comment", kind = "info" }
	end
	for _, row in ipairs(tasks) do
		rows[#rows + 1] = row
	end
	if record.blocked then
		rows[#rows + 1] = { text = "", kind = "blank" }
		rows[#rows + 1] = {
			text = "⚠ Needs attention — " .. (record.blocker_reason or "a human decision is waiting"),
			hl = "WarningMsg",
			kind = "info",
		}
	end
	rows[#rows + 1] = { text = "", kind = "blank" }
	rows[#rows + 1] = { text = "Open", hl = "Underlined", kind = "label" }
	local jumps = jump_rows(record)
	if #jumps == 0 then
		rows[#rows + 1] = { text = "  No plan files found.", hl = "Comment", kind = "info" }
	end
	for _, row in ipairs(jumps) do
		rows[#rows + 1] = row
	end
	rows[#rows + 1] = { text = "", kind = "blank" }
	rows[#rows + 1] = { text = "Next step", hl = "Underlined", kind = "label" }
	rows[#rows + 1] = {
		text = "  Ask your agent: /dwp-status " .. record.name,
		hl = "Comment",
		kind = "info",
	}
	rows[#rows + 1] = { text = "", kind = "blank" }
	rows[#rows + 1] = { text = "Enter open · q close · ? help · click a file line to open it", hl = "Comment", kind = "footer" }
	return rows
end

local function render(record)
	st.rows = build_rows(record)
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
	vim.api.nvim_buf_set_name(st.buf, "dwp-plan: " .. record.name)
end

-- Open the reader in the main window (never the sidebar itself): the
-- previous window when there is one, else the first non-sidebar window,
-- else the current one. The sidebar stays open beside it.
local function target_window()
	local sidebar_win = nil
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(w)
		if vim.bo[buf].filetype == "dwp-plans" then
			sidebar_win = w
		end
	end
	local prev = vim.fn.win_getid(vim.fn.winnr("#"))
	if prev ~= 0 and prev ~= sidebar_win and vim.api.nvim_win_is_valid(prev) then
		return prev
	end
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if w ~= sidebar_win then
			return w
		end
	end
	return vim.api.nvim_get_current_win()
end

local function current_row()
	if not st.buf or not vim.api.nvim_buf_is_valid(st.buf) then
		return nil
	end
	local win = vim.fn.bufwinid(st.buf)
	if win == -1 then
		return nil
	end
	return st.rows[vim.api.nvim_win_get_cursor(win)[1]]
end

local function open_file(path)
	vim.cmd("edit " .. vim.fn.fnameescape(path))
end

--- Open the rendered reader for one plan record (from dwp.plans.scan()).
--- Opening again (same or another plan) replaces the previous reader
--- buffer — one reader at a time, no name collisions.
function R.open(record)
	if not record or not record.path then
		return
	end
	if st.buf and vim.api.nvim_buf_is_valid(st.buf) then
		pcall(vim.api.nvim_buf_delete, st.buf, { force = true })
	end
	st.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[st.buf].buftype = "nofile"
	vim.bo[st.buf].bufhidden = "wipe"
	vim.bo[st.buf].buflisted = false
	vim.bo[st.buf].filetype = "dwp-plan"
	vim.bo[st.buf].swapfile = false
	render(record)

	local win = target_window()
	vim.api.nvim_set_current_win(win)
	vim.api.nvim_win_set_buf(win, st.buf)
	vim.wo[win].wrap = true
	vim.wo[win].cursorline = false

	local opts = { buffer = st.buf, silent = true, nowait = true }
	vim.keymap.set("n", "<CR>", function()
		local row = current_row()
		if row and row.kind == "jump" and row.file then
			open_file(row.file)
		end
	end, opts)
	vim.keymap.set("n", "<LeftMouse>", function()
		local row = current_row()
		if row and row.kind == "jump" and row.file then
			open_file(row.file)
		end
	end, opts)
	vim.keymap.set("n", "q", function()
		pcall(vim.cmd, "bdelete")
	end, opts)
	vim.keymap.set("n", "<Esc>", function()
		pcall(vim.cmd, "bdelete")
	end, opts)
	vim.keymap.set("n", "?", R.help, opts)
	return st.buf
end

local HELP_LINES = {
	"Plan reader — keys",
	"",
	"Enter    open the file on this line",
	"q / Esc  close the reader",
	"?        close this help",
	"",
	"Click a file line to open it.",
	"The reader never changes your plan —",
	"it explains it.",
}

function R.help()
	local help_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[help_buf].buftype = "nofile"
	vim.bo[help_buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, HELP_LINES)
	local width = 0
	for _, line in ipairs(HELP_LINES) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	local help_win = vim.api.nvim_open_win(help_buf, true, {
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
	for _, key in ipairs({ "?", "q", "<Esc>", "<CR>" }) do
		vim.keymap.set("n", key, function()
			vim.api.nvim_win_close(help_win, true)
		end, { buffer = help_buf, silent = true, nowait = true })
	end
end

--- Test hook: the rendered rows (text and metadata), for the smoke.
function R.rows()
	return st.rows
end

return R
