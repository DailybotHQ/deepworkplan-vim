# Product spec — DeepWorkPlan Vim

## What this is

The official **terminal editor** for [Deep Work Plan](https://deepworkplan.com):
a batteries-included Neovim configuration that serves two users at once —
**a person** working in a terminal, and **a coding agent** living in a terminal
pane (including Herdr mesh panes on other machines). It is a git repository
that *is* the product: clone it to `~/.config/nvim`, run `lua install.lua`, and
Neovim becomes the DeepWorkPlan editor.

## Who it is for

- **Deep Work Plan practitioners** who want their editor pre-tuned for the
  long, structured sessions the methodology prescribes (plans, docs, reviews).
- **Coding agents** that need a stable, predictable editing environment:
  deterministic mappings (a documented contract, not vibes), LSP + linting +
  formatting wired, and a config that survives agent-driven churn.
- **Contributors** developing the editor itself — the Docker + Herdr
  environment in this repo exists for them.

## Key capabilities

1. **One-command install/uninstall** across Linux (pacman/apt/dnf), macOS
   (Homebrew), and Windows (winget), with the user's previous config backed
   up, never destroyed (`install.lua` / `delete.lua`).
2. **A stable mapping contract** — the keybindings are pinned by Go contract
   tests (`tests/`), shared across the mu-vim flavor family, so muscle memory
   and agent expectations both survive updates.
3. **Tuned-for-agents editing stack** — LSP, completion, linting, formatting,
   fuzzy finding, file management, and a theme system with curated palettes,
   composed through pckr.nvim with lazy startup.
4. **Contributor dev container** — Docker environment with Neovim pinned,
   Herdr mesh connectivity, opt-in coding CLIs, and persistence volumes for
   CLI auth (`dev.sh`, `docker/local/`).
5. **Automated releases** — merging to `main` publishes a versioned GitHub
   Release driven by conventional-commit prefixes.

## Success criteria

- A fresh machine goes from `git clone` to a working editor with one command,
   on all three platform families, idempotently.
- The mapping contract suite stays green across flavors; keybindings never
   change silently.
- Agents can sit in this editor (or a mesh pane) and edit code with the same
   LSP/lint/format surface a human gets.
- Nothing private ever ships: no secrets, no private hostnames, no baked SSH
   keys.

## Non-goals

- **Not a DWP v6 addon.** The editor is planned as an *optional addon for
  DWP v7* upstream; it does not install or require the DeepWorkPlan skill
  itself to function as an editor.
- Not a framework, distro, or plugin marketplace — one curated config.
- Not a wrapper around any single coding CLI: agent CLIs are opt-in build
  args, and no path requires a specific vendor (no Dailybot-only flows, no
  `dbdev`).
- No support for Neovim < 0.12.
