-- Minimal runtime for dwp smokes: the repo's lua/ tree on rtp and
-- nothing else — no plugins, no data dir, no network, no plugin sync.
-- Invoked as: nvim --headless -u tests/smoke/minimal_init.lua
-- (cwd = repo root, set by tests/smoke/run.sh).

local repo = vim.fn.fnamemodify(vim.uv.cwd(), ":p"):gsub("/$", "")
vim.opt.runtimepath:prepend(repo)

-- Keep the smoke run hermetic: nothing written, no history read.
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
vim.opt.updatecount = 0
