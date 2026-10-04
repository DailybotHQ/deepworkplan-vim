local alpha = require("alpha")
local function button(sc, txt, keybind)
	local sc_ = sc:gsub("%s", ""):gsub("SPC", "<leader>")

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

default.ascii = {
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡆⡆⠀⠀⠀⠀⠀⢀⠜⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠁⢰⠀⠀⠀⠀⢀⠊⢠⠀⠀⢠⠀⠀⠀⠀⢠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠀⠀⡆⠀⠀⠠⠃⠀⡘⠀⠀⡘⠀⠀⠀⠀⡘⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⢰⠀⡰⠁⠀⠀⠇⠀⠀⡇⠀⠀⠀⢀⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠰⠀⠀⠀⠀⠞⠀⠀⠀⠰⠀⠀⢰⠑⠤⠤⠔⠱⠀⣿⡆⠀⠀⠀⣾⡗⠀⠀⠰⣿⠆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡌⠀⠀⠀⠀⠀⠀⠸⣿⡄⠀⣸⣿⠁⠀⣴⣶⣶⡄⠀⠀⢰⣦⣶⣤⣴⣶⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣷⢠⣿⠇⠀⠀⠀⠀⣿⡇⠀⠀⢸⣿⠀⣿⡏⠈⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⡟⠀⠀⠀⠀⠀⣿⡇⠀⠀⢸⣿⠀⣿⡇⠀⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠿⠁⠀⠀⠀⠀⠀⠿⠿⠿⠀⠸⠟⠀⠻⠇⠀⠿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
}

default.logo = {
	"⠀⢠⣤",
	"⠀⠈⠉⠀⢀⣀⣤⣤⣄⣀    ⠀⠀⣿⣿⠀⠀⣿⣿⣿⠀⠀⣿⠀⠀⣿⠀⠀⠀⣿⠀⣿⠀⣿⣿⠀⠀⠀⣿⣿⠀⣿⣿⣿",
	"⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣦⡀ ⠀⠀⣿⠀⣿⠀⣿⠀⣿⠀⠀⣿⠀⠀⣿⠀⠀⠀⣿⠀⣿⠀⣿⠀⣿⠀⣿⠀⣿⠀⠀⣿⠀",
	"⠀⣰⣿⣿⣿⡿⠋⠻⣿⠟⠙⢿⣷⡀⠀⠀⣿⠀⣿⠀⣿⣿⣿⠀⠀⣿⠀⠀⣿⠀⠀⠀⠀⣿⣿⠀⣿⣿⠀⠀⣿⠀⣿⠀⠀⣿⠀",
	"⠀⣿⣿⣿⣿⣧⡀⣠⣿⣄⢀⣼⣿⡇⠀⠀⣿⠀⣿⠀⣿⠀⣿⠀⠀⣿⠀⠀⣿⠀⠀⠀⠀⠀⣿⠀⣿⠀⣿⠀⣿⠀⣿⠀⠀⣿⠀",
	"⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⣿⣿⠀⠀⣿⠀⣿⠀⠀⣿⠀⠀⣿⣿⣿⠀⠀⣿⣿⠀⣿⣿⠀⠀⠀⣿⣿⠀⠀⣿⠀",
	"⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⡿⠃",
	"⠀⠀⠀⠈⠙⠛⠿⠿⠟⠛⠉",
}

default.header = {
	type = "text",
	val = default.ascii,
	opts = {
		position = "center",
		hl = "AlphaHeader",
	},
}

default.buttons = {
	type = "group",
	val = {
		button("SPC P", "  Plans  ", ":lua require('dwp.sidebar').toggle()<CR>"),
		button("SPC h h", "  Commands  ", ":lua require('mapping.glossary').open()<CR>"),
		button("SPC f f", "  Find File  ", ":Telescope find_files<CR>"),
		button("SPC f o", "  Recent File  ", ":Telescope oldfiles<CR>"),
		button("SPC f w", "  Find Word  ", ":Telescope live_grep<CR>"),
		button("SPC b m", "  Bookmarks  ", ":Telescope marks<CR>"),
	},
	opts = {
		spacing = 1,
	},
}

default.brand = {
	type = "text",
	val = default.logo,
	opts = {
		position = "center",
		hl = "AlphaHeader",
	},
}

-- Plans overview (Phase 2): the top plans at a glance above the buttons,
-- one gesture from the reader (Enter on a plan row) and one from the
-- sidebar (the [e] button; alpha text rows carry no on_press, so each
-- row is a button — the capability that decided the wiring). Defensive
-- by contract: any failure building the section omits it; the dashboard
-- always boots.
default.plans_section = { type = "group", val = {}, opts = { spacing = 1 } }
do
	local built, section = pcall(require, "dwp.greeter_plans")
	if built and type(section) == "table" then
		local ok, data = pcall(section.build)
		if ok and type(data) == "table" then
			local el = default.plans_section.val
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
				el[#el + 1] = {
					type = "text",
					val = data.hint,
					opts = { position = "center", hl = "Comment" },
				}
				el[#el + 1] = button("e", "  Open plans sidebar  ", ":lua require('dwp.sidebar').toggle()<CR>")
			end
		end
	end
end

alpha.setup({
	layout = {
		{ type = "padding", val = 2 },
		default.header,
		{ type = "padding", val = 1 },
		default.brand,
		{ type = "padding", val = 2 },
		default.plans_section,
		{ type = "padding", val = 1 },
		default.buttons,
	},
	opts = {},
})
alpha.start(true)
