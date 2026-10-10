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

-- Compose the hero: the wordmark block (DWP mark with VIM on its baseline,
-- tagline, credit) vertically centred beside the scene (the lighthouse with
-- a ship sailing at its foot). The scene is the tallest variant that fits
-- both the window width and its height; narrower windows stack the wordmark
-- over the smallest scene that fits, or show the wordmark alone.
function M.compose(columns, lines_avail)
	columns = columns or vim.o.columns
	lines_avail = lines_avail or vim.o.lines

	-- Wordmark rows: { text = ..., spans = { {group, from, to}, ... } }.
	local left = {}
	local function text_row(text, group)
		left[#left + 1] = { text = text, spans = text ~= "" and { { group, 0, #text } } or {} }
	end
	-- VIM sits in the empty corner under the P's bowl, to the right of its
	-- stem, on the last rows of the mark.
	local VIM_COL = 24
	local vim_top = #art.mark - #art.vim
	for r, l in ipairs(art.mark) do
		local text = l
		local spans = { { "DwpArt5", 0, #l } }
		local vim_row = art.vim[r - vim_top]
		if vim_row then
			text = pad(l, VIM_COL) .. vim_row
			spans[#spans + 1] = { "DwpGreeterLogo", #pad(l, VIM_COL), #text }
		end
		left[#left + 1] = { text = text, spans = spans }
	end
	text_row("", "Normal")
	text_row(M.tagline, "DwpGreeterDim")
	text_row(M.powered, "DwpGreeterAccent")

	local lw = 0
	for _, row in ipairs(left) do
		lw = math.max(lw, vim.fn.strdisplaywidth(row.text))
	end
	local gap = 6
	local function width_of(v)
		return vim.fn.strdisplaywidth(v.lines[1])
	end

	-- Tallest variant that fits both; else the tallest that fits the width.
	local variant
	for _, v in ipairs(art.variants) do
		if columns >= lw + gap + width_of(v) + 4 then
			variant = variant or v
			if #v.lines + BELOW_HERO <= lines_avail then
				variant = v
				break
			end
		end
	end

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

	if variant then
		local rows = math.max(#left, #variant.lines)
		local top = math.floor((rows - #left) / 2)
		for r = 1, rows do
			local row = left[r - top] or { text = "", spans = {} }
			local ptxt = pad(row.text, lw) .. string.rep(" ", gap)
			local spans = vim.deepcopy(row.spans)
			if variant.lines[r] then
				for _, sp in ipairs(spans_for_row(variant, r, #ptxt)) do
					spans[#spans + 1] = sp
				end
			end
			push(ptxt .. (variant.lines[r] or ""), spans)
		end
	else
		for _, row in ipairs(left) do
			push(row.text, row.spans)
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
