# Changelog

All notable changes to DeepWorkPlan Vim. Releases are cut by merging to
`main` (`.github/workflows/auto-release.yml`); versions follow the
conventional-commit bump rules described in the README. Pin by tag.

## v0.4.0 — 2026-10-08

The first release that ships the full DeepWorkPlan editor surface, and the
version the DeepWorkPlan v7 `vim` addon pins. Everything below was on `main`
only until this tag.

### Added

- **Command index** `SPC h h` / `:DwpCommands`, generated live from the
  actual keymaps — grouped, searchable, never out of date.
- **VS Code gestures**: `<C-a>` selects all; `SPC y` yanks to the system
  clipboard in normal and visual mode.
- **Plan browser** `SPC P` / `:DwpPlans`: a sidebar of every Deep Work Plan
  under the working directory and the config directory, grouped by status
  with progress bars and percent; Enter opens a plain-language reader; a
  clickable statusline segment shows the active plan; the dashboard lists
  the top three. Read-only — nothing under `.dwp/` is ever written.
- **Markdown viewer**: `SPC m p` previews in the browser, `SPC m r` renders
  in the buffer.
- **One-line installer** `install.sh`: preflight, clone, system setup and a
  headless plugin install. An existing Neovim config is moved aside only
  after an interactive yes; without a terminal the run aborts and leaves
  the existing config untouched. `DWP_VIM_REF`, `DWP_VIM_SOURCE`, `DWP_VIM_DIR` and
  `DWP_VIM_SKIP_PACKAGES` cover pinned, offline, custom-directory and
  image installs.
- **Addon surface** `addon/surface.json` (interface 1): read-only
  detection, the tag-pinned install path with the installer's sha256, the
  read-only plan reader and the features of this tag — the contract the
  DeepWorkPlan `vim` addon reads ([`addon/README.md`](addon/README.md)).
- Host-runnable test layers: the `lua/dwp` smoke suite (headless Neovim,
  561 assertions including the addon surface and `lua/dwp`
  self-containment) and the installer compatibility harness (21 scenarios
  over the real `install.sh`; runs on Linux and macOS, from any branch).

### Changed

- Positioning: DeepWorkPlan's editor, offered as the optional `vim` addon
  of DeepWorkPlan v7 — never required, and never requiring DeepWorkPlan.
- First launch is ready: no phantom plugin sync eating keystrokes; the
  contributor image bakes plugins, pnpm, Biome and the font.
- Contributor image: every tool pinned by version and verified by sha256
  (base image by digest, gh, Neovim, Herdr 0.9.3, the opt-in coding CLIs,
  pnpm, Biome); no vendor install script is piped to a shell; the
  `INSTALL_CODEX_CLI`, `INSTALL_PI_CLI` and `INSTALL_CLINE_CLI` build args
  now install their CLIs. See `docker/local/README.md`.
- Contributor tooling reads only the neutral, optional `herdr-peers` SSH
  include.

### Fixed

- Installer safety and UX audit: consent EOF resolves to the safe branch on
  every path; a diverged local `main` stops loudly instead of reporting
  success; updates honor `DWP_VIM_SOURCE`; mirror and fork clones are
  recognized by their contents; the uninstaller never removes a foreign
  config; `realpath` works on BSD hosts; a failing setup leg ends with a
  paste-able handoff.
- Plan surfaces: CJK and long-URL wrapping in the reader, screen-width
  fitting in the sidebar and statusline, one vocabulary across all four
  surfaces.

### Upgrading

- Pin `DWP_VIM_REF=v0.4.0` (installer) or `git clone --branch v0.4.0`.
- Installs from v0.3.1 or earlier carry the legacy marker
  `~/.local/share/nvim/deepworkplan-vim-installed`; current installs write
  `~/.local/share/<appname>/pckr/.dwp-vim-bootstrapped` instead.

## v0.3.1 — 2026-10-03

- DeepWorkPlan 6 onboarding of this repository: agent harness under
  `.agents/` with the `ai-diff-reviewer` and `dailybot` addons, docs set,
  and the local AI Diff Reviewer extension (`.review/extension.md`).

## v0.3.0 — 2026-10-03

- Contributor environment: `dev.sh` creates missing `.env` files from
  their `.env.example` templates.

## v0.2.0 — 2026-09-26

- First release under the DeepWorkPlan name: the Neovim configuration with
  a VS Code feel, `lua install.lua` / `lua delete.lua`, the command
  glossary (`SPC h h`), theme picker, LSP / completion / formatting stack,
  and the contributor container with the Herdr mesh. Derived from
  [mu-vim](https://github.com/AndresMpa/mu-vim) by Andrés M Prieto; GPL-3.0.
