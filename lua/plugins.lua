-- Commit pins (lua/plugin_lock.lua): every plugin and pckr itself install
-- and update at the commit pckr/lockfile.lua pins, so two installs of one
-- release get the same code. DWP_VIM_LOCK_UPDATE=1 — set only by
-- scripts/update-plugin-lock.sh — ignores the pins so a sync moves every
-- plugin to its branch tip.
local plugin_lock = require("plugin_lock")
local lock = vim.env.DWP_VIM_LOCK_UPDATE == "1" and {}
  or plugin_lock.read(vim.fn.stdpath("config") .. "/pckr/lockfile.lua")

-- HEAD of a git checkout without spawning git (startup path): a detached
-- HEAD file holds the commit itself.
local function head_commit(path)
  local f = io.open(path .. "/.git/HEAD", "r")
  if not f then
    return nil
  end
  local head = f:read("*l")
  f:close()
  return head
end

local function bootstrap_pckr()
  local pckr_path = vim.fn.stdpath("data") .. "/pckr/pckr.nvim"
  local fs = vim.uv or vim.loop
  local pin = plugin_lock.commit(lock, plugin_lock.PCKR_URL)

  if not fs.fs_stat(pckr_path) then
    vim.fn.system({ "git", "clone", "--filter=blob:none", plugin_lock.PCKR_URL, pckr_path })
  end

  -- Move pckr to its pin (a fresh clone, or one made by an older release
  -- at the branch tip); fetch only when the commit is not local yet.
  if pin and fs.fs_stat(pckr_path) and head_commit(pckr_path) ~= pin then
    local git = { "git", "-C", pckr_path }
    vim.fn.system(vim.list_extend(vim.deepcopy(git), { "checkout", "-q", pin }))
    if vim.v.shell_error ~= 0 then
      vim.fn.system(vim.list_extend(vim.deepcopy(git), { "fetch", "-q", "origin" }))
      vim.fn.system(vim.list_extend(vim.deepcopy(git), { "checkout", "-q", pin }))
    end
  end

  vim.opt.rtp:prepend(pckr_path)
end

bootstrap_pckr()

-- Headless bootstrap (install.sh, images): no autoinstall inside add().
-- With autoinstall on, add() starts asynchronous clones that the VimEnter
-- sync below does not wait for; quitting on the sync's completion callback
-- then killed them mid-checkout, leaving empty clones (seen in a fresh
-- container). Off, the sync performs every install and its callback is the
-- real end. Interactive launches keep autoinstall.
if vim.tbl_contains(vim.v.argv, "--headless") then
  require("pckr").setup({ autoinstall = false })
end

-- Each spec and each of its requires carries its pinned commit; pckr
-- checks that commit out on install and on update (sync).
require("pckr").add(plugin_lock.pin_all(require("plugin_specs"), lock))

-- First launch: no plugins cloned yet. Detected on the filesystem — the
-- same check install.sh uses — because `require('mason')` cannot work
-- here: plugins only reach the runtimepath once pckr loads them, so a
-- require-based probe would be false on EVERY launch and re-sync (with
-- its input-stealing display window) on every start.
local pckr_opt = vim.fn.stdpath("data") .. "/site/pack/pckr/opt"
-- install.sh sets DWP_VIM_BOOTSTRAP=1 for its headless run, which also
-- repairs installs whose plugins are incomplete (mason.nvim may exist).
if vim.env.DWP_VIM_BOOTSTRAP == "1" or vim.fn.isdirectory(pckr_opt .. "/mason.nvim") == 0 then
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      -- require('pckr') exports only add/setup; the operations live in
      -- pckr.actions (async.sync-wrapped: the third argument is the
      -- completion callback).
      local ok, actions = pcall(require, "pckr.actions")
      if not ok then
        return
      end
      -- Headless (install.sh bootstrap): run a full sync and exit on its
      -- completion callback — no quit-and-reopen dance. Headless runs have
      -- autoinstall off (above), so this sync performs every install; the
      -- short defer only lets its final output flush.
      if #vim.api.nvim_list_uis() == 0 then
        actions.sync(nil, nil, function()
          vim.defer_fn(function()
            print("pckr: plugins installed")
            vim.cmd("qa!")
          end, 1000)
        end)
        return
      end
      vim.notify(
        "Installing plugins. Quit Neovim when it finishes, then open it again.",
        vim.log.levels.INFO
      )
      actions.sync()
    end,
  })
end
