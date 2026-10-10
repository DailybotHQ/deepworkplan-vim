local alpha = require("alpha")
local function button(sc, txt, keybind)
	-- The shortcut label doubles as the binding source: first-exposure
	-- labels spell "Space" (UX2-01), so both spellings derive <leader>.
	local sc_ = sc:gsub("%s", ""):gsub("SPC", "<leader>"):gsub("Space", "<leader>")

	local opts = {
		position = "center",
		text = txt,
		shortcut = sc,
		cursor = 5,
		width = 36,
		align_shortcut = "right",
		hl = "AlphaButtons",
	}

	if keybind then
		opts.keymap = { "n", sc_, keybind, { noremap = true, silent = true } }
	end

	return {
		type = "button",
		val = txt,
		on_press = function()
			-- Enter runs the button's own Ex command directly. Feeding the
			-- leader chord instead relies on pending-map resolution, which
			-- can swallow the space on dashboard buffers in some terminals;
			-- the chord stays available as its normal-mode mapping anyway.
			if keybind then
				local cmd = vim.api.nvim_replace_termcodes(keybind, true, false, true)
				vim.api.nvim_feedkeys(cmd, "m", false)
				return
			end
			local key = vim.api.nvim_replace_termcodes(sc_, true, false, true)
			vim.api.nvim_feedkeys(key, "normal", false)
		end,
		opts = opts,
	}
end

local default = {}

local art = require("setUp.greeter_art")
local bottom = require("setUp.greeter_bottom")
art.define_highlights()
-- Colour schemes clear custom groups on :colorscheme; redefine after.
vim.api.nvim_create_autocmd("ColorScheme", { callback = art.define_highlights })

local SHORTCUTS = {
	{ key = "Space P", label = "  Plans  ", cmd = ":lua require('dwp.sidebar').toggle()<CR>" },
	{ key = "Space h h", label = "  Commands  ", cmd = ":lua require('mapping.glossary').open()<CR>" },
	{ key = "Space f f", label = "  Find File  ", cmd = ":Telescope find_files<CR>" },
	{ key = "Space f o", label = "  Recent File  ", cmd = ":Telescope oldfiles<CR>" },
	{ key = "Space f w", label = "  Find Word  ", cmd = ":Telescope live_grep<CR>" },
	{ key = "Space b m", label = "  Bookmarks  ", cmd = ":Telescope marks<CR>" },
}

-- Run an Ex command the way a button does (see button()).
local function run_cmd(cmd)
	return function()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(cmd, true, false, true), "m", false)
	end
end

-- Reader and sidebar load on first use only: the dashboard build stays
-- free of their requires.
local function toggle_sidebar()
	require("dwp.sidebar").toggle()
end

local function open_plan(record)
	require("dwp.reader").open(record)
end

-- Plans overview data, built once per dashboard draw (the scan costs tens
-- of ms and must not tax boots that never open the dashboard). Defensive by
-- contract: any failure yields nil and the section is omitted.
local function plan_data()
	if default._plan_data == nil then
		default._plan_data = false
		local built, section = pcall(require, "dwp.greeter_plans")
		if built and type(section) == "table" then
			local ok, data = pcall(section.build)
			if ok and type(data) == "table" then
				default._plan_data = data
			end
		end
	end
	return default._plan_data or nil
end

-- The bottom is two columns (shortcuts | your plans) when the window is wide
-- enough, stacked alpha buttons otherwise. Composed once per draw.
local function two_columns()
	local block = bottom.compose(
		vim.tbl_map(function(sc)
			return { label = sc.label, key = sc.key, run = run_cmd(sc.cmd) }
		end, SHORTCUTS),
		plan_data(),
		{ sidebar = toggle_sidebar, open_plan = open_plan }
	)
	if vim.api.nvim_win_get_width(0) >= block.width + 6 then
		return block
	end
	return nil
end

