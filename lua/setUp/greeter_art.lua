-- Dashboard art for the DWP Vim greeter: the DWP VIM wordmark on the left
-- and the Deep Work Plan lighthouse (the site's hero) on the right.
-- Pure data plus a small composer: no requires, no side effects at load.
local M = {}

M.tagline = "DeepWorkPlan's editor"
M.powered = "powered by Dailybot"

-- Lighthouse: braille engraving with a colour class per cell (data in
-- greeter_lighthouse.lua; classes 0-5 stone, 6-8 beam).
local art = require("setUp.greeter_lighthouse")

-- Rows the dashboard needs below the hero (plans overview + buttons).
local BELOW_HERO = 24

-- The tallest variant that fits `lines` window rows, else the smallest.
local function pick_variant(lines)
	local chosen = art.variants[#art.variants]
	for _, v in ipairs(art.variants) do
		if #v.lines + BELOW_HERO <= lines then
			return v
		end
	end
	return chosen
end

-- Highlight spans of row `r` of a lighthouse variant, byte offsets shifted by `offset`.
local function spans_for_row(variant, r, offset)
	local spans, cols = {}, variant.cols[r]
	local run, start = nil, nil
	local byte = offset
	for i = 1, #cols do
		local ch = cols:sub(i, i)
		local c = ch ~= " " and ch or nil
		if c ~= run then
			if run then
				spans[#spans + 1] = { "DwpArt" .. run, start, byte }
			end
			run, start = c, byte
		end
		byte = byte + 3 -- one braille cell is 3 bytes
	end
	if run then
		spans[#spans + 1] = { "DwpArt" .. run, start, byte }
	end
	return spans
end

-- Pad `s` with spaces to display width `w`.
local function pad(s, w)
	local d = vim.fn.strdisplaywidth(s)
	return d >= w and s or s .. string.rep(" ", w - d)
end

-- Compose the hero: a left block (wordmark, tagline, credit, ship) vertically
-- centred beside the lighthouse. Returns { lines = {...}, hl = {...} } with
-- alpha-style per-line highlight spans ({group, byte_start, byte_end}).
-- Narrow windows stack the left block alone; very narrow ones drop the ship.
function M.compose(columns, lines_avail)
	columns = columns or vim.o.columns
	local variant = pick_variant(lines_avail or vim.o.lines)
	local lighthouse = variant.lines

	-- Left block rows: { text = ..., spans = { {group, from, to}, ... } }.
	local left = {}
	local function text_row(text, group)
		left[#left + 1] = { text = text, spans = text ~= "" and { { group, 0, #text } } or {} }
	end
	for _, l in ipairs(art.logo) do
		text_row(l, "DwpGreeterLogo")
	end
	text_row("", "Normal")
	text_row(M.tagline, "DwpGreeterDim")
	text_row(M.powered, "DwpGreeterAccent")
	text_row("", "Normal")
	for r, l in ipairs(art.ship.lines) do
		left[#left + 1] = { text = l, spans = spans_for_row(art.ship, r, 0) }
	end

	local lw = 0
	for _, row in ipairs(left) do
		lw = math.max(lw, vim.fn.strdisplaywidth(row.text))
	end
	local rw = 0
	for _, l in ipairs(lighthouse) do
		rw = math.max(rw, vim.fn.strdisplaywidth(l))
	end
	local gap = 6
	local side_by_side = columns >= lw + gap + rw + 4

	local lines, hl = {}, {}
	-- alpha tells per-line highlight tables apart by the first line
	-- carrying a span, so no row may be left without one.
	local function push(text, spans)
		if #spans == 0 then
			spans = { { "Normal", 0, 0 } }
		end
		lines[#lines + 1] = text
		hl[#hl + 1] = spans
	end

	if side_by_side then
		local rows = math.max(#left, #lighthouse)
		local top = math.floor((rows - #left) / 2)
		for r = 1, rows do
			local row = left[r - top] or { text = "", spans = {} }
			local ptxt = pad(row.text, lw) .. string.rep(" ", gap)
			local spans = vim.deepcopy(row.spans)
			if lighthouse[r] then
				for _, sp in ipairs(spans_for_row(variant, r, #ptxt)) do
					spans[#spans + 1] = sp
				end
			end
			push(ptxt .. (lighthouse[r] or ""), spans)
		end
	else
		local keep = columns >= lw and #left or #art.logo + 3
		for i = 1, keep do
			push(left[i].text, left[i].spans)
		end
	end
	return { lines = lines, hl = hl }
end

-- Brand colours: cream ink, oxblood beam, slate sea. Fixed hexes so the
-- hero reads the same under every editor colour scheme.
function M.define_highlights()
	local function hi(name, opts)
		vim.api.nvim_set_hl(0, name, opts)
	end
	hi("DwpGreeterLogo", { fg = "#ece4d3", bold = true })
	hi("DwpGreeterDim", { fg = "#a39c8c", italic = true })
	hi("DwpGreeterAccent", { fg = "#d0564f" })
	for i, hex in ipairs(art.palette) do
		hi("DwpArt" .. (i - 1), { fg = hex })
	end
end

return M
