-- Addon surface smoke: addon/surface.json is the machine-readable contract
-- the DeepWorkPlan `vim` addon reads instead of guessing. This proves the
-- file parses, carries interface 1, never lags the latest release tag, and
-- that every claim it makes is true of THIS tree: the installer checksum,
-- the marker name install.sh writes, the identity files, the files the
-- plan reader reads, and each feature's keys and commands. Run via
-- tests/smoke/run.sh.

local repo = vim.uv.cwd()

local count, fails = 0, 0

local function ok(cond, msg)
	count = count + 1
	if not cond then
		fails = fails + 1
		print("FAIL: " .. msg)
	end
end

local function read(rel)
	local handle = io.open(repo .. "/" .. rel, "rb")
	if not handle then
		return nil
	end
	local content = handle:read("*a")
	handle:close()
	return content
end

-- "v1.2.3" / "v1.2.3-beta.1" -> { 1, 2, 3 } (pre-release ignored), or nil.
local function semver(tag)
	if type(tag) ~= "string" then
		return nil
	end
	local a, b, c = tag:match("^v(%d+)%.(%d+)%.(%d+)")
	if not a then
		return nil
	end
	return { tonumber(a), tonumber(b), tonumber(c) }
end

local function cmp(x, y)
	for i = 1, 3 do
		if x[i] ~= y[i] then
			return x[i] < y[i] and -1 or 1
		end
	end
	return 0
end

