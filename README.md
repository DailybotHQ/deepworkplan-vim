# DeepWorkPlan Vim

**DeepWorkPlan's editor** — a Neovim configuration with a VS Code feel, fast to start, built for humans and for the coding agents that live in a terminal.

[![CI](https://github.com/DailybotHQ/deepworkplan-vim/actions/workflows/ci.yml/badge.svg)](https://github.com/DailybotHQ/deepworkplan-vim/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/DailybotHQ/deepworkplan-vim)](https://github.com/DailybotHQ/deepworkplan-vim/releases)
[![License: GPL-3.0](https://img.shields.io/github/license/DailybotHQ/deepworkplan-vim)](./LICENSE)

## What it is

The terminal editor for [Deep Work Plan](https://deepworkplan.com): one
curated Neovim configuration (not a framework or a distro) for people and
agents working in a terminal, including Herdr panes. It is derived from
[AndresMpa/mu-vim](https://github.com/AndresMpa/mu-vim) (see
[CREDITS.md](./CREDITS.md)); new work lands here under the DeepWorkPlan name.

> **Optional, never required.** DeepWorkPlan v7 offers this editor as its optional `vim` addon during onboarding, pinned by tag. The methodology works with any editor (or none), and this editor works on its own — nothing here installs or requires the DeepWorkPlan skill.

Five features, each one keystroke away:

| Feature | Key | What it does |
|---|---|---|
| Command index | `SPC h h` | Every mapping in this config, generated live from the actual keymaps — always accurate, grouped, searchable. This is the product tour. |
| VS Code gestures | `<C-a>` · `SPC y` | Select all in one key (`<C-a>`); yank to the system clipboard (`SPC y`, works in visual mode too). |
| Plan browser | `SPC P` · click | Browse every Deep Work Plan under the current repo or config in a sidebar grouped by status (Working, Needs attention, Ready, Not started, Done) with progress bars and percent; Enter opens a plain-language reader for one plan; the statusline shows the live active plan (click it for the sidebar) and the dashboard lists the top three. Read-only. |
| Markdown viewer | `SPC m p` · `SPC m r` | Preview in the browser (`p`) or render in the buffer (`r`) — the same implementation `SPC x` uses to run files. |
| One-line installer | — | Preflight, clone, system setup, plugins — headless, consent-first. |

`SPC` is the leader (`Space` by default). `:DwpCommands` and `:DwpPlans`
are the terminal-independent entry points for the two panels. Also
included: `lua install.lua` / `lua delete.lua`, and an optional
contributor container with the Herdr mesh.

For integrators: [`addon/surface.json`](addon/surface.json) is the
machine-readable surface the DeepWorkPlan `vim` addon reads — interface
version, detection, the tag-pinned install path with the installer's
sha256, the read-only plan reader, and the features this tag ships
([`addon/README.md`](addon/README.md) explains it).

## Install

Release **v0.5.0** — macOS, Linux or WSL; requires
[Neovim](https://github.com/neovim/neovim/wiki/Installing-Neovim) 0.12+.
Download the installer, verify it, then run it from a terminal:

```bash
curl -fsSL -o install.sh https://deepworkplan.com/vim/install.sh
curl -fsSL -o install.sh.sha256 https://deepworkplan.com/vim/install.sh.sha256
shasum -a 256 -c install.sh.sha256      # Linux: sha256sum -c install.sh.sha256
bash install.sh
```

The same two files are assets of the
[GitHub release](https://github.com/DailybotHQ/deepworkplan-vim/releases/tag/v0.5.0)
(with `SHA256SUMS` for every asset) — comparing the website's copy with the
release's `SHA256SUMS` checks it against a second origin; release tags are
immutable:

```bash
curl -fsSL -o install.sh https://github.com/DailybotHQ/deepworkplan-vim/releases/download/v0.5.0/install.sh
curl -fsSL -o install.sh.sha256 https://github.com/DailybotHQ/deepworkplan-vim/releases/download/v0.5.0/install.sh.sha256
shasum -a 256 -c install.sh.sha256      # Linux: sha256sum -c install.sh.sha256
bash install.sh
```

That is the whole install: preflight (installs git, curl and Lua if they
are missing), clone into `~/.config/nvim`, the system setup
(`lua install.lua`), and a headless plugin install — no quit-and-reopen
dance. The installer installs **the release it belongs to** (v0.5.0);
`DWP_VIM_REF=main bash install.sh` follows the moving `main` branch instead.
An existing Neovim config is **never overwritten**: you are asked before it
is moved to `~/.config/previous-deepworkplan-vim`, and a run without a
terminal stops and leaves it untouched (missing git, curl or Lua may already
have been installed by the preflight). Rerunning a newer installer updates
an existing install from the DeepWorkPlan Vim repository; an install that
tracks another repository (such as the older `mu-vim` fork) or has local
edits is never changed in place — you are offered the same backup and a
fresh install, or told how to keep it.

Choose a version like the Dailybot CLI installer does — a flag (also after
`bash -s --` when the script arrives on stdin) or its environment twin:

```bash
bash install.sh --version 0.5.0          # or v0.5.0;  env: DWP_VIM_VERSION=0.5.0
bash install.sh --version latest         # newest stable release
bash install.sh --version '>=0.5.0'      # newest stable release at or above the floor
bash install.sh --help                   # every option and its env twin
```

Precedence: a flag beats every environment value; then `DWP_VIM_VERSION`,
then `DWP_VIM_REF`, then the installer's own release. A version and a ref
given at the same level (two flags, or two env values) that disagree are an
error, and a version that does not exist lists the newest releases. Switch
values are `1/true/yes/on` or `0/false/no/off` (any case).

**Docker images and CI** — the container mode replaces the clone +
`install.lua` + headless sync + plugin-check block with one step. It runs as
a non-root user without a terminal, installs Neovim from the official
release tarball (sha256-verified, into `~/.local/opt/nvim-vX.Y.Z`, linked as
`~/.local/bin/nvim`), installs no system package (the image
already has git, curl, Lua, a C compiler, Node.js and pnpm), and fails the
build when the plugins did not install:

```dockerfile
USER dev
RUN curl -fsSL -o /tmp/install.sh https://github.com/DailybotHQ/deepworkplan-vim/releases/download/v0.5.0/install.sh \
 && curl -fsSL -o /tmp/install.sh.sha256 https://github.com/DailybotHQ/deepworkplan-vim/releases/download/v0.5.0/install.sh.sha256 \
 && (cd /tmp && sha256sum -c install.sh.sha256) \
 && bash /tmp/install.sh --version 0.5.0 --nvim 0.12.5 --skip-packages --strict
ENV PATH="/home/dev/.local/bin:${PATH}"
```

`--yes` lets an unattended run move an existing foreign config aside;
without it such a run never touches one. Set `GITHUB_TOKEN` in CI to
authenticate the Neovim release lookup (GitHub rate-limits anonymous calls).

Offline and manual:

```bash
DWP_VIM_SOURCE=/path/to/deepworkplan-vim bash install.sh   # local/offline source or mirror — set it for every update too
git clone --branch v0.5.0 https://github.com/DailybotHQ/deepworkplan-vim.git ~/.config/nvim   # manual
cd ~/.config/nvim && lua install.lua
```

Integrations read the same steps, URL and sha256 from
[`addon/surface.json`](addon/surface.json) (`install.script`, `install.steps`).

Windows: use winget plus Git Bash, or run the steps above inside WSL,
where they work as-is:

```bash
winget install -e --id Neovim.Neovim --accept-package-agreements --accept-source-agreements
git clone --branch v0.5.0 https://github.com/DailybotHQ/deepworkplan-vim.git "$LOCALAPPDATA/nvim"
cd "$LOCALAPPDATA/nvim" && lua install.lua
```

Run the last two lines in Git Bash (which provides `git`); `lua` must be on
PATH. A one-line Windows installer is on the roadmap.

**Remove** — it lists every path it will touch and asks before removing
anything; Neovim itself stays installed:

```bash
lua ~/.config/nvim/delete.lua              # Git Bash on Windows: lua "$LOCALAPPDATA/nvim/delete.lua"
```

## Quickstart

1. Download, verify and run the installer above.
2. Launch `nvim`.
3. Press `Space h h` — the command index is the tour: every row names its
   key and what it does.
4. In a repository with Deep Work Plans, press `Space P` for the plan
   browser.

## Documentation

| Topic | Where |
|---|---|
| What the editor is and is not | [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md) |
| Boot chain, modules, container, release flow | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Every command (install, container, gates, release) | [docs/DEVELOPMENT_COMMANDS.md](docs/DEVELOPMENT_COMMANDS.md) |
| Tests and gates | [docs/TESTING_GUIDE.md](docs/TESTING_GUIDE.md) |
| Key cheat sheet | [CheatSheet.md](CheatSheet.md) |
| Addon surface for integrators | [addon/README.md](addon/README.md) |
| Contributor container (Docker + Herdr mesh) | [docker/README.md](docker/README.md), [docker/local/README.md](docker/local/README.md) |
| What each release ships | [CHANGELOG.md](CHANGELOG.md) |
| Agent entry point | [AGENTS.md](AGENTS.md) |

Contributor environment in four lines (the image installs the editor with the
DeepWorkPlan Vim installer — Neovim 0.12.5, plugins verified — plus Herdr;
coding CLIs opt-in):

```bash
cp docker/local/dwpvim/.env.example docker/local/dwpvim/.env
bash dev.sh build && bash dev.sh up
bash dev.sh shell
bash dev.sh agents    # list Herdr agents across machines
```

## Security

Please report vulnerabilities privately — see [SECURITY.md](SECURITY.md).
Never open a public issue for a security problem. The installer, the
contributor container's SSH surface and the release workflow are the
sensitive surfaces; [docs/SECURITY.md](docs/SECURITY.md) documents how they
are kept safe, and every pull request runs a public-hygiene check that
blocks private context and secret-shaped content.

## Contributing

Contributions are welcome — read [CONTRIBUTING.md](CONTRIBUTING.md) (setup,
the gate command, Conventional Commits, the PR and release flow) and the
[Code of Conduct](CODE_OF_CONDUCT.md). Merging to `main` publishes a release
only when the PR describes one; [CHANGELOG.md](CHANGELOG.md) records what
each tag ships, and every release carries `SHA256SUMS`.

## License

[GPL-3.0](./LICENSE). Derived from
[AndresMpa/mu-vim](https://github.com/AndresMpa/mu-vim) by Andrés M Prieto —
see [CREDITS.md](./CREDITS.md). Keep the license and the credit in every
copy and derivative.

---

Part of the [DeepWorkPlan](https://deepworkplan.com) ecosystem — works on its own.
