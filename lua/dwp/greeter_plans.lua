-- Greeter plans overview: the dashboard's answer to "what is happening
-- with my plans" before any key is pressed (DESIGN_SPEC § Wireframes 4).
-- Pure data — no alpha session, no UI — so the smoke proves it without
-- booting the dashboard. The alpha wiring lives in setUp/greeter.lua and
-- stays defensive: any failure there omits the section, and the
-- dashboard always boots.
--
-- Cost bounds: one bounded scan at greeter build time (per-plan reads
-- are README/state/manifest sized; the journal is tailed by the rich
-- model, never fully parsed); at most the top `N` plans are rendered.
-- Reader and sidebar are never required here — the gestures defer them
-- to their callbacks.

local plans = require("dwp.plans")

local M = {}

local TOP_N = 3 -- frozen in DESIGN_SPEC § Wireframes 4
local TITLE_CAP = 26
local BAR_CELLS = 8

local function truncate(text, cap)
	if vim.fn.strdisplaywidth(text) <= cap then
		return text
	end
	return vim.fn.strcharpart(text, 0, math.max(1, cap - 1)) .. "…"
end

local function progress_bar(done, total)
	local filled = 0
	if total and total > 0 then
		filled = math.floor((done / total) * BAR_CELLS + 0.5)
	end
	if filled > BAR_CELLS then
		filled = BAR_CELLS
	end
	return string.rep("▰", filled) .. string.rep("▱", BAR_CELLS - filled)
end

--- One overview row: `icon title bar done/total  status-word` — always
--- status-worded (the greeter has no section headers to carry meaning).
function M.plan_line(record)
	local title = truncate(record.title or record.name, TITLE_CAP)
	local pad = string.rep(" ", math.max(1, TITLE_CAP + 2 - vim.fn.strdisplaywidth(title)))
	return string.format(
		"%s %s%s%s %d/%d  %s",
		record.icon or "·",
		title,
		pad,
		progress_bar(record.tasks_done or 0, record.tasks_total or 0),
		record.tasks_done or 0,
		record.tasks_total or 0,
		record.label or "Unknown"
	)
end

--- Build the section data: header, top-N plan rows (records newest
--- first from `scan`), the gesture hint, and the empty-state line. The
--- caller renders; alpha text rows carry no actions, so the wiring
--- makes each row an alpha button whose on_press opens the reader.
function M.build(roots)
	local records = plans.scan(roots)
	local section = {
		header = "Your plans",
		plan_lines = {},
		hint = "Press  SPC P  to browse all plans",
		empty_line = "No plans yet — ask your agent to plan work.",
	}
	for i, record in ipairs(records) do
		if i > TOP_N then
			break
		end
		section.plan_lines[#section.plan_lines + 1] = {
			record = record,
			text = M.plan_line(record),
		}
	end
	return section
end

return M
