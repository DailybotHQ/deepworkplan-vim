# Changelog

All notable changes to DeepWorkPlan Vim are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Releases are cut by merging to `main` (`.github/workflows/auto-release.yml`,
see [CONTRIBUTING.md](CONTRIBUTING.md#releases)); each release's notes are its
section below, and its assets ship with `SHA256SUMS`. Pin by tag.

## [Unreleased]

## [v0.6.0] - 2026-10-10

### Changed

- **The plans sidebar and the file tree toggle for each other.** Opening one closes
  the other (`sidebars.exclusive` in `dwpvim.json`, on by default).
- **The plan reader closes with the plans sidebar.** Switching to the file tree (or
  closing the plans) now hides the plan being read too, and the window gets back the
  file it was showing, instead of leaving an orphan reader beside the tree.
- **Plan clicks route by the window under the pointer.** A mapped `<LeftMouse>` is
  resolved against the focused buffer, so with the reader focused a click on the
  sidebar was ignored; the double-click fell through to Vim's word selection.
  `dwp.mouse` now decides every click by the pointer's window, the sidebar keeps
  the focus after opening a plan, and a second plan replaces the reader instead of
  the sidebar.
- **The plans sidebar reacts to the mouse and the keyboard jumps between plans.** A
  click opens the plan under the pointer (a mapped `<LeftMouse>` does not move the
  cursor, so clicks used to act on the wrong row), the small arrow shows its tasks,
  and `j`/`k`, the arrows and `Ctrl-n`/`Ctrl-p` move from plan to plan, skipping
  blanks and decoration. The reader window is as quiet as the sidebar, and its
  clicks open the file under the pointer.
- **A clearer plans sidebar.** The window is quiet (no dots for spaces or arrows at
  line ends, a fixed width, editing keys do nothing instead of printing `E21`); the
  list has a hierarchy — a header with a summary, sections with their counts,
  status colours on the icon and the bar, strong titles for live plans and dim ones
  for settled plans, thin rules, titles that use a wider window — and a long Done
  group opens collapsed. See `docs/PLANS_SIDEBAR.md`.

- **The file tree opens on the left**, like the plans sidebar, and is 40 columns
  wide (it still shrinks to its content). It used to open on the right at 60.
- **Both sidebars are configurable from a file.** `dwpvim.json` in the repository
  sets `tree.side`, `tree.width`, `plans.side` and `plans.width`; a
  `.dwpvim.json` in a project overrides it for that project. Invalid values are
  ignored and reported by the new `:DwpConfig`, which also shows where each value
  came from. See `docs/CONFIGURATION.md`.

### Removed

- **nvim-lint**: no linter was ever configured, so it did nothing (its
  lock entry and `lua/lsp/linter.lua` go with it).
- **The prettier formatter entries** (html, markdown, scss, less, yaml,
  svelte, vue, angular): nothing installed prettier. `:Format` keeps biome
  (JS/TS/JSON/CSS/GraphQL), black, shfmt and stylua.
- **Eleven Mason servers** nobody asked for: efm and diagnosticls (no
  configuration in this repository), tailwindcss, grammarly and bashls
  (installed but never started), and the servers for astro, svelte, Vue 2
  (vuels), Angular, SQL and Vim script. Fewer plugins to pin and fewer
  packages to install and update at first start.

### Fixed

- **Language servers no longer fail to install behind an `npm` that is not
  npm.** Some environments put a script named `npm` first on PATH that
  forwards to pnpm; Mason runs `npm init --scope=mason`, pnpm rejects the
  flag, and 16 npm-based servers (astro, svelte, vuels, vimls, yamlls,
  ts_ls, jsonls, eslint, …) failed on every start, ending in a "Press ENTER"
  prompt. `lua/lsp/npm_guard.lua`, run first in `lua/lsp/init.lua` (Mason
  snapshots PATH when it first loads), detects such a stand-in and links the real
  npm that ships beside `node` first on PATH (a symlink under
  `stdpath("data")/dwp-bin`); when no real npm exists, the npm-based servers
  are left out of `ensure_installed` and one warning explains why. The
  no-op `npm = { package_manager = "pnpm" }` Mason setting, which Mason has
  no such key for, is removed.

## [v0.5.1] - 2026-10-09

### Fixed

- **Plugins are pinned to commits.** v0.5.0 installed all 41 plugins and
  pckr from each default branch, so two installs (or two image builds) of
  one release could run different plugin code and every install took
  whatever upstream had pushed last. The tracked `pckr/lockfile.lua` (pckr's
  own lockfile path and format) now pins every plugin, dependencies
  included, and pckr itself; each pin is applied as the plugin's `commit`,
  so it holds on install and on every update, and pckr is checked out at its
  pin by `lua/plugins.lua` and by `install.lua`.
- **`--strict` verifies every plugin commit**: each installed plugin (and
  pckr) must be checked out at its lock entry, every pinned plugin must be
  present and every installed plugin must be pinned; the failure names the
  plugin and both commits. Without `--strict` it is a warning. The
  empty-clone check is unchanged. An install made by an older release is no
  longer "already installed" until its plugins match the lock: rerunning the
  installer moves them to their pins. A release without a lockfile (an older
  `--version`) still installs, and the run says its commits are not
  verified — but under `--strict` a v0.5.1+ release tag whose tree lacks
  the lockfile is an error.
- A plugin left unpinned is reported, not hidden: a start whose lock is
  missing or incomplete warns that those plugins follow their branch tip,
  and pckr warns when it cannot reach its pin (the network fetch for that
  happens only during the installer's bootstrap, so an offline start never
  waits on it). Each repository is pinned on one spec, so pckr shows no
  "specified more than once" warnings for shared dependencies.

### Added

- `scripts/update-plugin-lock.sh` — the maintainer's lock refresh: syncs
  every plugin to its branch tip in a throwaway `HOME`, writes the lock,
  reinstalls from it and requires every commit to match, runs the smoke
  suite and the installer harness, and with `--commit` commits the lock
  alone (`chore(deps): refresh the plugin lock`, listing what moved). The
  sync runs with an environment allowlist (no tokens or agent sockets);
  it executes unreviewed branch-tip code, so run it in the contributor
  container.
- Tests: `tests/smoke/plugin_lock.lua` fails when a plugin (or a dependency)
  has no lock entry, the lock names an undeclared plugin, the file leaves
  pckr's format, or a pin is not applied; installer harness 58 scenarios
  (+4: pinned, drifted and repaired, unreadable lock, unlocked plugin,
  missing pckr, lock-less release); the container test requires every lock
  entry verified.

### Changed

- The curated plugin list moved unchanged from `lua/plugins.lua` to
  `lua/plugin_specs.lua` (pure data); `lua/plugin_lock.lua` applies the pins.

## [v0.5.0] - 2026-10-09

### Added

- **Version selection, Dailybot-CLI style:** `--version` / `DWP_VIM_VERSION`
  take `X.Y.Z`, `vX.Y.Z`, `latest` (newest stable release) or `'>=X.Y.Z'`
  (newest stable release at or above the floor), resolved with
  `git ls-remote` and compared numerically (pre-releases ignored). Precedence:
  a flag beats every environment value, then `DWP_VIM_VERSION`, then
  `DWP_VIM_REF`, then the installer's own release; a version and a ref at the
  same level that disagree are an error; the resolved tag is printed; a
  missing version lists the newest releases.
- **Options** (also after `bash -s --` from a pipe), each with an env twin:
  `--version`, `--ref`, `--dir`, `--skip-packages`, `--strict`, `--nvim`,
  `--yes`, `-h/--help`; an unknown option prints the usage and exits 2.
- **Container mode** for images and CI —
  `bash install.sh --version 0.5.0 --nvim 0.12.5 --skip-packages --strict`
  replaces the clone + `install.lua` + headless sync + plugin-check block:
  - `--nvim X.Y.Z` installs the official Neovim tarball (Linux and macOS,
    x86_64 and arm64) into `~/.local/opt/nvim-vX.Y.Z`, linked as
    `~/.local/bin/nvim` (an existing non-link `nvim` there is moved aside),
    verified against the sha256 Neovim publishes (release asset digest, else
    the `.sha256sum` asset); a mismatch or no checksum installs nothing.
    `GITHUB_TOKEN` authenticates the lookup and is then removed from the
    run's environment.
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
  `--strict` does. A rerun repairs an install left with empty clones: they
  are moved aside (never deleted) and installed again.

### Changed

- Switch values (`DWP_VIM_SKIP_PACKAGES` and the new twins) are
  `1/true/yes/on` or `0/false/no/off` in any case; anything else is an
  error. `DWP_VIM_SKIP_PACKAGES=false|no|off` previously meant on.
- Whether plugins are already installed is decided by the plugins
  themselves, not by the bootstrap marker or the `mason.nvim` directory.

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

[Unreleased]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.6.0...HEAD
[v0.6.0]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.5.1...v0.6.0
[v0.5.1]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.5.0...v0.5.1
[v0.5.0]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.4.2...v0.5.0
[v0.4.2]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.4.1...v0.4.2
[v0.4.1]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.4.0...v0.4.1
[v0.4.0]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.3.1...v0.4.0
[v0.3.1]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.3.0...v0.3.1
[v0.3.0]: https://github.com/DailybotHQ/deepworkplan-vim/compare/v0.2.0...v0.3.0
[v0.2.0]: https://github.com/DailybotHQ/deepworkplan-vim/releases/tag/v0.2.0
