# AGENTS.md — DeepWorkPlan Vim

Public Neovim configuration. Language: English. Conventional commits. GPL-3.0.

## Product

DeepWorkPlan Vim is the terminal editor for [Deep Work Plan](https://deepworkplan.com). Host install: clone to `~/.config/nvim` and `lua install.lua`. This repo **is** the config; do not nest a second clone inside Docker.

Roadmap: optional DWP **v7** addon. Not v6.

## Local container

| Item | Value |
|------|--------|
| User | `dev` (uid 1000) |
| Workdir | `/workspace` (this git tree, also `~/.config/nvim`) |
| Editor | Neovim 0.12.5 tarball (`EDITOR=nvim`) |
| Herdr SSH | `127.0.0.1:22035` |
| Launcher | `bash dev.sh` — `up` `down` `shell` `build` `rebuild` `agents` `ask` |

Coding CLIs (`INSTALL_CLAUDE_CLI`, …) default **false**. Herdr is always installed.

### Mesh

```bash
bash dev.sh agents
bash dev.sh ask <#> "Prompt..."
bash dev.sh ask <machine-id> <pane> "Prompt..."
```

Address is **machine id + pane id**. `#` dies with that listing. First hop includes `[herdr-mesh]` grant: the receiver is **authorized to reply now**, must send the reply itself, must not ask a person. A body that already has the stamp is a reply — do not answer it.

Peers from inside the container use `host.docker.internal` plus the published SSH port. Trust ED25519 host keys before `herdr agent list`.

Install Herdr on the host: https://herdr.dev/docs/install/ — show the command; do not pipe an installer without consent.

## Validation

```bash
bash -n dev.sh
bash -n docker/local/dwpvim/entrypoint.sh
# optional: bash tests/run.sh   # multi-distro installer smokes
```

## Do not

- Commit secrets or private hostnames
- Bake SSH host private keys into the image
- Require Dailybot-only paths or `dbdev`
- Change `LICENSE` away from GPL-3.0
- Drop [CREDITS.md](./CREDITS.md)
