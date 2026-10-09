-- Plugin commit pins. The lock is pckr/lockfile.lua at the config root —
-- pckr's own lockfile path and format, one line per repository:
--   ["https://github.com/<owner>/<repo>"] = { commit = "<40-hex sha>" },
-- It pins every plugin in lua/plugin_specs.lua (their requires included)
-- and pckr itself. Pure functions, no side effects: lua/plugins.lua
-- applies them, tests/smoke/plugin_lock.lua proves the lock covers the
-- specs, scripts/update-plugin-lock.sh rewrites the file.

local M = {}

M.PCKR_URL = "https://github.com/lewis6991/pckr.nvim"

-- pckr's plugin.url: its default_url_format without the trailing .git (the
-- lockfile key pckr itself writes).
function M.url(name)
  return "https://github.com/" .. name
end

-- The lock table at `path`, or {} when the file is missing or invalid.
function M.read(path)
  local ok, lock = pcall(dofile, path)
  if ok and type(lock) == "table" then
    return lock
  end
  return {}
end

-- The pinned commit for `url` (a full 40-hex sha), or nil.
function M.commit(lock, url)
  local entry = lock[url]
  local sha = type(entry) == "table" and entry.commit or nil
  if type(sha) == "string" and #sha == 40 and sha:match("^%x+$") then
    return sha
  end
  return nil
end

-- A copy of one spec with `commit` set on it and on each of its requires.
-- A spec with no lock entry gets no commit (pckr then follows the branch
-- tip) — the smoke test forbids that state in the tracked tree.
function M.pin(spec, lock)
  if type(spec) == "string" then
    return { spec, commit = M.commit(lock, M.url(spec)) }
  end
  local out = {}
  for k, v in pairs(spec) do
    out[k] = v
  end
  out.commit = M.commit(lock, M.url(spec[1]))
  if type(spec.requires) == "string" then
    out.requires = { M.pin(spec.requires, lock) }
  elseif type(spec.requires) == "table" then
    out.requires = {}
    for i, dep in ipairs(spec.requires) do
      out.requires[i] = M.pin(dep, lock)
    end
  end
  return out
end

-- The specs pckr receives: each repository's pin is set on ONE occurrence.
-- A spec carrying `commit` is "non-simple" to pckr, and pckr warns (on every
-- start) about a repository given by two non-simple specs — so a repository
-- named several times (a shared dependency) is pinned where it is a table if
-- it is one anywhere, else at its first occurrence; the other occurrences
-- stay as written. pckr keeps the non-simple spec, so the pin holds.
function M.pin_all(specs, lock)
  -- Occurrences are numbered in walk order (a string spec repeats by value,
  -- so identity cannot tell its occurrences apart).
  local primary, is_tbl, n = {}, {}, 0 -- url -> chosen occurrence number
  local function choose(spec)
    n = n + 1
    local is_table = type(spec) == "table"
    local url = M.url(is_table and spec[1] or spec)
    if primary[url] == nil or (is_table and not is_tbl[url]) then
      primary[url], is_tbl[url] = n, is_table
    end
    local req = is_table and spec.requires or nil
    if type(req) == "string" then
      choose(req)
    elseif type(req) == "table" then
      for _, dep in ipairs(req) do
        choose(dep)
      end
    end
  end
  for _, spec in ipairs(specs) do
    choose(spec)
  end

  n = 0
  local function apply(spec)
    n = n + 1
    local is_table = type(spec) == "table"
    local url = M.url(is_table and spec[1] or spec)
    local mine = primary[url] == n
    if not is_table and not mine then
      return spec
    end
    local out = is_table and {} or { spec }
    if is_table then
      for k, v in pairs(spec) do
        out[k] = v
      end
    end
    if mine then
      out.commit = M.commit(lock, url)
    end
    local req = is_table and spec.requires or nil
    if type(req) == "string" then
      out.requires = { apply(req) }
    elseif type(req) == "table" then
      out.requires = {}
      for i, dep in ipairs(req) do
        out.requires[i] = apply(dep)
      end
    end
    return out
  end
  local out = {}
  for i, spec in ipairs(specs) do
    out[i] = apply(spec)
  end
  return out
end

-- Every repository URL the specs name (requires included), sorted.
function M.urls(specs)
  local seen, list = {}, {}
  local function walk(spec)
    local name = type(spec) == "string" and spec or spec[1]
    local url = M.url(name)
    if not seen[url] then
      seen[url] = true
      list[#list + 1] = url
    end
    local req = type(spec) == "table" and spec.requires or nil
    if type(req) == "string" then
      walk(req)
    elseif type(req) == "table" then
      for _, dep in ipairs(req) do
        walk(dep)
      end
    end
  end
  for _, spec in ipairs(specs) do
    walk(spec)
  end
  table.sort(list)
  return list
end

-- Coverage of `lock` over `specs` + pckr: URLs with no valid pin, and
-- lock entries nothing declares. Both lists empty = the lock is complete.
function M.coverage(specs, lock)
  local wanted = M.urls(specs)
  wanted[#wanted + 1] = M.PCKR_URL
  local missing, stale, known = {}, {}, {}
  for _, url in ipairs(wanted) do
    known[url] = true
    if not M.commit(lock, url) then
      missing[#missing + 1] = url
    end
  end
  for url in pairs(lock) do
    if not known[url] then
      stale[#stale + 1] = url
    end
  end
  table.sort(stale)
  return missing, stale
end

return M
