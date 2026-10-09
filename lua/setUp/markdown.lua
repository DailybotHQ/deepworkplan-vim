-- render-markdown.nvim set-up. This module is loaded by the plugin spec's
-- config callback (see plugins.lua), which pckr runs when the plugin first
-- loads on a markdown buffer — never at boot. The defaults are the
-- deliberate configuration; only conceal behavior is pinned so toggling
-- never leaves stray hidden text.

local ok = pcall(require, "render-markdown")
if not ok then
	return
end

require("render-markdown").setup({
	anti_conceal = {
		enabled = true,
	},
})
