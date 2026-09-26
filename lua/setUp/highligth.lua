require("nvim-treesitter").setup({
  highlight = {
    enable = true,
    disable = {},
    -- Neovim 0.12 paints markdown. Regex on top of treesitter washed the colors out.
    additional_vim_regex_highlighting = false,
  },

  autotag = {
    enable = true,
  },

  indent = {
    enable = false,
    disable = {},
  },

  ensure_installed = {
    "c",
    "cpp",
    "lua",
    "vim",
    "css",
    "html",
    "bash",
    "java",
    "rust",
    "json",
    "yaml",
    "python",
    "javascript",
    "typescript",
  },

  ignore_install = {},
})
