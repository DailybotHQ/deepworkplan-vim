-- Plugin-reference smoke: static, hermetic (reads the Lua tree, loads no
-- plugin, touches no network). Three guards:
--   1. every plugin module `require`d under lua/ and init.lua belongs to a
--      plugin declared in lua/plugin_specs.lua — removing a plugin cannot
--      leave a dangling require behind;
--   2. no retired plugin's module is required (nvim-lint -> `lint`);
--   3. init.lua enables vim.loader before its first require (startup budget);
--   4. docs/PLUGINS.md has an entry for every plugin and every server.
-- The scanner first proves itself on a planted tree (red) and a clean one
-- (green). Run via tests/smoke/run.sh.

local count, fails = 0, 0
local function ok(cond, msg)
	count = count + 1
	if not cond then
		fails = fails + 1
		print("FAIL: " .. msg)
	end
end

-- Root module -> the plugin repository that provides it. Modules of the
-- repository's own tree (setUp, mapping, lsp, dwp, scheme, ...) are not here.
local PROVIDES = {
	lspconfig = "neovim/nvim-lspconfig",
	mason = "williamboman/mason.nvim",
	["mason-core"] = "williamboman/mason.nvim",
	["mason-registry"] = "williamboman/mason.nvim",
	["mason-lspconfig"] = "williamboman/mason-lspconfig.nvim",
	formatter = "mhartington/formatter.nvim",
	cmp = "hrsh7th/nvim-cmp",
	cmp_nvim_lsp = "hrsh7th/cmp-nvim-lsp",
	cmp_luasnip = "saadparwaiz1/cmp_luasnip",
	lspkind = "onsails/lspkind.nvim",
	luasnip = "L3MON4D3/LuaSnip",
	["nvim-treesitter"] = "nvim-treesitter/nvim-treesitter",
	["nvim-ts-autotag"] = "windwp/nvim-ts-autotag",
	["nvim-tree"] = "nvim-tree/nvim-tree.lua",
	["nvim-web-devicons"] = "nvim-tree/nvim-web-devicons",
	bufferline = "akinsho/bufferline.nvim",
	lualine = "nvim-lualine/lualine.nvim",
	alpha = "goolord/alpha-nvim",
	telescope = "nvim-telescope/telescope.nvim",
	plenary = "nvim-lua/plenary.nvim",
	ibl = "lukas-reineke/indent-blankline.nvim",
	diffview = "sindrets/diffview.nvim",
	["render-markdown"] = "MeanderingProgrammer/render-markdown.nvim",
	["auto-save"] = "Pocco81/auto-save.nvim",
}

-- Modules of plugins this repository retired: requiring one is a bug even if a
-- stale checkout still has it on disk.
local RETIRED = { lint = "mfussenegger/nvim-lint" }

local function declared_repos(specs_path)
	local specs = dofile(specs_path)
	local set = {}
	local function add(v)
		if type(v) == "string" then
			set[v] = true
		elseif type(v) == "table" then
			if type(v[1]) == "string" then
				set[v[1]] = true
			end
			local req = v.requires
			if type(req) == "string" then
				set[req] = true
			elseif type(req) == "table" then
				for _, r in ipairs(req) do
					add(r)
				end
			end
		end
	end
	for _, v in ipairs(specs) do
		add(v)
	end
	return set
end

