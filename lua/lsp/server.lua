-- Mason runs `npm`; make sure that is the real npm (see lsp/npm_guard.lua).
local npm_state = require("lsp.npm_guard").ensure()

require("mason").setup({
  PATH = "append",

  pip = {
    upgrade_pip = true,
  },

  ui = {
    icons = {
      package_pending = "",
      package_installed = "",
      package_uninstalled = "",
    },
  },
})

local servers = {
  "taplo",
  "yamlls",
  "jsonls",
  "lua_ls",
  "eslint",
  "emmet_ls",
  "dockerls",
  "marksman",
  "ts_ls",
  "rust_analyzer",
  "jedi_language_server",
}

-- Servers Mason installs with npm. With no usable npm they cannot install, so
-- they are left out of ensure_installed (one notice, not one error per server
-- on every start).
local npm_servers = {
  yamlls = true, jsonls = true, eslint = true, emmet_ls = true, dockerls = true,
  ts_ls = true,
}

local wanted = vim.deepcopy(servers)
if not npm_state.ok then
  wanted = vim.tbl_filter(function(name)
    return not npm_servers[name]
  end, wanted)
  vim.schedule(function()
    vim.notify(
      "DeepWorkPlan Vim: skipped " .. "the language servers that need npm: " .. npm_state.reason,
      vim.log.levels.WARN
    )
  end)
end

require("mason-lspconfig").setup({
  ensure_installed = wanted,
})

local ok_caps, capabilities = pcall(require, "lsp.capabilities")
if not ok_caps then
  capabilities = vim.lsp.protocol.make_client_capabilities()
end

local defaults = {
  capabilities = capabilities,
}

local configs = {

  lua_ls = {
    settings = {
      Lua = {
        diagnostics = {
          globals = { "vim" },
        },
      },
    },
  },

  marksman = {
    -- Debian slim has no libicu, so the binary abort()s unless globalization
    -- is invariant. `server` is already stdio; passing `--stdio` makes it exit 1.
    -- Diff views name the buffer `diffview://...`. Marksman treats that as a
    -- workspace URI, fails to parse the host, and exits. Only start on a real file.
    cmd = { "marksman", "server" },
    cmd_env = {
      DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1",
    },
    root_dir = function(bufnr, on_dir)
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:sub(1, 1) ~= "/" or name:find("://", 1, true) then
        return
      end
      on_dir(vim.fs.root(bufnr, { ".git" }) or vim.fs.dirname(name))
    end,
  },

  ts_ls = {
    root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
    init_options = {
      preferences = {
        disableSuggestions = true,
        importModuleSpecifierPreference = "non-relative",
      },
    },
  },
}

-- Mason installs these on first start. Enabling one before its binary exists
-- makes nvim stop on "Press ENTER" (Spawning language server failed).
local function server_ready(name)
  local ok, mapping = pcall(function()
    return require("mason-lspconfig").get_mappings().lspconfig_to_package[name]
  end)
  if not ok or not mapping then
    return true
  end
  local pkg_ok, pkg = pcall(require("mason-registry").get_package, mapping)
  if not pkg_ok then
    return true
  end
  return pkg:is_installed()
end

for _, server in ipairs(servers) do
  vim.lsp.config(server, vim.tbl_deep_extend("force", defaults, configs[server] or {}))
  if server_ready(server) then
    vim.lsp.enable(server)
  end
end

vim.api.nvim_create_autocmd("User", {
  pattern = "MasonToolsUpdateCompleted",
  callback = function()
    for _, server in ipairs(servers) do
      if server_ready(server) then
        vim.lsp.enable(server)
      end
    end
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("muvim_lsp_attach", { clear = true }),
  callback = function(ev)
    local opts = { buffer = ev.buf, silent = true, noremap = true }
    vim.keymap.set("n", "gd", function()
      vim.lsp.buf.definition()
    end, vim.tbl_extend("keep", { desc = "Go to definition" }, opts))
    vim.keymap.set("n", "gD", function()
      vim.lsp.buf.declaration()
    end, vim.tbl_extend("keep", { desc = "Go to declaration" }, opts))
    vim.keymap.set("n", "gi", function()
      vim.lsp.buf.implementation()
    end, vim.tbl_extend("keep", { desc = "Go to implementation" }, opts))
    vim.keymap.set("n", "gr", function()
      vim.lsp.buf.references()
    end, vim.tbl_extend("keep", { desc = "Find references" }, opts))
  end,
})

local alias_fts = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
}

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("muvim_path_alias", { clear = true }),
  pattern = alias_fts,
  callback = function()
    pcall(function()
      require("lsp.alias").setup_buffer()
    end)
  end,
})
