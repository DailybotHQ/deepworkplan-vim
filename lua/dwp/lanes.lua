-- Read-only orchestra view. Disk is authoritative for lane membership;
-- herdr-peers contributes only an optional, point-in-time runtime snapshot.
local L = {}

local function clean(value)
  return type(value) == "string" and value:gsub("[%c]", " "):sub(1, 500) or ""
end

local function cell(value)
  return vim.trim(value):gsub("`", ""):gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
end

local aliases = {
  lane = "lane",
  pane = "peer",
  peer = "peer",
  address = "peer",
  account = "profile",
  profile = "profile",
  repository = "repository",
  repo = "repository",
  branch = "branch",
  status = "status",
  state = "status",
  ["child plan"] = "child",
  ["child dwp"] = "child",
  ["plan name"] = "child",
  ["depends on"] = "depends",
  dependencies = "depends",
}

local function cells(line)
  local out = {}
  for value in line:gmatch("|([^|]*)") do
    out[#out + 1] = cell(value)
  end
  return out
end

--- Parse lane and child registry tables; ignore unrelated Markdown tables.
function L.parse(text)
  local out, headers = {}, nil
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^%s*|") then
      local values = cells(line)
      if values[1] and values[1]:match("^:?[%-]+:?") then
        -- Markdown separator.
      else
        local next_headers, relevant = {}, false
        for i, value in ipairs(values) do
          next_headers[i] = aliases[value:lower()] or false
          relevant = relevant or next_headers[i] == "lane" or next_headers[i] == "child"
        end
        if relevant then
          headers = next_headers
        elseif headers then
          local row = {}
          for i, key in ipairs(headers) do
            if key and values[i] and values[i] ~= "" then
              row[key] = values[i]
            end
          end
          if row.lane or row.child or row.repository then
            out[#out + 1] = row
          end
        else
          headers = nil
        end
      end
    else
      headers = nil
    end
  end
  return out
end

--- Manifest fields take precedence; README fills gaps and adds missing lanes.
function L.read(path)
  local out = {}
  for _, filename in ipairs({ "ORCHESTRATOR_MANIFEST.md", "README.md" }) do
    local handle = io.open(path .. "/" .. filename, "r")
    if handle then
      local rows = L.parse(handle:read("*a"))
      handle:close()
      for _, row in ipairs(rows) do
        local match
        for _, previous in ipairs(out) do
          if
            (row.lane and row.lane == previous.lane)
            or (row.repository and row.repository == previous.repository and not (row.lane and previous.lane and row.lane ~= previous.lane))
            or (row.child and row.child == previous.child)
          then
            match = previous
            break
          end
        end
        if match then
          for key, value in pairs(row) do
            if not match[key] then
              match[key] = value
            end
          end
        else
          out[#out + 1] = row
        end
      end
    end
  end
  return out
end

--- Strict version envelope; unknown fields are ignored by the renderer.
function L.decode(raw)
  local ok, snapshot = pcall(vim.json.decode, raw)
  if
    not ok
    or type(snapshot) ~= "table"
    or snapshot.schema ~= "herdr-peers/lanes-v1"
    or snapshot.protocol ~= 1
    or type(snapshot.lanes) ~= "table"
    or not vim.islist(snapshot.lanes)
  then
    return nil
  end
  return snapshot
end

local states = {
  working = true,
  idle = true,
  blocked = true,
  done = true,
  unknown = true,
  no_agent = true,
  unreachable = true,
}

function L.lines(record, rows, snapshot, message)
  local out = {
    "Orchestra — " .. clean(record.title or record.name),
    "",
    message or "Live status unavailable; showing recorded plan lanes.",
    "",
  }
  local peers = {}
  for _, live in ipairs(snapshot and snapshot.lanes or {}) do
    if type(live) == "table" and type(live.peer) == "string" then
      peers[live.peer] = live
    end
  end
  if #rows == 0 then
    out[#out + 1] = "No lane or child-plan table found in this plan."
  end
  for _, row in ipairs(rows) do
    local live = peers[row.peer]
    local state = live and states[live.state] and live.state or "unavailable"
    out[#out + 1] = clean(row.lane or row.repository or row.child) .. " · " .. state
    for _, field in ipairs({
      { "Repository", row.repository },
      { "Peer", row.peer },
      { "Account", row.profile },
      { "Branch", row.branch },
      { "Child plan", row.child },
      { "Recorded status", row.status },
      { "Depends on", row.depends },
    }) do
      if field[2] then
        out[#out + 1] = "  " .. field[1] .. ": " .. clean(field[2])
      end
    end
    if live then
      out[#out + 1] = "  Agent: " .. clean(live.agent) .. " " .. clean(live.profile)
      if type(live.screen) == "string" and live.screen ~= "none" then
        out[#out + 1] = "  Screen: " .. clean(live.screen)
      end
      out[#out + 1] = "  Open asks: " .. (type(live.open_asks) == "table" and #live.open_asks or 0)
    end
    out[#out + 1] = ""
  end
  out[#out + 1] = "r refresh · q / Esc close · read-only"
  return out
end

--- Only invokes the fixed read-only command; no plan text becomes an argument.
function L.fetch(callback)
  if vim.fn.executable("herdr-peers") ~= 1 then
    callback(nil, "Live status unavailable: herdr-peers is not installed.")
    return
  end
  local ok = pcall(
    vim.system,
    { "herdr-peers", "lanes", "--json" },
    { text = true, timeout = 3000 },
    function(result)
      vim.schedule(function()
        local snapshot = result.code == 0 and L.decode(result.stdout or "") or nil
        callback(
          snapshot,
          snapshot
              and ("Live snapshot: " .. clean(snapshot.generated_at) .. " · refresh to update")
            or "Live status unavailable: command failed, timed out or returned unsupported JSON."
        )
      end)
    end
  )
  if not ok then
    callback(nil, "Live status unavailable: command could not start.")
  end
end

function L.open(record)
  if not record or not record.path then
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "dwp-lanes"
  -- A separate window keeps the plan browser and its reader intact.
  vim.cmd("botright split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.wo[win].wrap = true
  vim.wo[win].list = false
  local generation = 0
  local function render(rows, snapshot, message)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, L.lines(record, rows, snapshot, message))
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
  end
  local function refresh()
    generation = generation + 1
    local current = generation
    local rows = L.read(record.path)
    render(rows, nil, "Checking live status…")
    L.fetch(function(snapshot, message)
      if current == generation then
        render(rows, snapshot, message)
      end
    end)
  end
  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set("n", "r", refresh, opts)
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then
        if #vim.api.nvim_list_wins() == 1 then
          vim.api.nvim_buf_delete(buf, { force = true })
        else
          vim.api.nvim_win_close(win, true)
        end
      end
    end, opts)
  end
  for _, key in ipairs({
    "i",
    "I",
    "a",
    "A",
    "o",
    "O",
    "c",
    "C",
    "s",
    "S",
    "x",
    "X",
    "d",
    "D",
    "p",
    "P",
    "R",
    "u",
    "U",
    "<C-r>",
    "J",
    "gi",
  }) do
    vim.keymap.set("n", key, "<Nop>", opts)
  end
  refresh()
  return buf
end

function L.pick()
  local records = {}
  for _, record in ipairs(require("dwp.plans").scan()) do
    if record.artifacts["ORCHESTRATOR_MANIFEST.md"] or #L.read(record.path) > 0 then
      records[#records + 1] = record
    end
  end
  if #records == 0 then
    vim.notify("No orchestrator plans found under .dwp/plans.", vim.log.levels.INFO)
  else
    vim.ui.select(records, {
      prompt = "Orchestrator plan",
      format_item = function(record)
        return record.title or record.name
      end,
    }, function(record)
      if record then
        L.open(record)
      end
    end)
  end
end

return L
