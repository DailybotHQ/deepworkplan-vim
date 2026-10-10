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

-- Lighthouse. Character classes drive the colour (see classify):
--   ░▒▓  the red beam      █▀▄▌▐▟▙▛▜  stone      ~≈  sea
M.lighthouse = {
	"                           ▄",
	"                          ▟█▙",
	"  ░░░░░░░░░░░░░▒▒▒▒▒▒▓▓▓▓▐▓█▓▌",
	"░░░░░░░░░░░░░░░▒▒▒▒▒▒▓▓▓▓▐███▌",
	"   ░░░░░░░░░░░░▒▒▒▒▒▓▓▓▓▓▐▓█▓▌",
	"                         ▀▀█▀▀",
	"                          ▐█▌",
	"                         ▐█ █▌",
	"                        ▟█████▙  ▄▄",
	"                       ▟███████▙ ▟██▙",
	"                      ▟█████████▙▀▀▀▀",
	"            ▄▄ ▄▄▄  ▟██████████████▙▄",
	"   |\\   ▟████▟██████████████████▙",
	"~~~~▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀",
	"~~ ≈≈ ~~~~ ≈≈ ~~~~~ ≈≈ ~~~~~~ ≈≈ ~~~~ ≈",
}

local BEAM = { ["░"] = true, ["▒"] = true, ["▓"] = true }
local SEA = { ["~"] = true, ["≈"] = true }

-- Highlight class of one character.
local function classify(ch)
	if BEAM[ch] then
		return "DwpGreeterBeam"
	elseif SEA[ch] then
		return "DwpGreeterSea"
	elseif ch == " " then
		return nil
	end
	return "DwpGreeterStone"
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
function M.compose(columns)
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
	for _, l in ipairs(M.lighthouse) do
		rw = math.max(rw, vim.fn.strdisplaywidth(l))
	end
	local gap = 6
	local side_by_side = (columns or vim.o.columns) >= lw + gap + rw + 4

	local lines, hl = {}, {}
	local function spans_for_art(text, offset)
		local spans, run_group, run_start = {}, nil, nil
		local byte = offset
		local n = vim.fn.strchars(text)
		for i = 0, n - 1 do
			local ch = vim.fn.strcharpart(text, i, 1)
			local g = classify(ch)
			if g ~= run_group then
				if run_group then
					spans[#spans + 1] = { run_group, run_start, byte }
				end
				run_group, run_start = g, byte
			end
			byte = byte + #ch
		end
		if run_group then
			spans[#spans + 1] = { run_group, run_start, byte }
		end
		return spans
	end

	if side_by_side then
		local rows = math.max(#left, #M.lighthouse)
		local top = math.floor((rows - #left) / 2) + 1
		for r = 1, rows do
			local li = r - top + 1
			local ltxt = (li >= 1 and li <= #left) and left[li] or ""
			local lgrp = (li >= 1 and li <= #left) and left_class[li] or false
			local ptxt = pad(ltxt, lw) .. string.rep(" ", gap)
			local rtxt = M.lighthouse[r] or ""
			local spans = {}
			if lgrp and ltxt ~= "" then
				spans[#spans + 1] = { lgrp, 0, #ltxt }
			end
			for _, s in ipairs(spans_for_art(rtxt, #ptxt)) do
				spans[#spans + 1] = s
			end
			lines[#lines + 1] = ptxt .. rtxt
			hl[#hl + 1] = spans
		end
	else
		for i, l in ipairs(left) do
			lines[#lines + 1] = l
			hl[#hl + 1] = left_class[i] and { { left_class[i], 0, #l } } or {}
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
	hi("DwpGreeterBeam", { fg = "#d0564f" })
	hi("DwpGreeterStone", { fg = "#c9c1b0" })
	hi("DwpGreeterSea", { fg = "#5f7480" })
end

return M
