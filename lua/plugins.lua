local function bootstrap_pckr()
  local pckr_path = vim.fn.stdpath("data") .. "/pckr/pckr.nvim"
  local fs = vim.uv or vim.loop

  if not fs.fs_stat(pckr_path) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/lewis6991/pckr.nvim",
      pckr_path,
    })
  end

  vim.opt.rtp:prepend(pckr_path)
end

bootstrap_pckr()

-- Headless bootstrap (install.sh, images): no autoinstall inside add().
-- With autoinstall on, add() starts asynchronous clones that the VimEnter
-- sync below does not wait for; quitting on the sync's completion callback
-- then killed them mid-checkout, leaving empty clones (seen in a fresh
-- container). Off, the sync performs every install and its callback is the
-- real end. Interactive launches keep autoinstall.
if vim.tbl_contains(vim.v.argv, "--headless") then
  require("pckr").setup({ autoinstall = false })
end

require("pckr").add({

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

})

-- First launch: no plugins cloned yet. Detected on the filesystem — the
-- same check install.sh uses — because `require('mason')` cannot work
-- here: plugins only reach the runtimepath once pckr loads them, so a
-- require-based probe would be false on EVERY launch and re-sync (with
-- its input-stealing display window) on every start.
local pckr_opt = vim.fn.stdpath("data") .. "/site/pack/pckr/opt"
-- install.sh sets DWP_VIM_BOOTSTRAP=1 for its headless run, which also
-- repairs installs whose plugins are incomplete (mason.nvim may exist).
if vim.env.DWP_VIM_BOOTSTRAP == "1" or vim.fn.isdirectory(pckr_opt .. "/mason.nvim") == 0 then
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      -- require('pckr') exports only add/setup; the operations live in
      -- pckr.actions (async.sync-wrapped: the third argument is the
      -- completion callback).
      local ok, actions = pcall(require, "pckr.actions")
      if not ok then
        return
      end
      -- Headless (install.sh bootstrap): run a full sync and exit on its
      -- completion callback — no quit-and-reopen dance. Headless runs have
      -- autoinstall off (above), so this sync performs every install; the
      -- short defer only lets its final output flush.
      if #vim.api.nvim_list_uis() == 0 then
        actions.sync(nil, nil, function()
          vim.defer_fn(function()
            print("pckr: plugins installed")
            vim.cmd("qa!")
          end, 1000)
        end)
        return
      end
      vim.notify(
        "Installing plugins. Quit Neovim when it finishes, then open it again.",
        vim.log.levels.INFO
      )
      actions.sync()
    end,
  })
end
