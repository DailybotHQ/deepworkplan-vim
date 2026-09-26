require("nvim-tree").setup({
	-- vim.system():wait() returns nil when git exceeds the default 400ms
	-- budget. nvim-tree then indexes that nil and the tree errors on expand.
	git = {
		timeout = 10000,
	},

	disable_netrw = true,
	hijack_netrw = true,
	open_on_tab = false,
	hijack_cursor = false,
	update_cwd = false,

	diagnostics = {
		enable = true,
		icons = {
			hint = "",
			info = "",
			error = "",
			warning = "",
		},
	},

	update_focused_file = {
		update_cwd = false,
		enable = true,
		ignore_list = {},
	},

	filters = {
    git_ignored = false,
		dotfiles = false,
		custom = {},
	},

	view = {
		width = 60,
		side = "right",
		adaptive_size = true,
		centralize_selection = false,
		preserve_window_proportions = false,
		relativenumber = false,
		number = false,
		signcolumn = "yes",
	},

	-- e edits the whole name, extension included. The plugin default
	-- only selects the part before the last dot.
	on_attach = function(bufnr)
		local api = require("nvim-tree.api")
		api.config.mappings.default_on_attach(bufnr)
		vim.keymap.set("n", "e", api.fs.rename, {
			desc = "nvim-tree: Rename",
			buffer = bufnr,
			noremap = true,
			silent = true,
			nowait = true,
		})
	end,

	renderer = {
		full_name = false,
		group_empty = false,
		add_trailing = false,
		-- Letter in the sign column, name tinted. The icon keeps its file color.
		highlight_git = "name",
		highlight_opened_files = "none",
		icons = {
			-- Git owns the left margin. Diagnostics live after the name so a
			-- warning never hides M / A / D.
			git_placement = "signcolumn",
			diagnostics_placement = "after",
			glyphs = {
				git = {
					unstaged = "M",
					staged = "M",
					unmerged = "U",
					renamed = "R",
					untracked = "A",
					deleted = "D",
					ignored = "◌",
				},
			},
		},
		root_folder_modifier = ":~",
		indent_width = 2,
		indent_markers = {
			enable = false,
			inline_arrows = true,
			icons = {
				corner = "└",
				edge = "│",
				item = "│",
				bottom = "─",
				none = " ",
			},
		},
	},
})

local function open_nvim_tree(data)
	-- buffer is a directory
	local directory = vim.fn.isdirectory(data.file) == 1

	if not directory then
		return
	end

	-- change to the directory
	vim.cmd.cd(data.file)

	-- open the tree
	require("nvim-tree.api").tree.open()
end

vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })
