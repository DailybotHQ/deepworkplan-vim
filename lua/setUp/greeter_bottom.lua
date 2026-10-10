-- Two-column bottom of the dashboard: shortcuts on the left, "Your plans"
-- on the right. Pure composition (no alpha session, no UI): the greeter
-- hands the result to one alpha text element and activates rows with a
-- buffer-local <CR>, because alpha buttons cannot sit side by side.
--
-- compose(shortcuts, plan_data, right_width) ->
--   { lines, hl, width, rows = { [i] = { left = fn?, right = fn? } },
--     split = { [i] = byte column where the right column starts } }
local M = {}

local LEFT_WIDTH = 36
local GAP = 6

local function dw(s)
	return vim.fn.strdisplaywidth(s)
end

local function pad(s, w)
	local d = dw(s)
	return d >= w and s or s .. string.rep(" ", w - d)
end

-- Greedy word wrap to `width` display cells.
local function wrap(text, width)
	local out, line = {}, ""
	for word in text:gmatch("%S+") do
		if line == "" then
			line = word
		elseif dw(line) + 1 + dw(word) <= width then
			line = line .. " " .. word
		else
			out[#out + 1] = line
			line = word
		end
	end
	if line ~= "" then
		out[#out + 1] = line
	end
	return out
end

-- Left column rows: a header, a spacer, then one row per shortcut with the
-- key label right-aligned inside LEFT_WIDTH.
local function left_rows(shortcuts)
	local rows = { { text = "Shortcuts", group = "AlphaHeader" }, { text = "" } }
	for _, sc in ipairs(shortcuts) do
		local label = vim.trim(sc.label)
		local fill = math.max(1, LEFT_WIDTH - dw(label) - dw(sc.key))
		rows[#rows + 1] = {
			text = label .. string.rep(" ", fill) .. sc.key,
			group = "AlphaButtons",
			run = sc.run,
		}
	end
	return rows
end

-- Right column rows: header, spacer, the plan rows (or the wrapped empty
-- state), a spacer, the hint and the sidebar button.
local function right_rows(data, sidebar, open_plan, width)
	local rows = { { text = "Your plans", group = "AlphaHeader" }, { text = "" } }
	if data and #data.plan_lines > 0 then
		for _, row in ipairs(data.plan_lines) do
			rows[#rows + 1] = {
				text = row.text,
				group = "AlphaButtons",
				run = function()
					open_plan(row.record)
				end,
			}
		end
		rows[#rows + 1] = { text = "" }
		rows[#rows + 1] = { text = data.hint, group = "Comment" }
	else
		for _, l in ipairs(wrap((data and data.empty_line) or "No plans yet.", width)) do
			rows[#rows + 1] = { text = l, group = "Comment" }
		end
		rows[#rows + 1] = { text = "" }
	end
	local label = "Open plans sidebar"
	local fill = math.max(1, width - dw(label) - 1)
	rows[#rows + 1] = {
		text = label .. string.rep(" ", fill) .. "e",
		group = "AlphaButtons",
		run = sidebar,
	}
	return rows
end

--- Widest right-hand row, so the left column and the block can be sized.
function M.right_width(data)
	local w = 40
	if data then
		for _, row in ipairs(data.plan_lines) do
			w = math.max(w, dw(row.text))
		end
		w = math.max(w, dw(data.hint or ""))
	end
	return w
end

function M.compose(shortcuts, data, actions)
	local rw = M.right_width(data)
	local left = left_rows(shortcuts)
	local right = right_rows(data, actions.sidebar, actions.open_plan, rw)
	local n = math.max(#left, #right)
	local lines, hl, rows, split = {}, {}, {}, {}
	for i = 1, n do
		local l = left[i] or { text = "" }
		local r = right[i] or { text = "" }
		local ltxt = pad(l.text, LEFT_WIDTH) .. string.rep(" ", GAP)
		local text = ltxt .. r.text
		local spans = {}
		if l.group and l.text ~= "" then
			spans[#spans + 1] = { l.group, 0, #l.text }
		end
		if r.group and r.text ~= "" then
			spans[#spans + 1] = { r.group, #ltxt, #text }
		end
		if #spans == 0 then
			spans[1] = { "Normal", 0, 0 }
		end
		lines[i], hl[i] = text, spans
		rows[i] = { left = l.run, right = r.run }
		split[i] = #ltxt
	end
	return { lines = lines, hl = hl, width = LEFT_WIDTH + GAP + rw, rows = rows, split = split }
end

return M
