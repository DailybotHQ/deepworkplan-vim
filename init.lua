-- Byte-code cache for Lua modules (Neovim 0.9+): the single biggest startup
-- saving, so it comes before any require. A no-op on older Neovim.
if vim.loader then
  vim.loader.enable()
end

-- SETTINGS

-- Nvim Basics
require('settings')
-- Key map
require('mapping')
-- Auto commands
require('autocommand')

-- PLUGIN
-- Plugin list
require('plugins')
-- Set up
require("composition")
