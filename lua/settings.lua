local set = vim.opt

-- Performance
set.lazyredraw = true

-- Number line
set.sw = 2
set.number = true
set.relativenumber = true

-- Interface style
set.ruler = true
set.hidden = true
set.cmdheight = 1
set.showcmd = true
set.backup = false
set.showmode = false
set.showmatch = true
set.swapfile = false
set.splitright = true
set.display="lastline"
set.encoding = "UTF-8"
set.writebackup = false
set.termguicolors = true

-- Spelling
set.spell = true
set.spelllang = { "en_us" }

-- Mouse support
set.mouse = "a"
set.title = true
set.visualbell = true
set.cursorline = false
set.clipboard = "unnamedplus"

-- Without a system clipboard tool (containers, SSH, bare hosts) "+ has no
-- provider and a yank never leaves the editor. Fall back to OSC 52: the
-- terminal receives the text and puts it on the system clipboard. Paste
-- reads the unnamed register (the terminal's own cmd+v pastes text typed
-- from outside, bracketed).
if vim.fn.executable("pbcopy") + vim.fn.executable("wl-copy") + vim.fn.executable("xclip") + vim.fn.executable("xsel") + vim.fn.executable("win32yank.exe") == 0 then
	local osc52 = require("vim.ui.clipboard.osc52")
	local function register()
		return function()
			return { vim.fn.split(vim.fn.getreg('"'), "\n"), vim.fn.getregtype('"') }
		end
	end
	vim.g.clipboard = {
		name = "OSC 52",
		copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
		paste = { ["+"] = register(), ["*"] = register() },
	}
end

-- Autos
set.autoindent = true
set.updatetime = 300
set.autowrite = true

-- Spaces & Tabs
set.tabstop = 2
set.shiftwidth = 2
set.softtabstop = 2
set.expandtab = true

-- Prefixes
set.completeopt = { "menu", "menuone", "noselect" }
set.errorformat:append("%f|%l col %c|%m")
-- Tabs as the same bar indent-blankline uses (not the default `tab:> `).
set.listchars = { tab = "▏ ", space = "⋅", eol = "↴", trail = "·" }
set.list = true

local disabled_built_ins = {
	"netrw",
	"netrwPlugin",
	"netrwSettings",
	"netrwFileHandlers",
	"gzip",
	"zip",
	"zipPlugin",
	"tar",
	"tarPlugin",
	"getscript",
	"getscriptPlugin",
	"vimball",
	"vimballPlugin",
	"2html_plugin",
	"logipat",
	"rrhelper",
	"spellfile_plugin",
	"matchit",
}

for _, plugin in pairs(disabled_built_ins) do
	vim.g["loaded_" .. plugin] = 1
end
