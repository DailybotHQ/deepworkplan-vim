# Architecture — deepworkplan-vim

## Shape

A single-product repository: the Neovim config tree (`lua/`), its installer
(`install.lua` + `utilities/installation/`), its contributor environment
(`dev.sh` + `docker/`), and its contract tests (`tests/`, Go). Deployment shape
= "clone-to-`~/.config/nvim`" on end-user machines; there is no server.

## Boot chain (runtime)

```
init.lua
  ├─ require('settings')      lua/settings.lua      vim.opt basics, perf flags
  ├─ require('mapping')       lua/mapping/init.lua  keybindings (contract-tested)
  ├─ require('autocommand')   lua/autocommand.lua   autocmds
  ├─ require('plugins')       lua/plugins.lua       pckr.nvim bootstrap + plugin list
  └─ require('composition')   lua/composition.lua   wires the plugin set-up below
        ├─ lua/setUp/*        greeter, finder, statusline, file manager, autosave, …
        ├─ lua/lsp/*          lspconfig/mason servers, formatters, linters, completion
        └─ lua/scheme/*       theme apply/picker + curated palettes (lua/scheme/palettes/)
```

pckr.nvim is bootstrapped on first launch (cloned into stdpath data); plugin
updates flow through pckr, not through this repo's git.

## Module map

```
lua/                 the editor config (see lua/README.md)
lua/dwp/             plan browser: .dwp/plans discovery + state derivation
                     (lazy — loaded on first SPC P, never at boot)
utilities/           installer modules + snippet getters + spelling helpers
docker/              contributor container (docker/local/) + image custom commands
tests/               Go mapping-contract suite (parses Lua/VimScript; no Neovim)
snippets/ dicts/     data: snippet sources, spell dictionaries
dev.sh               launcher: compose up/down/shell/build/rebuild + herdr agents/ask
install.sh           curl-able entry: preflight, consent, clone/update, then lua
                     install.lua + headless plugin bootstrap (thin wrapper)
install.lua          multi-distro installer (runs on user machines, sudo for packages)
delete.lua           uninstaller
```

## Contributor environment (feature area)

`docker/local/docker-compose.yaml` builds the `dwpvim` image: Neovim 0.12.5,
Herdr, user `dev` (uid 1000), workdir `/workspace` mounted over
`~/.config/nvim`. The build context is the repository root (kept lean by
`.dockerignore`), and the image bakes a first-launch-ready editor: one
headless `nvim --headless` sync installs the pckr plugins (the same
self-exiting bootstrap install.sh uses), plus pnpm + biome (user prefix,
`PNPM_HOME`), and the Iosevka Nerd Font — mirroring
`utilities/installation/installer.lua`. The config itself is not baked: the
entrypoint links `~/.config/nvim` to `/workspace`, and `install.sh` (the host
installer) never enters the image. Host `~/.ssh` is mounted **read-only** at
`.ssh_host` and Herdr SSH publishes on `127.0.0.1:22035`. Coding CLIs
(Claude, Codex, Cursor, Grok, …) are **opt-in build args, default false**.
`entrypoint.sh` performs symlink surgery so CLI auth (`~/.claude*`, etc.)
survives container recreations via persistent volumes. `.env` files are
created 0600 from committed `.env.example` placeholders by `dev.sh`
(`ensure_env_from_examples`).

## Mesh

`bash dev.sh agents` lists Herdr machines/agents; `bash dev.sh ask <machine>
<pane> "prompt"` sends a prompt carrying the `[herdr-mesh]` grant stamp — the
receiver is authorized to reply now and must reply itself. A body that already
carries the stamp is a reply, not a question.

## Testing architecture

`tests/` is a Go module that **parses** mapping files (Lua and VimScript) and
asserts a three-flavor contract: `shared` mappings must exist in every flavor;
`current` adds Lua-only expectations; `vim-family` covers mini/VimScript. It
never starts Neovim — fast, deterministic, container-friendly. The root
`compose.yml` runs multi-distro installer smokes.

## Release flow

`.github/workflows/auto-release.yml`: push to `main` → resolve next semver from
commit prefixes (`feat:`/`fix:`/`perf:` bump minor; `BREAKING CHANGE` footer
bumps major; anything else patch) → tag + GitHub Release. `[skip release]` in
the merge body publishes nothing.

## DWP harness layer

`.agents/` carries the vendored skills (deepworkplan 6.0.2, ai-diff-reviewer,
dailybot), the thin `dwp-*` command delegators, agent personas, and the
catalog; `.claude`/`.cursor` are symlinks to it. Plan output lives in
gitignored `.dwp/`; scratch in gitignored `tmp/`.
