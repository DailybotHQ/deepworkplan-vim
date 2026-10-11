# DeepWorkPlan Vim

**The terminal editor for DeepWorkPlan: a Neovim configuration for people and
coding agents reviewing files, changes and plans in a terminal.**

[![CI](https://github.com/DailybotHQ/deepworkplan-vim/actions/workflows/ci.yml/badge.svg)](https://github.com/DailybotHQ/deepworkplan-vim/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/DailybotHQ/deepworkplan-vim)](https://github.com/DailybotHQ/deepworkplan-vim/releases)
[![License: GPL-3.0](https://img.shields.io/github/license/DailybotHQ/deepworkplan-vim)](./LICENSE)

When agents work across repositories and terminal panes, you need to inspect
what changed and see which plans and lanes need attention. DeepWorkPlan Vim
combines file navigation, Git diffs, a searchable command index and read-only
plan views in one editor. It works on its own; DeepWorkPlan and Herdr are optional.

## Install and quickstart

The current release is **v0.7.0**, for macOS, Linux or WSL, with
[Neovim 0.12+](https://github.com/neovim/neovim/wiki/Installing-Neovim).
Download the tag-pinned installer and release checksums, verify the installer,
then run it from a terminal:

```bash
curl -fsSL -o install.sh https://github.com/DailybotHQ/deepworkplan-vim/releases/download/v0.7.0/install.sh
curl -fsSL -o SHA256SUMS https://github.com/DailybotHQ/deepworkplan-vim/releases/download/v0.7.0/SHA256SUMS
awk '$2 == "install.sh" { print }' SHA256SUMS | shasum -a 256 -c -
bash install.sh --version 0.7.0
nvim
```

The verification prints `install.sh: OK`. On Linux, `sha256sum -c -` can replace
`shasum -a 256 -c -`. Stop if verification fails. The
[release assets](https://github.com/DailybotHQ/deepworkplan-vim/releases/tag/v0.7.0)
also include `install.sh.sha256`, `surface.json` and the source archive.
The website's [installer mirror](https://deepworkplan.com/vim/install.sh) is usable
when its checksum matches the pinned release.

The installer preflights git, curl and Lua, clones the configuration to
`~/.config/nvim`, runs system setup and installs the pinned plugins headlessly.
It asks before moving an existing foreign configuration to
`~/.config/previous-deepworkplan-vim`; without a terminal it stops unless backup
is explicitly authorized with `--yes`. Local edits are preserved through that
backup path rather than overwritten. Rerunning updates an existing installation.

For an image or CI environment that already provides git, curl, Lua, a C compiler,
Node.js and pnpm, run the verified installer as a non-root user:

```bash
bash install.sh --version 0.7.0 --nvim 0.12.5 --skip-packages --strict
```

This installs checksum-verified Neovim into `~/.local/opt`, links it under
`~/.local/bin` and fails on incomplete or unpinned plugin installations. Put
`~/.local/bin` on PATH. `bash install.sh --help` lists version selection, offline
sources and all other options; [development commands](docs/DEVELOPMENT_COMMANDS.md)
cover the contributor container and mesh.

On Windows, install Neovim with `winget install -e --id Neovim.Neovim`, then use
Git Bash with git and Lua on PATH:

```bash
git clone --branch v0.7.0 https://github.com/DailybotHQ/deepworkplan-vim.git "$LOCALAPPDATA/nvim"
cd "$LOCALAPPDATA/nvim" && lua install.lua
nvim
```

For a manual Unix install, clone the same tag into `~/.config/nvim` and run
`lua install.lua` there. To uninstall, run `lua ~/.config/nvim/delete.lua`
(Windows: `lua "$LOCALAPPDATA/nvim/delete.lua"` in Git Bash). It lists the paths
and asks before removal; Neovim itself stays installed.

## Core usage

`SPC` means the leader key, Space by default. Start with `SPC h h`:
its searchable command index is generated from the live mappings.

| Action | Keys or command | What you see |
| --- | --- | --- |
| Find files | `SPC f f` / `SPC n` | A file finder or the file tree. |
| Review changes | `SPC g d` | A side-by-side Git diff; repeat to close it. |
| Browse plans | `SPC P` / `:DwpPlans` | Plans grouped by status with progress; Enter opens the plan reader and Tab expands tasks and files. |
| Inspect the orchestra | `SPC O` / `:DwpLanes`, or `L` on a plan in the browser | Recorded lanes and child plans with optional live peer state. |
| Preview Markdown | `SPC m p` / `SPC m r` | A browser preview or rendered Markdown in the buffer. |
| Discover commands | `SPC h h` / `:DwpCommands` | Every live mapping, grouped and searchable. |

The plan browser reads `.dwp/plans` in the current repository and the editor's
configuration directory. The reader explains the goal, task checklist and plan
files; the statusline and start screen also expose plan progress. These surfaces
never write your plans. Clipboard shortcuts include `Ctrl-a` to select all and
`SPC y` to copy in normal or visual mode.

### Orchestra lanes in v0.7.0

The lanes view reads `ORCHESTRATOR_MANIFEST.md` and README lane/child-plan tables,
with manifest fields taking precedence. It shows repository, peer address,
account, branch, child plan, recorded status and dependencies when present.
For example, a recorded lane with no helper installed appears as:

```text
Orchestra — Example plan

Live status unavailable: herdr-peers is not installed.

vim · unavailable
  Repository: deepworkplan-vim
  Peer: local:w1:p2
  Branch: feat/example

r refresh · q / Esc close · read-only
```

With `herdr-peers` on PATH, the editor asynchronously runs the read-only
`herdr-peers lanes --json` command and accepts `herdr-peers/lanes-v1`, protocol 1.
Matching peer addresses gain a timestamped snapshot: `working`, `idle`,
`blocked`, `done`, `unknown`, `no_agent` or `unreachable`, plus agent/profile,
attention screen and open ask count. `r` refreshes disk and live status;
`q` / `Esc` closes the view. Missing helpers, timeouts and unsupported JSON keep
recorded lanes visible with explicit unavailable status. This is a snapshot,
not continuous monitoring. [View contract and keys](docs/PLANS_SIDEBAR.md#orchestra-lanes).

## How it fits with DeepWorkPlan

The optional [vim addon](https://deepworkplan.com/kit/vim) installs or detects this
editor using its tag-pinned, machine-readable [addon surface](addon/surface.json).
The [DeepWorkPlan pack](https://github.com/DailybotHQ/deepworkplan-skill) manages
repository onboarding and durable plans; the editor lets a person or agent read
those plans and review the resulting changes.

[herdr-peers](https://deepworkplan.com/kit/herdr) supplies optional lane snapshots;
[coding-agents-kit](https://deepworkplan.com/kit/agentkit) manages the coding agents
and their profiles; [devcontainer-kit](https://deepworkplan.com/kit/devcontainer)
provides a container environment for the tools. The lanes view displays recorded
accounts and optional runtime profiles; it does not launch agents, pick accounts,
send messages or change child repositories. Adoption starts at
[the quickstart](https://deepworkplan.com/quickstart).

## Part of the DeepWorkPlan ecosystem

[DeepWorkPlan](https://deepworkplan.com) turns any repository into an AI-first,
agent-pilotable codebase. These projects ship together; every addon is optional.

| Project | Role | What it does |
| --- | --- | --- |
| [deepworkplan-skill](https://github.com/DailybotHQ/deepworkplan-skill) | Pack | The methodology, specification and kit as an installable agent skill; onboards a repository and installs or upgrades every addon. |
| [coding-agents-kit](https://github.com/DailybotHQ/coding-agents-kit) | Addon | `ak`: installs coding-agent CLIs, manages accounts and profiles, shows usage and picks the account with the most headroom. |
| [devcontainer-kit](https://github.com/DailybotHQ/devcontainer-kit) | Addon | `dck`: renders an agent-ready development container with the host's accounts, Herdr and the agent mesh. |
| [herdr-peers](https://github.com/DailybotHQ/herdr-peers) | Addon | Ask/reply messaging and lane status between agents across panes, machines and containers. |
| [deepworkplan-vim](https://github.com/DailybotHQ/deepworkplan-vim) (this repository) | Addon | A Neovim distribution with a plan reader, sidebar and lanes view. |
| [ai-diff-reviewer](https://github.com/DailybotHQ/ai-diff-reviewer) | Addon | The local and CI pull-request reviewer behind the `Ready` label. |
| [agent-skill](https://github.com/DailybotHQ/agent-skill) | Addon | The Dailybot agent skill: standup-style progress reports from agents. |
| [deepworkplan.com](https://github.com/DailybotHQ/deepworkplan-website) | Site and hub | The documentation site, `/init.md` and `/quickstart`, and the hub that coordinates these releases. |

## Security and trust

Verify release assets before execution. The installer can install system
prerequisites and run plugin setup; read it before granting those actions.
Plugins and pckr are pinned by commit in [the lockfile](pckr/lockfile.lua);
Mason language servers and Treesitter parsers are fetched at runtime and are not
covered by that lock. Keep credentials outside committed configuration and plans.
Plan and lane views are read-only, and live lookup uses a fixed command with a
three-second timeout. The contributor container publishes SSH on loopback and
mounts host SSH files read-only. Report vulnerabilities privately through
[SECURITY.md](SECURITY.md); the [security guide](docs/SECURITY.md) covers the details.

## Documentation and contributing

| Topic | Guide |
| --- | --- |
| Product scope and editor capabilities | [Product specification](docs/PRODUCT_SPEC.md) |
| Boot chain, modules and releases | [Architecture](docs/ARCHITECTURE.md) |
| Installation, container, mesh and validation commands | [Development commands](docs/DEVELOPMENT_COMMANDS.md) |
| Plans and orchestra view | [Plans sidebar](docs/PLANS_SIDEBAR.md) |
| Plugins and language tools | [Plugin guide](docs/PLUGINS.md) |
| Sidebar settings and user overrides | [Configuration](docs/CONFIGURATION.md) |
| Key reference | [Cheat sheet](CheatSheet.md) |
| Addon integration contract | [Addon guide](addon/README.md) |
| Contributor container | [Container guide](docker/README.md), [local image](docker/local/README.md) |
| Tests and required gates | [Testing guide](docs/TESTING_GUIDE.md) |
| Agent instructions | [AGENTS.md](AGENTS.md) |

Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, gates and the pull-request
process, and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community expectations.
[CHANGELOG.md](CHANGELOG.md) records each release. Merges publish a new release
only when the tree declares a new version; this README update keeps v0.7.0.

## License

[GPL-3.0](LICENSE). Derived from
[AndresMpa/mu-vim](https://github.com/AndresMpa/mu-vim) by Andrés M Prieto;
[CREDITS.md](CREDITS.md) preserves the lineage. Keep the license and credit in
copies and derivatives.
