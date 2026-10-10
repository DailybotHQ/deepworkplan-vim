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
art.define_highlights()
-- Colour schemes clear custom groups on :colorscheme; redefine after.
vim.api.nvim_create_autocmd("ColorScheme", { callback = art.define_highlights })

-- The hero is composed when the dashboard draws (it depends on the
-- window width), so a narrow terminal gets the wordmark stacked alone.
default.header = {
	type = "group",
	val = function()
		-- Rows the dashboard needs outside the hero: top padding, the plans
		-- overview (built here so its size is known; it is cached), the
		-- buttons and the spacers between them.
		local ok, plans = pcall(default.plans_section.val)
		local plan_rows = 0
		if ok and type(plans) == "table" then
			for _, el in ipairs(plans) do
				plan_rows = plan_rows + (el.type == "padding" and el.val or 1)
			end
		end
		local below = 1 + 1 + plan_rows + 1 + 6
		-- The window, not the screen: the command line and status line take rows.
		local hero = art.compose(nil, vim.api.nvim_win_get_height(0), below)
		return { { type = "text", val = hero.lines, opts = { position = "center", hl = hero.hl } } }
	end,
}

default.buttons = {
	type = "group",
	val = {
		button("Space P", "  Plans  ", ":lua require('dwp.sidebar').toggle()<CR>"),
		button("Space h h", "  Commands  ", ":lua require('mapping.glossary').open()<CR>"),
		button("Space f f", "  Find File  ", ":Telescope find_files<CR>"),
		button("Space f o", "  Recent File  ", ":Telescope oldfiles<CR>"),
		button("Space f w", "  Find Word  ", ":Telescope live_grep<CR>"),
		button("Space b m", "  Bookmarks  ", ":Telescope marks<CR>"),
	},
	opts = {
		spacing = 0,
	},
}

-- Plans overview (Phase 2): the top plans at a glance above the buttons,
-- one gesture from the reader (Enter on a plan row) and one from the
-- sidebar (the [e] button; alpha text rows carry no on_press, so each
-- row is a button — the capability that decided the wiring). Defensive
-- by contract: any failure building the section omits it; the dashboard
-- always boots. Built when the dashboard first DRAWS, not at require
-- time: the plans scan costs tens of ms and must not tax boots that
-- never open the dashboard (startup ceiling; UX_AUDIT §10, D-5).
default.plans_section = { type = "group", val = function()
	if default._plans_built then
		return default._plans_built
	end
	local el = {}
	local built, section = pcall(require, "dwp.greeter_plans")
	if built and type(section) == "table" then
		local ok, data = pcall(section.build)
		if ok and type(data) == "table" then
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
						-- Reader and sidebar load on first use only — the
						-- dashboard build stays free of their requires.
						on_press = function()
							require("dwp.reader").open(row.record)
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
				el[#el + 1] = {
					type = "text",
					val = data.hint,
					opts = { position = "center", hl = "Comment" },
				}
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
	end
	default._plans_built = el
	return el
end, opts = { spacing = 0 } }

alpha.setup({
	layout = {
		{ type = "padding", val = 1 },
		default.header,
		{ type = "padding", val = 1 },
		default.plans_section,
		{ type = "padding", val = 1 },
		default.buttons,
	},
	opts = {},
})
-- The dashboard draws on VimEnter, not at require time: alpha.start(true)
-- is designed for the VimEnter moment (it checks whether a file was
-- opened), and starting at require made every boot — even +qa! boots
-- that never show a dashboard — pay the alpha layout plus the plans
-- scan (startup ceiling; UX_AUDIT §10, D-5).
-- The beam pulses while the dashboard is on screen (see greeter_art).
vim.api.nvim_create_autocmd("User", {
	pattern = "AlphaReady",
	callback = function()
		art.start_pulse(vim.api.nvim_get_current_buf())
	end,
})
vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		alpha.start(true)
	end,
})
