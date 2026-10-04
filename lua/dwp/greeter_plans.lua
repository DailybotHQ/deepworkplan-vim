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

-- Display-cell-aware cut (CJK titles count two cells per character);
-- a character-count cut overflowed the line (render harness, F-12), and
-- a BYTE-wise walk under-fills it: strdisplaywidth of a lone invalid
-- byte is 4, so each CJK byte counted 4 cells and titles collapsed to a
-- fraction of the cap (D-4, consistency harness). Walk whole UTF-8
-- sequences instead.
local function chars(text)
	local i = 1
	return function()
		if i > #text then
			return nil
		end
		local b = text:byte(i)
		local len = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
		local ch = text:sub(i, i + len - 1)
		i = i + len
		return ch
	end
end

local function truncate(text, cap)
	if vim.fn.strdisplaywidth(text) <= cap then
		return text
	end
	local out, used = "", 0
	for ch in chars(text) do
		local cw = vim.fn.strdisplaywidth(ch)
		if used + cw > cap - 1 then
			break
		end
		out = out .. ch
		used = used + cw
	end
	return out .. "…"
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

--- One overview row: `icon title bar done/total · percent  status-word`
--- — always status-worded (the greeter has no section headers to carry
--- meaning). The percent is the number a non-technical reader parses
--- without dividing (UX_AUDIT F-01).
function M.plan_line(record)
	local title = truncate(record.title or record.name, TITLE_CAP)
	local pad = string.rep(" ", math.max(1, TITLE_CAP + 2 - vim.fn.strdisplaywidth(title)))
	return string.format(
		"%s %s%s%s %d/%d · %d%%  %s",
		record.icon or "·",
		title,
		pad,
		progress_bar(record.tasks_done or 0, record.tasks_total or 0),
		record.tasks_done or 0,
		record.tasks_total or 0,
		record.percent or 0,
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
		-- Terminals have no hover: the click affordance of the statusline
		-- segment is taught once, here (UX_AUDIT F-04).
		hint_click = "The bar at the bottom shows your active plan — click it anytime",
		-- The empty state says WHERE plans are searched, so opening the
		-- editor outside a project reads as a location fact, not as
		-- "my plans vanished" (UX_AUDIT F-02).
		empty_line = "No plans yet — ask your agent to plan work (open the editor in your project folder).",
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
