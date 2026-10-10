-- LSP config

local function safe_require(mod)
  local ok = pcall(require, mod)
  return ok
end

-- First of all: Mason snapshots PATH when it first loads (capabilities pulls
-- it in), so the real npm has to be in place before that.
pcall(function()
  require("lsp.npm_guard").ensure()
end)

safe_require("lsp.capabilities")
safe_require("lsp.server")
safe_require("lsp.formatter")
safe_require("lsp.completion")
safe_require("lsp.alias")
