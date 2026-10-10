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
				spans[#spans + 1] = { "DwpArt" .. tonumber(run, 36), start, byte }
			end
			run, start = c, byte
		end
		byte = byte + 3 -- one braille cell is 3 bytes
	end
	if run then
		spans[#spans + 1] = { "DwpArt" .. tonumber(run, 36), start, byte }
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
function M.compose(columns, lines_avail, below)
	below = below or BELOW_HERO
	columns = columns or vim.o.columns
	lines_avail = lines_avail or vim.o.lines

	-- Wordmark rows: { text = ..., spans = { {group, from, to}, ... } }.
	local left = {}
	local function text_row(text, group)
		left[#left + 1] = { text = text, spans = text ~= "" and { { group, 0, #text } } or {} }
	end
	-- VIM sits in the empty corner under the P's bowl, to the right of its
	-- stem, on the last rows of the mark (its bottom meets the P's foot).
	local VIM_COL = 22
	local vim_top = #art.mark - #art.vim
	for r, l in ipairs(art.mark) do
		local vim_row = art.vim[r - vim_top]
		-- Blank braille cells at the end of a mark row are padding: drop them
		-- on the rows VIM shares so it sits against the P.
		local l = vim_row and vim.fn.substitute(l, "\\%u2800\\+$", "", "") or l
		local text = l
		local spans = { { "DwpArt7", 0, #l } }
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
	local gap = 4
	local function width_of(v)
		return vim.fn.strdisplaywidth(v.lines[1])
	end

	-- Tallest variant that fits both; else the tallest that fits the width.
	local variant
	for _, v in ipairs(art.variants) do
		if columns >= lw + gap + width_of(v) + 4 then
			variant = variant or v
			if #v.lines + below <= lines_avail then
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
		-- Biased toward the top so the beam sweeps across the wordmark.
		local top = math.floor((rows - #left) * 0.4)
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

-- Slow pulse of the beam: the four red classes breathe between dim and
-- bright while the dashboard is on screen. One uv timer, started when the
-- dashboard draws and stopped as soon as its buffer is hidden or wiped;
-- `vim.g.dwp_greeter_pulse = false` turns it off. Nothing runs at boot.
local PULSE_STEP_MS = 160
local PULSE_PERIOD_STEPS = 24
local pulse_timer = nil

local function scaled(hex, k)
	local r, g, b = hex:match("#(%x%x)(%x%x)(%x%x)")
	local function ch(v)
		return math.min(255, math.floor(tonumber(v, 16) * k + 0.5))
	end
	return string.format("#%02x%02x%02x", ch(r), ch(g), ch(b))
end

local function stop_pulse()
	if pulse_timer then
		pulse_timer:stop()
		pulse_timer:close()
		pulse_timer = nil
		M.define_highlights()
	end
end

function M.start_pulse(buf)
	if vim.g.dwp_greeter_pulse == false or #vim.api.nvim_list_uis() == 0 then
		return
	end
	stop_pulse()
	local timer = vim.uv.new_timer()
	if not timer then
		return
	end
	pulse_timer = timer
	local step = 0
	timer:start(
		PULSE_STEP_MS,
		PULSE_STEP_MS,
		vim.schedule_wrap(function()
			if pulse_timer ~= timer then
				return
			end
			if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "alpha" then
				return stop_pulse()
			end
			if vim.fn.bufwinid(buf) == -1 then
				return -- hidden: skip the tick, stop when the buffer goes
			end
			step = (step + 1) % PULSE_PERIOD_STEPS
			local k = 0.84 + 0.2 * (1 + math.sin(2 * math.pi * step / PULSE_PERIOD_STEPS)) / 2
			for i = 9, 12 do
				vim.api.nvim_set_hl(0, "DwpArt" .. (i - 1), { fg = scaled(art.palette[i], k) })
			end
		end)
	)
	vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
		buffer = buf,
		once = true,
		callback = stop_pulse,
	})
end

return M
