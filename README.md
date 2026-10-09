# DeepWorkPlan Vim

**DeepWorkPlan's editor** — the terminal editor for [Deep Work Plan](https://deepworkplan.com): a Neovim configuration with a VS Code feel — lightweight, fast to start, built for humans and for coding agents that live in a terminal, including Herdr panes.

This repository is public, GPL-3.0. It is derived from [AndresMpa/mu-vim](https://github.com/AndresMpa/mu-vim) (see [CREDITS.md](./CREDITS.md)). New work lands here under the DeepWorkPlan name.

> **Optional, never required.** DeepWorkPlan v7 offers this editor as its optional `vim` addon during onboarding, pinned by tag. The methodology works with any editor (or none), and this editor works on its own — nothing here installs or requires the DeepWorkPlan skill.

## Install (host)

One line — macOS, Linux, or WSL (installs git, curl, and Lua first if they are missing):

```bash
curl -fsSL https://deepworkplan.com/vim/install.sh | bash
```

That is the whole install: preflight, clone into `~/.config/nvim`, the system
setup (`lua install.lua`), and a headless plugin install — no quit-and-reopen
dance. An existing Neovim config is **never overwritten**: interactively you
are asked before it is moved to `~/.config/previous-deepworkplan-vim`; piped
without a terminal the script aborts instead of touching anything.

Advanced / offline:

```bash
curl -fsSL https://deepworkplan.com/vim/install.sh | DWP_VIM_REF=v0.4.0 bash   # pin a tag (recommended for images and automation)
git clone https://github.com/DailybotHQ/deepworkplan-vim.git ~/.config/nvim    # manual (advanced)
cd ~/.config/nvim && lua install.lua
DWP_VIM_SOURCE=/path/to/deepworkplan-vim bash install.sh                       # local/offline source (also redirects updates)
DWP_VIM_SKIP_PACKAGES=1 lua install.lua                                        # image already has the deps
```

Windows: `curl | bash` is not the Windows gesture — use winget plus Git Bash,
or run the one-liner above inside WSL, where it works as-is:

```bash
winget install -e --id Neovim.Neovim --accept-package-agreements --accept-source-agreements
git clone https://github.com/DailybotHQ/deepworkplan-vim.git "$LOCALAPPDATA/nvim"
cd "$LOCALAPPDATA/nvim" && lua install.lua
```

Run the last two lines in Git Bash (which provides `git`); `lua` must be on
PATH. A one-line Windows installer is on the roadmap. Requires
[Neovim](https://github.com/neovim/neovim/wiki/Installing-Neovim) 0.12+.

## Remove

One line — the same shape as the install. It lists every path it will touch
and asks before removing anything; Neovim itself stays installed:

```bash
lua ~/.config/nvim/delete.lua
```

On Windows the config lives in `%LOCALAPPDATA%\nvim` — in Git Bash:
`lua "$LOCALAPPDATA/nvim/delete.lua"`.

## What you get

Five features, each one keystroke away:

| Feature | Key | What it does |
|---|---|---|
| Command index | `SPC h h` | Every mapping in this config, generated live from the actual keymaps — always accurate, grouped, searchable. This is the product tour. |
| VS Code gestures | `<C-a>` · `SPC y` | Select all in one key (`<C-a>`); yank to the system clipboard (`SPC y`, works in visual mode too). |
| Plan browser | `SPC P` · click | Browse every Deep Work Plan under the current repo or config in a sidebar grouped by status (Working, Needs attention, Ready, Not started, Done) with progress bars and percent; Enter opens a plain-language reader for one plan; the statusline shows the live active plan (click it for the sidebar) and the dashboard lists the top three. |
| Markdown viewer | `SPC m p` · `SPC m r` | Preview in the browser (`p`) or render in the buffer (`r`) — the same implementation `SPC x` uses to run files. |
| One-line installer | — | The `curl` above. Preflight, clone, system setup, plugins — headless, consent-first. |

`SPC` is the leader (`Space` by default). The index (`SPC h h`) lists all of
this and everything else; `:DwpCommands` and `:DwpPlans` are the
terminal-independent entry points for the same two panels.

**Quickstart:** run the one-liner, launch `nvim`, press `Space h h`. The index
is the tour — every row names its key and what it does.

Also included: `lua install.lua` / `lua delete.lua` for install and uninstall,
and an optional **dev container** with Herdr mesh so agents in this repo can
list and talk to agents on other machines.

## Contributor environment (Docker)

The image does **not** clone a second copy of the config. This repo mounts at `/workspace` and is linked to `~/.config/nvim`. Neovim 0.12.5 and Herdr are in the image. Coding CLIs are opt-in.

```bash
cp docker/local/dwpvim/.env.example docker/local/dwpvim/.env
bash dev.sh build
bash dev.sh up
bash dev.sh shell
bash dev.sh agents    # list Herdr agents across machines
```

Herdr SSH publishes at `127.0.0.1:22035` (override `HERDR_SSH_HOST_PORT`). Copy `.devcontainer_example/` to `.devcontainer/` for VS Code / Cursor.

Selective CLIs (default `false`):

```bash
docker compose -f docker/local/docker-compose.yaml build \
  --build-arg INSTALL_CLAUDE_CLI=true --build-arg INSTALL_CODEX_CLI=true
```

Mesh ask/reply uses stamp `[herdr-mesh]`. The first hop **authorizes** the other agent to reply. See `AGENTS.md`.

Root `compose.yml` still runs multi-distro installer smokes.

## Releases

Merging to `main` publishes a GitHub Release (`v0.1.0`, then the next tag). Conventional commits: `feat:` / `fix:` / `perf:` bump minor; `BREAKING CHANGE` bumps major. `[skip release]` in the merge body publishes nothing.

## Lineage

GPL-3.0. Derived from [AndresMpa/mu-vim](https://github.com/AndresMpa/mu-vim). Do not drop the license or the credit.
