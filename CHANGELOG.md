# Changelog

All notable changes to DeepWorkPlan Vim are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases are cut by merging to `main` (`.github/workflows/auto-release.yml`,
see [CONTRIBUTING.md](CONTRIBUTING.md#releases)); each release's notes are its
section below, and its assets ship with `SHA256SUMS`. Pin by tag.

## [Unreleased]

## [v0.5.0] - 2026-10-09

### Added

- **Version selection, Dailybot-CLI style:** `--version` / `DWP_VIM_VERSION`
  take `X.Y.Z`, `vX.Y.Z`, `latest` (newest stable release) or `'>=X.Y.Z'`
  (newest stable release at or above the floor), resolved with
  `git ls-remote` and compared numerically (pre-releases ignored). Precedence:
  flags, `DWP_VIM_VERSION`, `DWP_VIM_REF`, the installer's own release; a
  version and a ref that disagree are an error; the resolved tag is printed;
  a missing version lists the newest releases.
- **Options** (also after `bash -s --` from a pipe), each with an env twin:
  `--version`, `--ref`, `--dir`, `--skip-packages`, `--strict`, `--nvim`,
  `--yes`, `-h/--help`; an unknown option prints the usage and exits 2.
- **Container mode** for images and CI —
  `bash install.sh --version 0.5.0 --nvim 0.12.5 --skip-packages --strict`
  replaces the clone + `install.lua` + headless sync + plugin-check block:
  - `--nvim X.Y.Z` installs the official Neovim tarball (Linux and macOS,
    x86_64 and arm64) into `~/.local`, verified against the sha256 Neovim
    publishes (release asset digest, else the `.sha256sum` asset); a
    mismatch or no checksum installs nothing. `GITHUB_TOKEN` authenticates
    the lookup.
  - `--strict` fails on a failed or timed-out headless plugin install and
    verifies the plugins (alpha-nvim, nvim-cmp, mason.nvim; no empty clone).
  - `--yes` moves a foreign config aside without a terminal; without it an
    unattended run still never touches one.
- Tests: installer harness 52 scenarios (+15); `tests/installer/container.sh`
  proves the one-liner in Debian as a non-root user without a terminal (CI
  job "Container install").

### Fixed

- The headless plugin install left every plugin as an empty clone in a fresh
  container while reporting success (pckr's autoinstall raced the explicit
  sync, and quitting killed its clones); a headless run now lets the sync do
  every install. The images' `test -d mason.nvim` check could not see this;
  `--strict` does.

### Changed

- The agent harness vendors DeepWorkPlan skill 7.0.1 (standard 7.0.0),
  verified file-by-file against the release `SHA256SUMS`; the addon
  registry is the tracked `.dwp/config.json` (plans stay local).

### Removed

- Unreferenced screenshots inherited from the original mu-vim tree
  (`.doc/`, `.examples/`).

## [v0.4.2] - 2026-10-09

### Fixed

- Updating an existing install no longer fails for installs cloned from
  the older `mu-vim` fork ("couldn't find remote ref"): the release is
  fetched from `DWP_VIM_SOURCE` or the DeepWorkPlan Vim repository, never
  from the checkout's own origin.

### Changed

- An existing install whose origin is another repository, or that has
  local edits to tracked files, is no longer switched in place. The
  installer names the situation and offers the consented path — move it
  to `~/.config/previous-deepworkplan-vim`, then install fresh — or how to
  keep it and update in place (only the steps that apply: point origin at
  the repository, stash the edits); without a terminal it stops and
  touches nothing. A checkout whose changes cannot be read stops too.
- Updates no longer follow the checkout's origin: an install kept in sync
  with a mirror (even one named `deepworkplan-vim`) sets `DWP_VIM_SOURCE`
  to that mirror for every update.

### Security

- URLs shown by the installer drop everything that can carry a credential
  (user-info, query, fragment); asking about local changes takes no index
  lock; the backup path is checked again right before the move, and a
  failure after the move says where the previous config is.
- The installer harness runs with git limited to the file protocol and no
  system gitconfig, so no scenario can depend on the network or the host
  (37 scenarios).

## [v0.4.1] - 2026-10-09

The installer the website publishes at `https://deepworkplan.com/vim/install.sh`,
and the repository's public-standard baseline.

### Fixed

- `install.sh` installs the release it belongs to (`RELEASE_REF`, v0.4.1)
  instead of the moving `main` branch; `DWP_VIM_REF=main` (or any tag,
  branch or commit) still overrides it. Updating to a tag checks it out
  detached and stops when the checkout holds local commits no remote branch
  or tag has.
- `DWP_VIM_SKIP_PACKAGES` works as documented: with `1` the preflight
  installs no system package (a missing git, curl or Lua stops the run) and
  `install.lua` skips its package step; `0` or empty means off in both.
- The installer header no longer claims that `/install.sh` redirects to
  `/vim/install.sh`.
- A run with the script piped into bash no longer lets `install.lua` read
  the rest of the script as answers: the script is parsed whole before it
  runs (`main`), `install.lua` reads the terminal or `/dev/null`, and the
  headless Neovim reads `/dev/null`.
- pnpm is installed with npm (`pnpm@10`); a missing npm is added with its
  own package-manager call, and a Node.js older than 18 stops with a clear
  message.
- Release workflow: only a commit footer line starting with
  `BREAKING CHANGE:` bumps the major version; prose that mentions the words
  no longer does.

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
- Release assets: the source archive, `install.sh`, `install.sh.sha256` and
  `surface.json` with `SHA256SUMS` (`scripts/release-assets.sh`), also
  attached to the existing releases.
- Installer harness: 31 scenarios (release-tag default, explicit `main`, tag
  updates, `DWP_VIM_SKIP_PACKAGES`, the pnpm fallback, the script read
  through a pipe); the hygiene check's `pipe-to-shell` rule.

### Changed

- Releases use annotated tags and take their notes from this file. A merge
  publishes only when `addon/surface.json` names a new version (others end
  with a notice), and is refused when that version, the computed bump and
  the CHANGELOG section disagree. Only `main` publishes; a re-run finishes a
  failed publish; manual dispatch defaults to a dry run and can cut a
  flagged pre-release.
- README follows the ecosystem layout. Every install instruction is
  download → verify (`install.sh.sha256`) → `bash install.sh`.
- `addon/surface.json` describes v0.4.1: the release asset URL, the
  `install.sh.sha256` file and `DWP_VIM_SKIP_PACKAGES`.

### Security

- No shipped text or code pipes a download into a shell: the installer's
  usage teaches download → verify → run, and the pnpm fallback installs
  pnpm with npm (user prefix) instead of piping a fetched script into `sh`
  (or `iex` on Windows). Piping the URL into bash still works and stays
  safe: without a terminal an existing config is never touched.
- The release tag is fetched into a private ref (a user's own tag of the
  same name is never rewritten); release tags are immutable on GitHub;
  `DWP_VIM_REF`/`DWP_VIM_SOURCE` values starting with `-` are refused.
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

[Unreleased]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.5.0...HEAD
[v0.5.0]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.4.2...v0.5.0
[v0.4.2]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.4.1...v0.4.2
[v0.4.1]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.4.0...v0.4.1
[v0.4.0]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.3.1...v0.4.0
[v0.3.1]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.3.0...v0.3.1
[v0.3.0]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.2.0...v0.3.0
[v0.2.0]: https://github.com/DailybotHQ/deepworkplan-vim/releases/tag/v0.2.0
