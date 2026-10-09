# Changelog

All notable changes to DeepWorkPlan Vim are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases are cut by merging to `main` (`.github/workflows/auto-release.yml`,
see [CONTRIBUTING.md](CONTRIBUTING.md#releases)); each release's notes are its
section below, and its assets ship with `SHA256SUMS`. Pin by tag.

## [Unreleased]

### Added

- `CONTRIBUTING.md`, `SECURITY.md` (private vulnerability reporting),
  `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), issue and pull request
  templates, `CODEOWNERS`.
- CI on every pull request and push to `main`: public hygiene, Lua parse and
  shell syntax, the smoke suite, the installer harness and the Go mapping
  contracts; Dependabot for GitHub Actions and the Docker base images.
- `scripts/check-public-hygiene.sh` with `.public-hygiene-allow` and a
  self-test (`tests/hygiene/run.sh`): blocks personal paths, private names
  and secret-shaped content in tracked files.
- Release assets: the source archive, `install.sh` and `surface.json` with
  `SHA256SUMS` (`scripts/release-assets.sh`), also attached to the existing
  releases.

### Changed

- Releases use annotated tags and take their notes from this file. A merge
  publishes only when `addon/surface.json` names a new version (others end
  with a notice), and is refused when that version, the computed bump and
  the CHANGELOG section disagree. Only `main` publishes; a re-run finishes a
  failed publish; manual dispatch defaults to a dry run and can cut a
  flagged pre-release.
- README follows the ecosystem layout; the install line is pinned to the tag.

### Security

- The release workflow no longer interpolates commit text into shell.
- Third-party GitHub Actions are pinned by commit SHA.

## [v0.4.0] - 2026-10-08

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
- The `INSTALL_CODEX_CLI`, `INSTALL_PI_CLI` and `INSTALL_CLINE_CLI` build
  args of the contributor image now install their CLIs.
- Contributor tooling reads only the neutral, optional `herdr-peers` SSH
  include.

### Fixed

- Installer UX audit: a diverged local `main` stops loudly instead of
  reporting success; updates honor `DWP_VIM_SOURCE`; mirror and fork clones
  are recognized by their contents; `realpath` works on BSD hosts; a
  failing setup leg ends with a paste-able handoff.
- Plan surfaces: CJK and long-URL wrapping in the reader, screen-width
  fitting in the sidebar and statusline, one vocabulary across all four
  surfaces.

### Security

- Installer: a consent question answered by end-of-input (a piped run)
  always takes the safe branch; the uninstaller never removes a foreign
  config.
- Contributor image: every tool pinned by version and verified by sha256
  (base image by digest, gh, Neovim, Herdr 0.9.3, the opt-in coding CLIs,
  pnpm, Biome); no vendor install script is piped to a shell. See
  `docker/local/README.md`.

### Upgrading

- Pin `DWP_VIM_REF=v0.4.0` (installer) or `git clone --branch v0.4.0`.
- Installs from v0.3.1 or earlier carry the legacy marker
  `~/.local/share/nvim/deepworkplan-vim-installed`; current installs write
  `~/.local/share/<appname>/pckr/.dwp-vim-bootstrapped` instead.

## [v0.3.1] - 2026-10-03

### Added

- DeepWorkPlan 6 onboarding of this repository: agent harness under
  `.agents/` with the `ai-diff-reviewer` and `dailybot` addons, docs set,
  and the local AI Diff Reviewer extension (`.review/extension.md`).

## [v0.3.0] - 2026-10-03

### Added

- Contributor environment: `dev.sh` creates missing `.env` files from
  their `.env.example` templates.

## [v0.2.0] - 2026-09-26

### Added

- First release under the DeepWorkPlan name: the Neovim configuration with
  a VS Code feel, `lua install.lua` / `lua delete.lua`, the command
  glossary (`SPC h h`), theme picker, LSP / completion / formatting stack,
  and the contributor container with the Herdr mesh. Derived from
  [mu-vim](https://github.com/AndresMpa/mu-vim) by Andrés M Prieto; GPL-3.0.

[Unreleased]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.4.0...HEAD
[v0.4.0]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.3.1...v0.4.0
[v0.3.1]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.3.0...v0.3.1
[v0.3.0]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.2.0...v0.3.0
[v0.2.0]: https://github.com/DailybotHQ/deepworkplan-vim/releases/tag/v0.2.0