-- Concatenated sources of a directory's *.lua files (plain-text search).
local function sources(dir)
	local parts = {}
	for _, path in ipairs(vim.fn.globpath(repo .. "/" .. dir, "**/*.lua", false, true)) do
		local handle = io.open(path, "r")
		if handle then
			parts[#parts + 1] = handle:read("*a")
			handle:close()
		end
	end
	return table.concat(parts, "\n")
end

-- 1. Parses, identity, interface.
local raw = read("addon/surface.json")
ok(raw ~= nil, "addon/surface.json exists")
local parsed, s = pcall(vim.json.decode, raw or "")
ok(parsed and type(s) == "table", "addon/surface.json parses as a JSON object")
if not (parsed and type(s) == "table") then
	print(("ADDON SURFACE SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
	return
end
ok(s.name == "deepworkplan-vim", "name is deepworkplan-vim")
ok(s.interface == 1, "interface is the integer 1 (a breaking change bumps it and the major)")
local version = semver(s.version)
ok(version ~= nil, "version is a vX.Y.Z tag name (got " .. tostring(s.version) .. ")")
ok(s.license == "GPL-3.0", "license is GPL-3.0")

-- 2. The surface never lags the release: version >= the newest vX.Y.Z
--    tag, and equal to the tag when HEAD is exactly a release.
local tags = vim.fn.systemlist({ "git", "-C", repo, "tag", "-l", "v*" })
local newest
if vim.v.shell_error == 0 then
	for _, tag in ipairs(tags) do
		local v = semver(tag)
		if v and (newest == nil or cmp(v, newest) > 0) then
			newest = v
		end
	end
end
-- Each check below is always one assertion (vacuously true when its input
-- is absent: no tags yet, an untagged HEAD) so the count never drifts.
ok(
	newest == nil or (version ~= nil and cmp(version, newest) >= 0),
	("surface version %s is not older than the newest tag %s"):format(
		tostring(s.version),
		newest and ("v%d.%d.%d"):format(newest[1], newest[2], newest[3]) or "(none)"
	)
)
local exact = vim.fn.systemlist({ "git", "-C", repo, "tag", "--points-at", "HEAD", "-l", "v*" })
if vim.v.shell_error ~= 0 then
	exact = {}
end
ok(#exact == 0 or vim.tbl_contains(exact, s.version), "at a tagged HEAD (" .. table.concat(exact, ",") .. ") the surface names that tag")
local changelog = read("CHANGELOG.md")
local top = changelog and changelog:match("\n## %[?(v%d+%.%d+%.%d+[%w%.%-]*)%]?")
ok(changelog == nil or top == s.version, "CHANGELOG's newest release heading equals the surface version (got " .. tostring(top) .. ")")

-- 3. Detection describes what the install actually lays down.
local detect = s.detect or {}
ok(type(detect.config_dir) == "table" and detect.config_dir.unix ~= nil, "detect.config_dir.unix is declared")
ok(detect.read_only == true, "detection is declared read-only")
ok(
	vim.deep_equal(detect.identity_files, { "install.lua", "lua/plugins.lua" }),
	"identity files are the install.lua + lua/plugins.lua pair (install.sh is_ours, delete.lua)"
)
for _, rel in ipairs(detect.identity_files or {}) do
	ok(read(rel) ~= nil, "identity file exists in the tree: " .. rel)
end
ok(detect.surface_file == "addon/surface.json", "surface_file points at this file")
local installer = read("install.sh") or ""
local marker_path = type(detect.marker) == "table" and detect.marker.path or ""
local marker_name = marker_path:match("([^/]+)$") or ""
ok(marker_name ~= "" and installer:find(marker_name, 1, true) ~= nil, "the marker is the one install.sh writes: " .. marker_name)
ok(type(detect.legacy_marker) == "table" and detect.legacy_marker.path ~= nil, "the pre-v0.4.0 legacy marker is named")
for _, state in ipairs({ "installed", "installed_without_surface", "existing_config", "absent" }) do
	ok(type((detect.states or {})[state]) == "string", "detection state documented: " .. state)
end

-- 4. Install: pinned to this version, checksum true of this tree, and no
--    step spells a fetch piped to a shell.
local install = s.install or {}
ok(install.ref == s.version, "install.ref pins this version")
ok(install.ref_env == "DWP_VIM_REF", "the ref variable is install.sh's DWP_VIM_REF")
ok(installer:find("DWP_VIM_REF", 1, true) ~= nil, "install.sh honors DWP_VIM_REF")
local script = install.script or {}
ok(type(script.url) == "string" and script.url:find("/" .. tostring(s.version) .. "/install.sh", 1, true) ~= nil, "script.url is tag-pinned")
ok(script.sha256 == vim.fn.sha256(installer), "script.sha256 equals sha256(install.sh) of this tree")
local pipe_free = true
for _, list in ipairs({ install.steps or {}, install.manual or {}, install.windows or {} }) do
	for _, step in ipairs(list) do
		-- a pipe followed, anywhere later, by a shell word: | bash, | sh,
		-- | zsh, | sudo bash, | VAR=x bash ...
		if step:find("|[^|]*%f[%w]b?a?z?sh%f[%W]") or step:find("|[^|]*%f[%w]sh$") then
			pipe_free = false
		end
	end
end
ok(pipe_free, "no install step pipes a download into a shell")
ok(#(install.steps or {}) >= 3, "download / verify / run are separate steps")
ok(type(install.consent) == "table" and install.consent.backup_dir == "~/.config/previous-deepworkplan-vim", "consent and backup dir declared")
local readme = read("README.md") or ""
ok(readme:find("/" .. tostring(s.version) .. "/install.sh", 1, true) ~= nil, "README pins the install line to this version")
ok(read("delete.lua") ~= nil and tostring(install.uninstall):find("delete.lua", 1, true) ~= nil, "uninstall names delete.lua")

-- 5. plan_reader: read-only, and every file it claims is one lua/dwp reads.
local reader = (s.capabilities or {}).plan_reader or {}
ok(reader.read_only == true and type(reader.writes) == "table" and #reader.writes == 0, "plan_reader is read-only with no writes")
for _, kind in ipairs({ "manifest", "journal", "state", "readme_checkboxes", "contract" }) do
	ok(vim.tbl_contains(reader.reads or {}, kind), "plan_reader reads " .. kind)
end
local dwp_src = sources("lua/dwp")
for _, file in ipairs(reader.files or {}) do
	ok(dwp_src:find('"' .. file .. '"', 1, true) ~= nil or dwp_src:find("/" .. file, 1, true) ~= nil, "lua/dwp reads " .. file)
end
ok(#(reader.files or {}) == 5, "plan_reader lists five files")

-- 6. Features: the five pack claims, each real in this tree.
local mapping_src = sources("lua/mapping")
local lua_src = sources("lua")
local ids = {}
for _, feature in ipairs(s.features or {}) do
	ids[#ids + 1] = feature.id
	local since = semver(feature.since)
	ok(since ~= nil and version ~= nil and cmp(since, version) <= 0, feature.id .. ": since is a tag no newer than the surface")
	for _, lhs in ipairs(feature.keys or {}) do
		ok(mapping_src:find('"' .. lhs .. '"', 1, true) ~= nil, feature.id .. ": key " .. lhs .. " is mapped in lua/mapping")
	end
	for _, name in ipairs(feature.commands or {}) do
		ok(lua_src:find('nvim_create_user_command("' .. name .. '"', 1, true) ~= nil, feature.id .. ": command :" .. name .. " is defined")
	end
end
ok(
	vim.deep_equal(ids, { "command_index", "vscode_gestures", "plan_browser", "markdown_viewer", "one_line_installer" }),
	"features are exactly F1-F5, in order"
)
ok(read("install.sh") ~= nil, "one_line_installer: install.sh exists")

if fails > 0 then
	print(("ADDON SURFACE SMOKE: %d FAILED of %d assertions"):format(fails, count))
	vim.cmd("cquit 1")
else
	print(("ADDON SURFACE SMOKE: %d assertions OK"):format(count))
end
