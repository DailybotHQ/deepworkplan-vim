-- User configuration: where the two sidebars sit and how wide they are.
--
-- Three layers, later wins, each checked key by key:
--   1. built-in defaults (below);
--   2. `dwpvim.json` in the editor's own directory (the repository, shipped
--      with the defaults — edit it to change them for every project);
--   3. `.dwpvim.json` in the directory Neovim was started in (one project).
--
-- A missing file is fine; a malformed file, an unknown key or an invalid value
-- is ignored and reported (`:DwpConfig`), never fatal. Read once at startup:
-- one small JSON decode, no plugin. `lua/dwp` must stay self-contained, so the
-- plans sidebar reads `vim.g.dwp_plans_side` / `vim.g.dwp_plans_width`, which
-- `apply()` sets; it never requires this module.
local M = {}

local DEFAULTS = {
	tree = { side = "left", width = 40 },
	plans = { side = "left", width = 48 },
}

local MIN_WIDTH, MAX_WIDTH = 20, 120

-- key -> validator returning the cleaned value, or nil and a reason.
local RULES = {
	side = function(v)
		if v == "left" or v == "right" then
			return v
		end
		return nil, 'must be "left" or "right"'
	end,
	width = function(v)
		if type(v) == "number" and v == math.floor(v) and v >= MIN_WIDTH and v <= MAX_WIDTH then
			return v
		end
		return nil, "must be a whole number from " .. MIN_WIDTH .. " to " .. MAX_WIDTH
	end,
}

local function copy_defaults()
	return vim.deepcopy(DEFAULTS)
end

-- Returns the decoded table, or nil plus a problem message (nil, nil when the
-- file does not exist).
local function read_json(path)
	local f = io.open(path, "r")
	if not f then
		return nil, nil
	end
	local text = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, text)
	if not ok then
		return nil, path .. ": invalid JSON (" .. tostring(data):gsub("\n.*", "") .. ")"
	end
	if type(data) ~= "table" or vim.islist(data) then
		return nil, path .. ": the top level must be an object"
	end
	return data, nil
end

--- Merge the three layers. `config_dir` and `project_dir` default to the
--- config directory and the current directory; tests pass temporary ones.
--- Returns { values = {...}, sources = { ["tree.side"] = "default"|path },
---           problems = { "..." } }.
function M.load(config_dir, project_dir)
	config_dir = config_dir or vim.fn.stdpath("config")
	project_dir = project_dir or vim.uv.cwd()
	local state = { values = copy_defaults(), sources = {}, problems = {} }
	for section, keys in pairs(DEFAULTS) do
		for key in pairs(keys) do
			state.sources[section .. "." .. key] = "default"
		end
	end
	local layers = { config_dir .. "/dwpvim.json", project_dir .. "/.dwpvim.json" }
	for _, path in ipairs(layers) do
		local data, problem = read_json(path)
		if problem then
			state.problems[#state.problems + 1] = problem
		elseif data then
			for section, body in pairs(data) do
				if section:sub(1, 1) == "$" or section:sub(1, 1) == "_" then
					-- "$comment" and friends: documentation inside the file.
				elseif not DEFAULTS[section] then
					state.problems[#state.problems + 1] = path .. ': unknown section "' .. section .. '"'
				elseif type(body) ~= "table" or vim.islist(body) then
					state.problems[#state.problems + 1] = path .. ": " .. section .. " must be an object"
				else
					for key, value in pairs(body) do
						local rule = RULES[key]
						if DEFAULTS[section][key] == nil then
							state.problems[#state.problems + 1] = path .. ": unknown key " .. section .. "." .. key
						else
							local cleaned, why = rule(value)
							if cleaned == nil then
								state.problems[#state.problems + 1] = path
									.. ": "
									.. section
									.. "."
									.. key
									.. " "
									.. why
									.. " (got "
									.. vim.inspect(value):gsub("\n", " ")
									.. "); ignored"
							else
								state.values[section][key] = cleaned
								state.sources[section .. "." .. key] = path
							end
						end
					end
				end
			end
		end
	end
	return state
end

local state

local function current()
	if not state then
		state = M.load()
	end
	return state
end

--- Effective value of "section.key", e.g. get("tree.side").
function M.get(path)
	local section, key = path:match("^(%w+)%.(%w+)$")
	local v = section and current().values[section] and current().values[section][key]
	if v == nil then
		v = section and DEFAULTS[section] and DEFAULTS[section][key]
	end
	return v
end

function M.sources()
	return current().sources
end

function M.problems()
	return current().problems
end

--- The effective configuration as lines of text (what :DwpConfig shows).
function M.describe(st)
	st = st or current()
	local lines = { "DeepWorkPlan Vim configuration", "" }
	local names = {}
	for section, keys in pairs(st.values) do
		for key in pairs(keys) do
			names[#names + 1] = section .. "." .. key
		end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local section, key = name:match("^(%w+)%.(%w+)$")
		local src = st.sources[name]
		lines[#lines + 1] = string.format("  %-14s %-6s  %s", name, tostring(st.values[section][key]), src == "default" and "(default)" or src)
	end
	lines[#lines + 1] = ""
	if #st.problems == 0 then
		lines[#lines + 1] = "No problems."
	else
		lines[#lines + 1] = "Problems (these settings were ignored):"
		for _, p in ipairs(st.problems) do
			lines[#lines + 1] = "  - " .. p
		end
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Edit dwpvim.json in the editor's directory, or add .dwpvim.json to a project."
	return lines
end

--- Load, publish the plans-sidebar settings for lua/dwp, define :DwpConfig and
--- report problems once. Safe to call more than once.
function M.apply(config_dir, project_dir)
	state = M.load(config_dir, project_dir)
	vim.g.dwp_plans_side = state.values.plans.side
	vim.g.dwp_plans_width = state.values.plans.width
	vim.api.nvim_create_user_command("DwpConfig", function()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.describe())
		vim.bo[buf].modifiable = false
		vim.bo[buf].bufhidden = "wipe"
		vim.cmd("botright 14split")
		vim.api.nvim_win_set_buf(0, buf)
		vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf, silent = true })
	end, { desc = "Show the effective editor configuration and where each value came from" })
	if #state.problems > 0 then
		vim.schedule(function()
			vim.notify(
				"DeepWorkPlan Vim: " .. #state.problems .. " setting(s) ignored — see :DwpConfig",
				vim.log.levels.WARN
			)
		end)
	end
	return state
end

return M
