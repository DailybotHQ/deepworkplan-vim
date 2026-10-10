-- Dashboard art for the DWP Vim greeter: the DWP VIM wordmark on the left
-- and the Deep Work Plan lighthouse (the site's hero) on the right.
-- Pure data plus a small composer: no requires, no side effects at load.
local M = {}

-- Wordmark: "DWP VIM" in half-block pixel letters, three rows tall.
M.logo = {
	"█▀▄ █   █ █▀█   █ █ ▀█▀ █▄ ▄█",
	"█ █ █ █ █ █▀▀   █ █  █  █ ▀ █",
	"█▄▀ ▀▄▀▄▀ █      ▀   █  ▀   ▀",
}
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

-- Compose the hero: left block (wordmark, tagline, powered-by) vertically
-- centred beside the lighthouse. Returns { lines = {...}, hl = {...} } with
-- alpha-style per-line highlight spans ({group, byte_start, byte_end}).
-- Narrow windows get the wordmark alone, stacked over the credit line.
function M.compose(columns, lines_avail)
	local variant = pick_variant(lines_avail or vim.o.lines)
	local lighthouse = variant.lines
	local left = {}
	local left_class = {}
	for _, l in ipairs(M.logo) do
		left[#left + 1] = l
		left_class[#left_class + 1] = "DwpGreeterLogo"
	end
	left[#left + 1] = ""
	left_class[#left_class + 1] = false
	left[#left + 1] = M.tagline
	left_class[#left_class + 1] = "DwpGreeterDim"
	left[#left + 1] = M.powered
	left_class[#left_class + 1] = "DwpGreeterAccent"

	local lw = 0
	for _, l in ipairs(left) do
		lw = math.max(lw, vim.fn.strdisplaywidth(l))
	end
	local rw = 0
	for _, l in ipairs(lighthouse) do
		rw = math.max(rw, vim.fn.strdisplaywidth(l))
	end
	local gap = 6
	local side_by_side = (columns or vim.o.columns) >= lw + gap + rw + 4

	local lines, hl = {}, {}
	if side_by_side then
		local rows = math.max(#left, #lighthouse)
		local top = math.floor((rows - #left) / 2) + 1
		for r = 1, rows do
			local li = r - top + 1
			local ltxt = (li >= 1 and li <= #left) and left[li] or ""
			local lgrp = (li >= 1 and li <= #left) and left_class[li] or false
			local ptxt = pad(ltxt, lw) .. string.rep(" ", gap)
			local rtxt = lighthouse[r] or ""
			local spans = {}
			if lgrp and ltxt ~= "" then
				spans[#spans + 1] = { lgrp, 0, #ltxt }
			end
			for _, s in ipairs(rtxt ~= "" and spans_for_row(variant, r, #ptxt) or {}) do
				spans[#spans + 1] = s
			end
			-- alpha tells per-line highlight tables apart by the first line
			-- carrying a span, so no row may be left without one.
			if #spans == 0 then
				spans[1] = { "Normal", 0, 0 }
			end
			lines[#lines + 1] = ptxt .. rtxt
			hl[#hl + 1] = spans
		end
	else
		for i, l in ipairs(left) do
			lines[#lines + 1] = l
			hl[#hl + 1] = { { left_class[i] or "Normal", 0, #l } }
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
