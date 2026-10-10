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
  ├─ require('userconfig')    lua/userconfig.lua    dwpvim.json -> sidebar side/width (vim.g for lua/dwp)
  ├─ require('mapping')       lua/mapping/init.lua  keybindings (contract-tested)
  ├─ require('autocommand')   lua/autocommand.lua   autocmds
  ├─ require('plugins')       lua/plugins.lua       pckr.nvim bootstrap at its pin, then
  │                                                 lua/plugin_specs.lua (the list) pinned
  │                                                 by lua/plugin_lock.lua from
  │                                                 pckr/lockfile.lua (commit per plugin)
  └─ require('composition')   lua/composition.lua   wires the plugin set-up below
        ├─ lua/setUp/*        greeter, finder, statusline, file manager, autosave, …
        ├─ lua/lsp/*          lspconfig/mason servers (npm_guard keeps Mason's npm real), formatters, completion
        └─ lua/scheme/*       theme apply/picker + curated palettes (lua/scheme/palettes/)
```

pckr.nvim is bootstrapped on first launch (cloned into stdpath data); plugin
updates flow through pckr, not through this repo's git.

## Module map

```
lua/                 the editor config (see lua/README.md)
lua/setUp/sidebars.lua  one sidebar at a time: closes the file tree when the plans open and back (events)
lua/userconfig.lua   dwpvim.json (editor dir) + .dwpvim.json (project): merge, validate, :DwpConfig
lua/dwp/             plan surfaces (see lua/README.md): plans (discovery),
                     state (machine states + rich plain-language model),
                     sidebar (SPC P), reader (Enter on a plan),
                     statusline (clickable active-plan segment),
                     greeter_plans (dashboard top-3 overview)
                     (sidebar/reader/statusline lazy — mapping and click
                     callbacks require them on first use; plans/state/
                     greeter_plans load when the dashboard first DRAWS,
                     not at boot — alpha starts on VimEnter and the
                     overview builds on first draw, so non-dashboard
                     boots never pay the scan: PLAN_003's probe reads
                     −12.7 ms vs the pre-Phase-2 baseline, i.e. faster
                     than before the UI existed)
utilities/           installer modules + snippet getters + spelling helpers
docker/              contributor container (docker/local/) + image custom commands
tests/               Go mapping-contract suite (parses Lua/VimScript; no Neovim)
                     + smoke suite (tests/smoke/: host-runnable headless
                     nvim over fixtures — model, sidebar, reader,
                     statusline, greeter, render/consistency proofs,
                     lua/dwp self-containment, addon surface)
addon/               surface.json: machine-readable addon surface (interface 1,
                     version, detection, tag-pinned install + sha256, read-only
                     plan reader, shipped features) — read by the DWP `vim`
                     addon; addon/README.md explains it
snippets/ dicts/     data: snippet sources, spell dictionaries
dev.sh               launcher: compose up/down/shell/build/rebuild + herdr agents/ask
install.sh           downloadable entry (pins its release tag): preflight, consent, clone/update, then lua
                     install.lua + headless plugin bootstrap (thin wrapper)
install.lua          multi-distro installer (runs on user machines, sudo for packages)
delete.lua           uninstaller
```

## Capability map

The [product focus](PRODUCT_SPEC.md#product-focus) has six pillars; this is
where each one lives and what guards it. A change to a module on the right is
checked by the test on the right.

| Pillar | Modules and plugins | Guarded by |
|---|---|---|
| Navigate | `nvim-tree` (`SPC n`, `lua/setUp/fileManager.lua`), `telescope` (`lua/setUp/finder.lua`, `SPC t…`), the dashboard shortcuts (`lua/setUp/greeter*.lua`) | Go mapping contracts (`tests/contract.go`); `scripts/boot-check.sh` loads the modules |
| See what changed | nvim-tree git marks, `vim-signify` margin signs, `vim-fugitive` (`SPC g s`), the diff panel's file list | boot check (plugins load); no hermetic test of the git state |
| Review the diff | `diffview.nvim` (`SPC g d`, `lua/setUp/diff.lua`), `vim-fugitive` blame and show | boot check; `lua/setUp/diff.lua` loads only when the plugin does |
| Approve or discard | diffview panel (stage; `d` or right-click discards a file after a confirmation), `SPC g a p` stage a file by hunks, `SPC g a a`, `SPC g c` | Go mapping contracts for the chords; the confirmation lives in `lua/setUp/diff.lua` |
| Agent-first | the pinned mapping contract, the command index (`lua/mapping/glossary.lua`, `SPC h h`), the contributor container and Herdr mesh (`dev.sh`), the headless smoke suite | `tests/` (Go contracts), `tests/smoke/` |
| Deep Work Plan in view | `lua/dwp/` (plans, state, sidebar, reader, statusline, greeter overview) — self-contained, no plugin required | `tests/smoke/dwp_*.lua`, incl. the self-contained and consistency smokes |
| Lightweight | the pinned plugin set (`lua/plugin_specs.lua`, `pckr/lockfile.lua`), `vim.loader` in `init.lua`, deferred setup | `tests/smoke/plugin_lock.lua`, `tests/smoke/plugin_refs.lua`, the startup numbers recorded in the plans |
| Tested and reviewed | `.github/workflows/ci.yml` and its `gate` job; pull-request-only flow | CI on every pull request; see [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) |

Dependency rule: `lua/dwp/` requires only `dwp.*` (the extraction boundary,
proven by `dwp_self_contained.lua`), and the editor reaches it lazily — the
plan surfaces never make a plugin a requirement, and no plugin makes the plan
surfaces fail.

## Contributor environment (feature area)

`docker/local/docker-compose.yaml` builds the `dwpvim` image: Herdr, user
`dev` (uid 1000), workdir `/workspace` mounted over `~/.config/nvim`, and the
editor installed the way every ecosystem image installs it — the hosted
DeepWorkPlan Vim installer (downloaded, verified against the release's
`install.sh.sha256`, run as `dev` with `--version 0.5.0 --nvim 0.12.5
--skip-packages --strict`): Neovim in `~/.local/opt`, the release config in
`~/.config/nvim`, pckr + the Iosevka Nerd Font, and a verified headless plugin
sync. pnpm + biome (user prefix, `PNPM_HOME`) come first because the plugins
build with pnpm. At start the entrypoint links `~/.config/nvim` to
`/workspace`, so contributors run the working tree; the baked release config
is the standalone fallback. Host `~/.ssh` is mounted **read-only** at
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

`tests/smoke/` is the complementary **runtime** suite: headless Neovim
(`bash tests/smoke/run.sh`, bash + nvim only, no container) over
committed synthetic plans — the model, each surface, what actually
lands on the **screen grid** (`dwp_render.lua`, `vim.fn.screenstring`),
and cross-surface consistency (`dwp_consistency.lua`: one record must
tell the same story in sidebar, reader, statusline and greeter).

## Release flow

`.github/workflows/auto-release.yml`: push to `main` → no-op (notice) while
`addon/surface.json` names a released version → otherwise resolve next semver from
commit prefixes (SemVer: `feat:` bumps minor; `fix:`/`perf:`/anything else
patch; `BREAKING CHANGE` footer or `!:` major) → refuse unless `addon/surface.json` names
that tag and `CHANGELOG.md` has its `## [vX.Y.Z]` section → annotated tag →
GitHub Release whose notes are that CHANGELOG section, with the source
archive, `install.sh`, `surface.json` and `SHA256SUMS` attached
(`scripts/release-notes.sh`, `scripts/release-assets.sh`). `[skip release]`
in the merge body publishes nothing; `workflow_dispatch` defaults to a dry
run (assets as a workflow artifact) and cuts pre-releases by suffix.

## CI

`.github/workflows/ci.yml`, on every pull request and push to `main`: public
hygiene (+ its self-test), lint (`luac5.4 -p`, `bash -n`), the smoke suite
(Neovim pinned by version and sha256), the installer harness, and the Go
mapping contracts, and the container install (which also runs `scripts/boot-check.sh`
on the installed config). A final `gate` job needs all of them and fails unless each
succeeded; it is the one check branch protection requires
([BRANCH_PROTECTION.md](BRANCH_PROTECTION.md)).

## DWP harness layer

`.agents/` carries the vendored skills (deepworkplan 7.0.1, ai-diff-reviewer,
dailybot), the thin `dwp-*` command delegators, agent personas, and the
catalog; `.claude`/`.cursor` are symlinks to it. Plan output lives in
`.dwp/`, gitignored except the tracked addon registry `.dwp/config.json`
(DWP v7 CONFIG §1); scratch in gitignored `tmp/`.
