# DeepWorkPlan Vim

The official **terminal editor** for [Deep Work Plan](https://deepworkplan.com). A Neovim configuration for humans and for coding agents that live in a terminal — including Herdr panes.

This repository is public, GPL-3.0. It is derived from [AndresMpa/mu-vim](https://github.com/AndresMpa/mu-vim) (see [CREDITS.md](./CREDITS.md)). New work lands here under the DeepWorkPlan name.

> **Roadmap:** DeepWorkPlan **v7** will offer this editor as an optional addon (`deepworkplan-vim`) during onboard. It is **not** part of v6.

## Install (host)

Needs [Neovim](https://github.com/neovim/neovim/wiki/Installing-Neovim) 0.12+ and Lua (`lua`, `lua5.4`, or `luajit`).

```bash
git clone https://github.com/DailybotHQ/deepworkplan-vim.git ~/.config/nvim
cd ~/.config/nvim && lua install.lua
nvim
```

Windows: clone into `%LOCALAPPDATA%\nvim` and run `lua install.lua`.

## What you get

- A batteries-included Neovim config (Lua) tuned for long agent sessions
- `lua install.lua` / `lua delete.lua` for install and uninstall
- Optional **dev container** with Herdr mesh so agents in this repo can list and talk to agents on other machines

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
