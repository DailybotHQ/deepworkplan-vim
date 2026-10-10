-- Space f -> :Format
-- Python: black
-- JS/TS/JSON/CSS/GraphQL: biome (Rust)
-- Shell: shfmt  Lua: stylua

local function biome()
	return {
		exe = "biome",
		args = { "format", "--stdin-file-path", vim.api.nvim_buf_get_name(0) },
		stdin = true,
	}
end

require("formatter").setup({
	logging = true,
	log_level = vim.log.levels.WARN,
	filetype = {
		sh = { require("formatter.filetypes.sh").shfmt },

		javascript = { biome },
		typescript = { biome },
		javascriptreact = { biome },
		typescriptreact = { biome },
		json = { biome },
		css = { biome },
		graphql = { biome },

		python = { require("formatter.filetypes.python").black },

		lua = { require("formatter.filetypes.lua").stylua },
		["*"] = { require("formatter.filetypes.any").remove_trailing_whitespace },
	},
})
