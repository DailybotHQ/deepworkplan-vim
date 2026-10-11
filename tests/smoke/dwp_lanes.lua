local lanes = require("dwp.lanes")
local count = 0
local function ok(value, message)
  count = count + 1
  assert(value, message)
end
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local readme = {
  "# Orchestra",
  "",
  "## Lanes",
  "",
  "| Lane | Pane | Account | Repository | Branch |",
  "| --- | --- | --- | --- | --- |",
  "| vim | local:w1:p2 | codex @work | deepworkplan-vim | feat/orchestra |",
  "| pack | local:w1:p3 | claude @work | pack | feat/orchestra |",
  "",
  "## Child DWP Plans",
  "",
  "| # | Repository | Child Plan | Status | Depends On |",
  "| --- | --- | --- | --- | --- |",
  "| 1 | deepworkplan-vim | `PLAN_001_lanes` | ready | pack |",
  "",
  "| Tool | Version |",
  "| --- | --- |",
  "| nvim | 0.12 |",
}
vim.fn.writefile(readme, root .. "/README.md")
vim.fn.writefile(
  { "| Lane | Peer | Status |", "| --- | --- | --- |", "| vim | local:w1:p2 | working |" },
  root .. "/ORCHESTRATOR_MANIFEST.md"
)
local rows = lanes.read(root)
ok(#rows == 2, "manifest and README merge without duplicate repository rows")
ok(
  rows[1].child == "PLAN_001_lanes" and rows[1].status == "working",
  "child registry merged; manifest status wins"
)
ok(rows[1].profile == "codex @work", "README fills account")
ok(
  #lanes.parse("| Tool | Version |\n| --- | --- |\n| nvim | 0.12 |") == 0,
  "unrelated table ignored"
)
ok(#lanes.read(root .. "/missing") == 0, "missing plan harmless")
local snapshot = {
  schema = "herdr-peers/lanes-v1",
  protocol = 1,
  generated_at = "2026-10-11T00:00:00Z",
  lanes = {
    {
      peer = "local:w1:p2",
      state = "blocked",
      agent = "codex",
      profile = "@work",
      screen = "permission",
      open_asks = { { id = "fake-id" } },
      ignored = "must-not-render",
    },
    { peer = "local:w9:p9", state = "done" },
  },
}
ok(lanes.decode(vim.json.encode(snapshot)) ~= nil, "v1 envelope accepted")
ok(
  lanes.decode('{"schema":"herdr-peers/lanes-v2","protocol":1,"lanes":[]}') == nil,
  "future envelope degrades"
)
ok(
  lanes.decode('{"schema":"herdr-peers/lanes-v1","protocol":1,"lanes":{}}') == nil,
  "object lanes rejected"
)
ok(lanes.decode("bad json") == nil, "malformed JSON harmless")
ok(
  lanes.decode('{"schema":"herdr-peers/lanes-v1","protocol":1,"lanes":[]}') ~= nil,
  "empty live list accepted"
)
local record = { path = root, name = "PLAN_001_lanes", title = "Orchestra", artifacts = {} }
local text = table.concat(lanes.lines(record, rows, snapshot), "\n")
ok(text:find("vim · blocked", 1, true), "peer identity overlays live state")
ok(text:find("pack · unavailable", 1, true), "unmatched lane explicitly unavailable")
ok(
  text:find("Screen: permission", 1, true) and text:find("Open asks: 1", 1, true),
  "attention and asks visible"
)
ok(not text:find("must-not-render", 1, true), "unknown JSON fields ignored")
ok(not text:find("local:w9:p9", 1, true), "unrelated runtime peers never become plan lanes")
for _, state in ipairs({
  "working",
  "idle",
  "blocked",
  "done",
  "unknown",
  "no_agent",
  "unreachable",
}) do
  snapshot.lanes[1].state = state
  ok(
    table.concat(lanes.lines(record, rows, snapshot), "\n"):find("vim · " .. state, 1, true),
    "renders state " .. state
  )
end
snapshot.lanes[1].state = "blocked"
local separate =
  lanes.parse("| Lane | Repository |\n| --- | --- |\n| one | shared |\n| two | shared |")
vim.fn.writefile(
  { "| Lane | Repository |", "| --- | --- |", "| one | shared |", "| two | shared |" },
  root .. "/ORCHESTRATOR_MANIFEST.md"
)
ok(#lanes.read(root) == 4, "distinct lanes in the same repository remain separate")
vim.fn.writefile(
  { "| Lane | Peer | Status |", "| --- | --- | --- |", "| vim | local:w1:p2 | working |" },
  root .. "/ORCHESTRATOR_MANIFEST.md"
)
local executable, system = vim.fn.executable, vim.system
vim.fn.executable = function()
  return 0
end
local returned
lanes.fetch(function(data, message)
  returned = message
  ok(data == nil, "missing helper gives nil snapshot")
end)
ok(returned:find("not installed", 1, true), "missing helper explained")
vim.fn.executable = function()
  return 1
end
local pending = {}
vim.system = function(argv, opts, callback)
  ok(
    vim.deep_equal(argv, { "herdr-peers", "lanes", "--json" }),
    "fixed argument vector; no plan interpolation"
  )
  ok(opts.timeout == 3000, "bounded async timeout")
  pending[#pending + 1] = callback
end
local original = table.concat(vim.fn.readfile(root .. "/README.md"), "\n")
local buf = lanes.open(record)
ok(
  vim.bo[buf].buftype == "nofile" and not vim.bo[buf].modifiable and not vim.bo[buf].swapfile,
  "read-only scratch buffer"
)
local maps = {}
for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
  maps[map.lhs] = map
end
ok(
  maps.r and maps.q and maps.i and (maps.i.rhs == "<Nop>" or maps.i.rhs == ""),
  "refresh, close and editing guards wired"
)
maps.r.callback()
pending[2]({ code = 0, stdout = vim.json.encode(snapshot) })
vim.wait(100, function()
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"):find("blocked", 1, true)
end)
pending[1]({ code = 1, stderr = "must-not-render" })
vim.wait(20)
ok(
  table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"):find("vim · blocked", 1, true),
  "stale request cannot overwrite refresh"
)
maps.r.callback()
pending[3]({ code = 124, stdout = "", stderr = "must-not-render" })
vim.wait(100, function()
  return table
    .concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    :find("timed out", 1, true)
end)
ok(
  not table
    .concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    :find("must-not-render", 1, true),
  "stderr never displayed"
)
maps.r.callback()
maps.q.callback()
pending[4]({ code = 0, stdout = vim.json.encode(snapshot) })
vim.wait(20)
ok(not vim.api.nvim_buf_is_valid(buf), "late callback safe after close")
ok(original == table.concat(vim.fn.readfile(root .. "/README.md"), "\n"), "view never writes plan")
-- Entrypoints are real mappings and commands; the index discovers them live.
vim.g.mapleader = " "
require("mapping.navigation")
local found = false
for _, item in ipairs(require("mapping.glossary").collect()) do
  if item.desc == "Orchestra lanes (read-only)" then
    found = true
  end
end
ok(found, "command index discovers orchestra mapping")
ok(vim.api.nvim_get_commands({}).DwpLanes ~= nil, "DwpLanes command registered")
local plans = require("dwp.plans")
local saved_scan, saved_select, saved_open = plans.scan, vim.ui.select, lanes.open
plans.scan = function()
  return { record }
end
local picked
vim.ui.select = function(items, options, callback)
  ok(
    #items == 1 and options.format_item(items[1]) == "Orchestra",
    "picker includes README orchestrator"
  )
  callback(items[1])
end
lanes.open = function(value)
  picked = value
end
vim.cmd("DwpLanes")
ok(picked == record, "command opens selected plan")
plans.scan, vim.ui.select = saved_scan, saved_select
local sidebar = require("dwp.sidebar")
sidebar.open({ vim.uv.cwd() .. "/tests/fixtures/dwp_plans" })
local sidebuf = vim.api.nvim_get_current_buf()
local sidekey
for _, map in ipairs(vim.api.nvim_buf_get_keymap(sidebuf, "n")) do
  if map.lhs == "L" then
    sidekey = map
  end
end
ok(sidekey ~= nil, "plan browser exposes L")
picked = nil
sidekey.callback()
ok(picked and picked.path, "plan browser opens selected record")
sidebar.close()
lanes.open = saved_open
vim.fn.executable, vim.system = executable, system
vim.fn.delete(root, "rf")
print(("LANES SMOKE: %d assertions OK"):format(count))
