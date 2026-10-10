#!/usr/bin/env bash
# Boot check — start the real configuration headless and fail on any error.
#
# The smoke suite is hermetic (no plugins); this is the one check that loads
# the whole config with its plugins, so a removed plugin or a stale require
# shows up here. It reads the plugins and Mason packages from the data
# directory (XDG_DATA_HOME or ~/.local/share/nvim); it installs nothing.
#
#   1. a throwaway XDG_CONFIG_HOME links `nvim` to this checkout, so the
#      checkout is the config, whatever the user's own config is;
#   2. nvim starts headless, waits for the deferred setup to settle, then
#      collects :messages;
#   3. it fails on any error line, on a missing core module, and if a
#      retired plugin still loads.
#
# Usage: scripts/boot-check.sh
# Needs: bash, nvim 0.12+, the plugins installed (run the installer first).
# Env:   DWP_BOOT_WAIT_MS  settle time before collecting (default 4000)
# Exit:  0 boots clean, 1 a problem was found, 2 cannot run (no nvim/plugins).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
data="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
wait_ms="${DWP_BOOT_WAIT_MS:-4000}"

command -v nvim >/dev/null 2>&1 || { echo "boot-check: nvim not found on PATH" >&2; exit 2; }
if [ ! -d "$data/site/pack/pckr/opt/mason.nvim" ]; then
	echo "boot-check: plugins are not installed under $data (run install.sh first)" >&2
	exit 2
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config"
ln -s "$repo" "$tmp/config/nvim"

cat >"$tmp/check.lua" <<LUA
vim.defer_fn(function()
  local out = {}
  local msgs = vim.api.nvim_exec2("messages", { output = true }).output or ""
  local bad = {}
  for line in msgs:gmatch("[^\n]+") do
    if line:find("^E%d+:") or line:lower():find("error") or line:find("stack traceback") then
      bad[#bad + 1] = line
    end
  end
  -- Modules the editor cannot be without: the LSP chain, completion, the greeter.
  for _, mod in ipairs({ "lsp.server", "mason", "mason-lspconfig", "lspconfig", "cmp", "luasnip", "alpha", "telescope", "nvim-tree", "lualine" }) do
    if not package.loaded[mod] and not pcall(require, mod) then
      bad[#bad + 1] = "core module does not load: " .. mod
    end
  end
  -- Retired plugins must be gone, not merely unused.
  for _, mod in ipairs({ "lint" }) do
    if pcall(require, mod) then
      bad[#bad + 1] = "retired module still loads: " .. mod
    end
  end
  local f = assert(io.open("$tmp/result.txt", "w"))
  f:write(#bad == 0 and "OK" or table.concat(bad, "\n"))
  f:close()
  vim.cmd("qa!")
end, $wait_ms)
LUA

XDG_CONFIG_HOME="$tmp/config" timeout 120 nvim --headless -S "$tmp/check.lua" >"$tmp/nvim.out" 2>&1 || true

if [ ! -s "$tmp/result.txt" ]; then
	echo "boot-check: Neovim did not finish the check" >&2
	sed 's/^/  /' "$tmp/nvim.out" | head -20 >&2
	exit 1
fi
if [ "$(cat "$tmp/result.txt")" = "OK" ] && ! grep -qiE "error|E[0-9]+:" "$tmp/nvim.out"; then
	echo "boot-check: OK (the real config boots clean)"
	exit 0
fi
echo "boot-check: FAILED" >&2
{ cat "$tmp/result.txt"; echo; cat "$tmp/nvim.out"; } | sed 's/^/  /' | head -30 >&2
exit 1
