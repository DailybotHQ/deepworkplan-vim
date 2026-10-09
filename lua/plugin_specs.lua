-- The curated plugin list: pure data (vim is used only inside run/config
-- functions, which never run on load), so tests and the lock refresh
-- script can read it without Neovim. Each entry is pinned to a commit by
-- pckr/lockfile.lua — lua/plugins.lua injects the pins; adding a plugin
-- here without refreshing the lock fails tests/smoke/plugin_lock.lua
-- (refresh: bash scripts/update-plugin-lock.sh).
return {

  -- LSP
  "neovim/nvim-lspconfig",
  "williamboman/mason.nvim",
  "williamboman/mason-lspconfig.nvim",
  "mfussenegger/nvim-lint",
  "mhartington/formatter.nvim",

  -- Completion
  {
    "hrsh7th/nvim-cmp",
    requires = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim",
    },
  },
  "L3MON4D3/LuaSnip",

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    run = ":TSUpdate",
  },
  "windwp/nvim-ts-autotag",

  -- UI
  {
    "nvim-tree/nvim-tree.lua",
    requires = "nvim-tree/nvim-web-devicons",
  },
  "akinsho/bufferline.nvim",
  "nvim-lualine/lualine.nvim",
  {
    "goolord/alpha-nvim",
    requires = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "nvim-telescope/telescope.nvim",
    },
  },
  "nvim-telescope/telescope.nvim",
  "lukas-reineke/indent-blankline.nvim",

  -- Motion
  "christoomey/vim-tmux-navigator",
  "easymotion/vim-easymotion",

  -- Git
  "tpope/vim-fugitive",
  "mhinz/vim-signify",
  {
    "sindrets/diffview.nvim",
    requires = "nvim-lua/plenary.nvim",
  },

  -- Syntax / edit
  "sheerun/vim-polyglot",
  "preservim/nerdcommenter",
  "terryma/vim-multiple-cursors",
  "jiangmiao/auto-pairs",
  "tpope/vim-surround",
  "tpope/vim-repeat",
  "editorconfig/editorconfig-vim",
  "ap/vim-css-color",
  "KabbAmine/vCoolor.vim",

  -- Preview / live
  {
    "iamcco/markdown-preview.nvim",
    run = function()
      vim.fn["mkdp#util#install"]()
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    requires = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    ft = { "markdown" },
    config = function()
      require("setUp.markdown")
    end,
  },
  {
    "turbio/bracey.vim",
    run = "pnpm install --prefix server",
    cmd = "Bracey",
  },

  -- Utilities
  {
    "Pocco81/auto-save.nvim",
  },

}