-- Stacked layout (narrow windows): real alpha buttons, one under another.
default.buttons = { type = "group", val = {}, opts = { spacing = 0 } }
for _, sc in ipairs(SHORTCUTS) do
	default.buttons.val[#default.buttons.val + 1] = button(sc.key, sc.label, sc.cmd)
end

default.plans_section = {
	type = "group",
	val = function()
		local el = {}
		local data = plan_data()
		if data then
			if #data.plan_lines == 0 then
				el[#el + 1] = {
					type = "text",
					val = data.empty_line,
					opts = { position = "center", hl = "Comment" },
				}
			else
				el[#el + 1] = {
					type = "text",
					val = data.header,
					opts = { position = "center", hl = "AlphaHeader" },
				}
				el[#el + 1] = { type = "padding", val = 1 }
				for _, row in ipairs(data.plan_lines) do
					el[#el + 1] = {
						type = "button",
						val = row.text,
						on_press = function()
							open_plan(row.record)
						end,
						opts = {
							position = "center",
							hl = "AlphaButtons",
							cursor = 3,
							width = 60,
							align_shortcut = "right",
						},
					}
				end
				-- Short windows drop the spacer and the second hint so the
				-- artwork keeps its rows.
				local tight = vim.api.nvim_win_get_height(0) < 50
				if not tight then
					el[#el + 1] = { type = "padding", val = 1 }
				end
				el[#el + 1] = { type = "text", val = data.hint, opts = { position = "center", hl = "Comment" } }
				if data.hint_click and not tight then
					el[#el + 1] = {
						type = "text",
						val = data.hint_click,
						opts = { position = "center", hl = "Comment" },
					}
				end
				el[#el + 1] = button("e", "  Open plans sidebar  ", ":lua require('dwp.sidebar').toggle()<CR>")
			end
		end
		return el
	end,
	opts = { spacing = 0 },
}

-- Rows the stacked bottom needs (plans overview + padding + buttons).
local function stacked_rows()
	local rows = 0
	for _, el in ipairs(default.plans_section.val()) do
		rows = rows + (el.type == "padding" and el.val or 1)
	end
	return rows + 1 + #SHORTCUTS
end

-- Bottom of the dashboard: one text block with both columns, or the stacked
-- elements. The block is remembered so <CR> can activate its rows.
default.bottom = {
	type = "group",
	val = function()
		default._block = two_columns()
		if default._block then
			return {
				{
					type = "text",
					val = default._block.lines,
					opts = { position = "center", hl = default._block.hl },
				},
			}
		end
		return {
			default.plans_section,
			{ type = "padding", val = 1 },
			default.buttons,
		}
	end,
}

-- The hero is composed when the dashboard draws (it depends on the window),
-- so a narrow terminal gets the wordmark stacked alone.
default.header = {
	type = "group",
	val = function()
		-- Rows the dashboard needs outside the hero: top padding, the spacer
		-- and the bottom (known before composing it).
		local block = two_columns()
		local bottom_rows = block and #block.lines or stacked_rows()
		local below = 1 + 1 + bottom_rows
		-- The window, not the screen: the command line and status line take rows.
		local hero = art.compose(nil, vim.api.nvim_win_get_height(0), below)
		return { { type = "text", val = hero.lines, opts = { position = "center", hl = hero.hl } } }
	end,
}

alpha.setup({
	layout = {
		{ type = "padding", val = 1 },
		default.header,
		{ type = "padding", val = 1 },
		default.bottom,
	},
	opts = {},
})

-- Activation for the two-column block (alpha buttons cannot sit side by
-- side): <CR> runs the row's action for the column under the cursor; `e`
-- opens the plans sidebar; anything else falls through to alpha.
local function activate()
	local block = default._block
	local buf = vim.api.nvim_get_current_buf()
	if block then
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
		for i, text in ipairs(block.lines) do
			if #line >= #text and line:sub(-#text) == text then
				local c = col - (#line - #text)
				local act = block.rows[i]
				local fn = c >= block.split[i] and act.right or act.left
				fn = fn or act.right or act.left
				if fn then
					return fn()
				end
			end
		end
	end
	alpha.press()
end

local function wire_block(buf)
	local block = default._block
	if not block then
		return
	end
	vim.keymap.set("n", "<CR>", activate, { buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "e", toggle_sidebar, { buffer = buf, nowait = true, silent = true })
	-- Start on the first shortcut so Enter does something useful at once.
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local first = block.lines[3]
	for lnum, line in ipairs(lines) do
		if first and #line >= #first and line:sub(-#first) == first then
			vim.api.nvim_win_set_cursor(0, { lnum, #line - #first + 2 })
			break
		end
	end
end

-- The dashboard draws on VimEnter, not at require time: alpha.start(true)
-- is designed for the VimEnter moment (it checks whether a file was
-- opened), and starting at require made every boot — even +qa! boots
-- that never show a dashboard — pay the alpha layout plus the plans
-- scan (startup ceiling; UX_AUDIT §10, D-5).
-- The beam pulses while the dashboard is on screen (see greeter_art).
vim.api.nvim_create_autocmd("User", {
	pattern = "AlphaReady",
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		wire_block(buf)
		art.start_pulse(buf)
	end,
})
vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		alpha.start(true)
	end,
})
