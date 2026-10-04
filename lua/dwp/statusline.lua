-- Statusline segment: the always-present ambient answer to "what is
-- the agent working on and how far along" (DESIGN_SPEC § Wireframes 3).
-- One click region that opens the sidebar.
--
-- Hot-path contract: `segment()` never touches the filesystem. It reads
-- a module-local cache; the cache is repopulated only by explicit
-- events (FocusGained, BufEnter, CursorHold/CursorHoldI — debounced,
-- cancel-and-rearm) and the first call after the module loads. The
-- smoke proves it with a scan counter: repeated renders, one scan.
--
-- Recorded deviation from the spec's "≥ 2 s idle timer": CursorHold and
-- CursorHoldI already fire only after the editor goes idle (updatetime),
-- giving the same idle coverage vim-natively — a repeating timer would
-- scan forever even while the editor is busiest, which is the hot-path
-- bug this module exists to avoid.

local plans = require("dwp.plans")

local M = {}

local TITLE_CAP = 20 -- frozen in DESIGN_SPEC § Information architecture
local BAR_CELLS = 6
local CLICK_FN = "v:lua.DwpPlansClick"

local st = {
	record = nil, -- cached active plan (scan record) or nil
	roots = nil, -- test override; nil means default roots
	initialized = false,
	scans = 0, -- the no-per-redraw-scan proof, asserted by the smoke
	timer = nil,
	events = nil, -- augroup id, so setup is idempotent
}

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

local function schedule_refresh()
	-- Debounced cancel-and-rearm: a burst of events costs one scan.
	if st.timer then
		st.timer:stop()
		st.timer = nil
	end
	st.timer = vim.defer_fn(function()
		st.timer = nil
		M.refresh()
	end, 500)
end

local function ensure_events()
	if st.events then
		return
	end
	st.events = vim.api.nvim_create_augroup("DwpStatusline", { clear = true })
	vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
		group = st.events,
		callback = schedule_refresh,
	})
end

--- Rescan the roots and pick the active plan: the most recent in-flight
--- plan (Working or Needs attention); if none is in flight, the most
--- recently modified plan; if there are no plans at all, nil. `scan()`
--- returns newest-first, so "first match" is "most recent" by contract.
function M.refresh(roots)
	st.roots = roots or st.roots
	ensure_events()
	st.scans = st.scans + 1
	local records = plans.scan(st.roots)
	local active
	for _, record in ipairs(records) do
		if record.label == "Working" or record.label == "Needs attention" then
			active = record
			break
		end
	end
	st.record = active or records[1]
	st.initialized = true
	return st.record
end

--- The display string for the statusline: click-wrapped
--- `icon title bar done/total`, or "" when no plan is active (lualine's
--- cond hides the component entirely). Zero filesystem work in here.
--- An explicit `record` overrides the cache (the smoke's hostile-title
--- proof uses it); the lualine wiring passes nothing.
function M.segment(record)
	if not st.initialized then
		M.refresh()
		ensure_events()
	end
	record = record or st.record
	if not record then
		return ""
	end
	local text = string.format(
		"%s %s %s %d/%d",
		record.icon or "·",
		truncate(record.title or record.name, TITLE_CAP),
		progress_bar(record.tasks_done or 0, record.tasks_total or 0),
		record.tasks_done or 0,
		record.tasks_total or 0
	)
	-- Click region: `%@fn@…%X` is the complete form — a bare trailing @
	-- renders as a stray character. The display text is statusline
	-- format input, so every literal % is doubled or a plan title like
	-- "50% done" would break the line and "%{expr}" would *evaluate* on
	-- every draw. (Known cosmetic bound: a literal @ in a title ends the
	-- click region early; titles are truncated to 20 chars and render
	-- fine, only the clickable span shortens.)
	local safe = text:gsub("%%", "%%%%")
	return "%@" .. CLICK_FN .. "@" .. safe .. "%X"
end

--- Cache predicate for lualine's cond (also pure): true when there is
--- an active plan to show.
function M.has_plan()
	if not st.initialized then
		M.refresh()
		ensure_events()
	end
	return st.record ~= nil
end

--- Click handler: the whole segment toggles the sidebar. Exposed as a
--- global because statusline click expressions only address globals.
_G.DwpPlansClick = function()
	require("dwp.sidebar").toggle()
end

--- Test hooks: the cached record and the scan counter (asserted by the
--- smoke: repeated renders must not add scans).
function M.cached()
	return st.record
end

function M.scan_count()
	return st.scans
end

return M