local function lua_files(root, out)
	out = out or {}
	local h = vim.uv.fs_scandir(root)
	while h do
		local name, kind = vim.uv.fs_scandir_next(h)
		if not name then
			break
		end
		local path = root .. "/" .. name
		if kind == "directory" then
			lua_files(path, out)
		elseif name:sub(-4) == ".lua" then
			out[#out + 1] = path
		end
	end
	return out
end

-- Returns a list of "file: message" violations.
local function scan(files, repos)
	local bad = {}
	for _, file in ipairs(files) do
		for line in io.lines(file) do
			local t = vim.trim(line)
			if t:sub(1, 2) ~= "--" then
				-- require("m"), require "m", and pcall(require, "m")
				local mods = {}
				for mod in line:gmatch("require%s*%(?%s*[\"']([%w_%.%-]+)[\"']") do
					mods[#mods + 1] = mod
				end
				for mod in line:gmatch("require%s*,%s*[\"']([%w_%.%-]+)[\"']") do
					mods[#mods + 1] = mod
				end
				for _, mod in ipairs(mods) do
					local root = mod:match("^[^%.]+")
					if RETIRED[root] then
						bad[#bad + 1] = file .. ": requires the retired module '" .. mod .. "' (" .. RETIRED[root] .. ")"
					elseif PROVIDES[root] and not repos[PROVIDES[root]] then
						bad[#bad + 1] = file .. ": requires '" .. mod .. "' but " .. PROVIDES[root] .. " is not in plugin_specs"
					end
				end
			end
		end
	end
	return bad
end

local cwd = vim.uv.cwd()
local repos = declared_repos(cwd .. "/lua/plugin_specs.lua")

-- 0. The scanner proves itself: a planted dangling require and a retired
--    module are reported (red), a clean file passes (green).
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local function write(name, text)
	local f = assert(io.open(tmp .. "/" .. name, "w"))
	f:write(text)
	f:close()
	return tmp .. "/" .. name
end
local dangling = write("dangling.lua", 'require("telescope")\nrequire("diffview.actions")\n')
local retired = write("retired.lua", 'local ok = pcall(require, "lint")\nrequire("lint").try_lint()\n')
local clean = write("clean.lua", '-- require("lint") in a comment is fine\nrequire("setUp.finder")\nrequire("nvim-tree.api")\n')
local only_telescope = { ["nvim-telescope/telescope.nvim"] = true }
local red1 = scan({ dangling }, only_telescope)
ok(#red1 == 1 and red1[1]:find("diffview", 1, true) ~= nil, "a require of a plugin missing from the specs is reported (red)")
local red2 = scan({ retired }, repos)
ok(#red2 >= 1 and red2[1]:find("retired", 1, true) ~= nil, "a require of a retired module is reported (red)")
ok(#scan({ clean }, repos) == 0, "comments and repository-local modules are not violations (green)")
vim.fn.delete(tmp, "rf")

-- 1 + 2. The real tree.
local files = lua_files(cwd .. "/lua")
files[#files + 1] = cwd .. "/init.lua"
ok(#files > 40, "the scan covers the whole Lua tree (" .. #files .. " files)")
local bad = scan(files, repos)
for _, b in ipairs(bad) do
	print("  " .. b)
end
ok(#bad == 0, "every plugin module required under lua/ and init.lua is provided by a plugin in plugin_specs, and none is retired")

-- 3. init.lua enables the loader before its first require.
local src = assert(io.open(cwd .. "/init.lua")):read("*a")
local loader = src:find("vim.loader.enable", 1, true)
local first_require = src:find("require%s*%(")
ok(loader ~= nil, "init.lua enables vim.loader")
ok(loader ~= nil and first_require ~= nil and loader < first_require, "vim.loader is enabled before the first require")

-- 4. The ecosystem doc stays honest: every plugin in plugin_specs and every
--    server in lsp/server.lua has an entry in docs/PLUGINS.md.
local doc = assert(io.open(cwd .. "/docs/PLUGINS.md")):read("*a")
local missing = {}
for repo in pairs(repos) do
	if not doc:find("`" .. repo .. "`", 1, true) then
		missing[#missing + 1] = repo
	end
end
table.sort(missing)
ok(#missing == 0, "docs/PLUGINS.md documents every plugin in plugin_specs (missing: " .. table.concat(missing, ", ") .. ")")
local server_src = assert(io.open(cwd .. "/lua/lsp/server.lua")):read("*a")
local block = server_src:match("local servers = {(.-)\n}")
local undocumented, n_servers = {}, 0
for name in (block or ""):gmatch('"([%w_]+)"') do
	n_servers = n_servers + 1
	if not doc:find("`" .. name .. "`", 1, true) then
		undocumented[#undocumented + 1] = name
	end
end
ok(n_servers >= 5, "the server list was found in lsp/server.lua (" .. n_servers .. " servers)")
ok(#undocumented == 0, "docs/PLUGINS.md documents every server in lsp/server.lua (missing: " .. table.concat(undocumented, ", ") .. ")")
ok(doc:find("lewis6991/pckr.nvim", 1, true) ~= nil, "pckr, the plugin manager, is documented")

if fails > 0 then
	print(("PLUGIN REFS SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("PLUGIN REFS SMOKE: %d assertions OK"):format(count))
end
