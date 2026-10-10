-- One sidebar at a time: looking at the plans, you should not also be looking at
-- the file tree (and the other way round). Opening either closes the other.
--
-- Event-driven so each side stays independent: the plans sidebar announces
-- itself with `User DwpPlansOpened` (lua/dwp never requires a plugin), and
-- nvim-tree announces `TreeOpen`. Turn it off with `sidebars.exclusive = false`
-- in dwpvim.json (docs/CONFIGURATION.md).
local ok_cfg, userconfig = pcall(require, "userconfig")
if ok_cfg and userconfig.get("sidebars.exclusive") == false then
	return
end

local group = vim.api.nvim_create_augroup("DwpExclusiveSidebars", { clear = true })

-- Plans opened -> close the tree.
vim.api.nvim_create_autocmd("User", {
	group = group,
	pattern = "DwpPlansOpened",
	callback = function()
		local ok, api = pcall(require, "nvim-tree.api")
		if ok and api.tree.is_visible() then
			api.tree.close()
		end
	end,
})

-- Tree opened -> close the plans sidebar.
local ok, api = pcall(require, "nvim-tree.api")
if ok then
	api.events.subscribe(api.events.Event.TreeOpen, function()
		local ok_s, sidebar = pcall(require, "dwp.sidebar")
		if ok_s and sidebar.is_open() then
			sidebar.close()
		end
	end)
end
