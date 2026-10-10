-- Mouse routing for the plan windows (the sidebar and the reader).
--
-- A mapped <LeftMouse> is resolved against the CURRENT buffer's mappings, not the
-- buffer under the pointer. With the focus in the reader, a click on the sidebar
-- was therefore handled by the reader's mapping and ignored; and a double-click
-- (<2-LeftMouse>) fell through to Vim's word selection and left a stray Visual
-- mode. So every click is decided here, by the window under the pointer, whichever
-- buffer has the focus:
--   * over a plan window: focus it and let it act (a click on a plan opens it);
--     the second, third and fourth click of a multi-click are swallowed;
--   * anywhere else: Vim's own behaviour, untouched.
--
-- The editor installs the same functions as global mappings
-- (lua/setUp/mouse.lua) and each plan window as buffer-local ones, so the
-- windows keep working when this module is used on its own.
local M = {}

-- Vim's default behaviour for a click, replayed when the pointer is not over a
-- plan window. A field so the smokes can observe it.
function M.default_click(count)
	local key = count and count > 1 and ("<%d-LeftMouse>"):format(count) or "<LeftMouse>"
	vim.cmd(('exe "normal! \\%s"'):format(key))
end

-- The plan module that owns `winid`, or nil.
function M.owner(winid)
	local ok, sidebar = pcall(require, "dwp.sidebar")
	if ok and sidebar.owns_window(winid) then
		return sidebar
	end
	local ok2, reader = pcall(require, "dwp.reader")
	if ok2 and reader.owns_window(winid) then
		return reader
	end
	return nil
end

--- <LeftMouse>
function M.click()
	local pos = vim.fn.getmousepos()
	local mod = M.owner(pos.winid)
	if not mod then
		return M.default_click(1)
	end
	if vim.api.nvim_get_current_win() ~= pos.winid then
		vim.api.nvim_set_current_win(pos.winid)
	end
	mod.click(pos)
end

--- <2-LeftMouse>, <3-LeftMouse>, <4-LeftMouse>: the first click already acted.
function M.multi_click(count)
	return function()
		if not M.owner(vim.fn.getmousepos().winid) then
			M.default_click(count)
		end
	end
end

return M
