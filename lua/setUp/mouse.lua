-- Mouse routing for the plan windows, installed globally: with the focus in any
-- buffer, a click is decided by the window under the pointer (see
-- lua/dwp/mouse.lua). Nothing is loaded until a click happens, and a click that
-- is not over a plan window gets Vim's own behaviour.
local function route(fn_name, ...)
	local args = { ... }
	return function()
		local mouse = require("dwp.mouse")
		local f = mouse[fn_name]
		if fn_name == "multi_click" then
			return f(unpack(args))()
		end
		return f()
	end
end

-- Cheap guard: no plan window can exist until one of the modules is loaded, so the
-- common click costs two table lookups and then Vim's default.
local function plans_loaded()
	return package.loaded["dwp.sidebar"] ~= nil or package.loaded["dwp.reader"] ~= nil
end

local function default(count)
	local key = count > 1 and ("<%d-LeftMouse>"):format(count) or "<LeftMouse>"
	vim.cmd(('exe "normal! \\%s"'):format(key))
end

vim.keymap.set("n", "<LeftMouse>", function()
	if plans_loaded() then
		return route("click")()
	end
	default(1)
end, { silent = true, desc = "Mouse click (plan windows act on the row under the pointer)" })

for count = 2, 4 do
	vim.keymap.set("n", ("<%d-LeftMouse>"):format(count), function()
		if plans_loaded() then
			return route("multi_click", count)()
		end
		default(count)
	end, { silent = true, desc = "Mouse multi-click (ignored over plan windows)" })
end
