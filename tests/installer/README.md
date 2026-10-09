# Installer compatibility harness

Host-runnable compatibility and safety harness for `install.sh`. It needs
only **bash, git, coreutils, `script`** (util-linux or BSD/macOS — for the
one pty consent scenario) **and a real `lua5.4` on PATH** (for the four
`delete.lua`/probe scenarios) — no Docker, no network, no Neovim, no real
`install.lua` leg — and runs the **real `install.sh`** end to end in
synthetic roots.

**Portability.** The harness runs from any branch: the fixture (a clone of
this repository standing in for the remote) gets `main` pointed at the
commit under test and checked out, because `install.sh` installs `main` by
default and a clone only carries the source's current branch. The pty
scenario uses `pty_answer`: util-linux `script -qec` where available,
otherwise BSD `script`, whose stdin is held open until the command exits
(BSD `script` forwards end-of-input as `^D`, which can overtake the typed
answer).

```bash
bash tests/installer/run.sh
```

Success sentinel: `INSTALLER HARNESS: OK (54 scenarios)` (exit 0). Runtime is
a few seconds; the run is hermetic (every scenario builds and destroys its own
`mktemp -d` root — it never touches a real `$HOME`).

## What it proves

Each scenario drives the real installer under `env -i` with a controlled
`PATH` (fake `uname`/`id`/`sudo` always visible; exactly one package-manager
shim per scenario; real `git`/coreutils for everything else):

| Scenario | Proves |
|---|---|
| `fresh_apt` | Debian/Ubuntu leg: `apt-get update` first, installs `curl` then `lua5.4`, `sudo` prefix for uid 1000, Lua leg invoked, completion banner, nvim-absent NOTE, no backup, rc 0 |
| `fresh_dnf` | Fedora leg: `dnf install -y lua`, **no** `sudo` as root |
| `fresh_pacman` | Arch leg: `pacman -Sy --noconfirm lua`, `sudo` prefix |
| `fresh_brew` | macOS leg: `brew install lua`, never `sudo` |
| `ref_default_release_tag` | A5: with no `DWP_VIM_REF` a fresh install lands exactly on the release tag baked into `install.sh` (`RELEASE_REF`), detached, with a `Version` row and no detached-HEAD advice noise |
| `ref_main_explicit` | `DWP_VIM_REF=main` opts into the moving branch: the checkout is on `refs/heads/main` |
| `update_older_to_tag` | An install on an older upstream commit moves to the release tag; its local `main` branch is kept |
| `update_diverged_local_main` | R2 on the branch path (`DWP_VIM_REF=main`): a diverged local `main` dies loudly, local commit intact |
| `skip_packages_missing_tool` | `DWP_VIM_SKIP_PACKAGES=1` with Lua missing: dies naming the switch and the tool, calls no package manager, clones nothing |
| `skip_packages_present` | `DWP_VIM_SKIP_PACKAGES=1` with every tool present: completes, calls no package manager, and hands `DWP_VIM_SKIP_PACKAGES=1` to `install.lua` |
| `skip_packages_zero_is_off` | `DWP_VIM_SKIP_PACKAGES=0` is off: the preflight installs the missing Lua; `install.lua` is not told to skip |
| `pnpm_fallback_no_pipe` | Real `installer.lua` `ensure_pnpm()` under real `lua5.4` (stubbed util, `tests/installer/lua/pnpm_fallback.lua`): Unix installs `pnpm@10` with `npm install -g --ignore-scripts --prefix <PNPM_HOME>` (shell-quoted, even with `$`/`"` in the path), Windows with `npm install -g --ignore-scripts pnpm@10`; a missing npm is added with its own `apt-get install -y npm`; no npm → clear failure; Node 12 → "too old", nothing installed; no command contains a pipe |
| `piped_stdin_fresh` | The script read through a real pipe (as when the URL is piped into bash) completes a fresh install on the release tag, and the `install.lua` stub records an empty stdin — no script text reaches a child |
| `piped_stdin_foreign_safe` | The same pipe over a foreign config: "ran without a terminal" abort, rc non-zero, config intact, no backup |
| `version_exact` | `--version 0.4.2` (with `--dir`) installs exactly that release and prints the resolved tag; a matching `DWP_VIM_REF` is not a conflict |
| `version_v_prefix` | `DWP_VIM_VERSION=v0.4.1` (env twin, v-prefixed) |
| `version_latest` | `--version latest` through `bash -s --` from a pipe = the newest stable tag; the fixture's newer `v9.9.9-rc.1` is ignored |
| `version_floor` | `'>=0.4.1'` = the newest stable release at or above the floor; `'>=99.0.0'` fails listing the newest releases |
| `version_missing` | `--version 9.9.9`: non-zero, the newest releases listed, nothing cloned |
| `version_ref_conflict` | `--ref main --version 0.4.2` and `DWP_VIM_REF=main DWP_VIM_VERSION=0.4.2`: exit 2 naming both; `DWP_VIM_REF=main` + `--version 0.4.2`: the flag wins |
| `version_bad_string` | `1.2`, `--upload-pack=…`, `>=1.2.3;id`, `latest-ish`, `v1.2.3.4`, a bad `--ref` and `--nvim`: exit 2, git never runs |
| `flag_unknown` | an unknown option or a missing value: the usage, exit 2 |
| `flag_help` | `--help`: the usage (options + env twins), exit 0, nothing installed |
| `strict_bootstrap_failure` | `--strict`: a failed bootstrap exits non-zero with the log; without it a warning; `--strict` without nvim on PATH fails |
| `strict_missing_plugins` | `--strict` verifies the plugins: a missing `mason.nvim` and an empty clone each fail with the list; all present passes |
| `nvim_checksum_mismatch` | `--nvim`: a wrong published digest, an asset listed without a digest, and a release without the asset (old naming) all abort with nothing installed and no staging left (file:// fixture of the release API and tarball) |
| `nvim_install_ok` | `--nvim` with the right digest: unpacked into `~/.local/opt/nvim-v0.12.5`, `~/.local/bin/nvim` linked to it (an existing non-link `nvim` moved aside), mirror trust noted, used by the `--strict` bootstrap; a rerun skips the download |
| `strict_repairs_empty_clones` | empty clones (only `.git`, as left by the pre-0.5.0 race) are moved aside (not deleted), the bootstrap runs with `DWP_VIM_BOOTSTRAP=1`, `--strict` passes |
| `option_values_hardened` | `--version=` empty, `--dir --yes`, `DWP_VIM_YES=N`, a non-numeric timeout and `--dir $HOME` exit 2; `DWP_VIM_SKIP_PACKAGES=Off` is off; a relative `--dir` becomes absolute; a `GITHUB_TOKEN` carrying curl config is ignored (no file written) |
| `yes_moves_foreign` | `DWP_VIM_YES=1` moves a foreign config aside without a terminal |
| `install_lua_unattended_answers` | real `cli.lua`: stdin `/dev/null` gives the same answers as the images' `printf 'n\n\n'` (custom dir No, extras default) |
| `update_origin_old_fork` | Field bug of v0.4.1: an install whose origin is the older `mu-vim` fork is not updated in place — without a terminal the run names the origin, offers backup + fresh install or how to keep it, fetches nothing, changes nothing (HEAD, branch, no backup) — also when the script is piped; only the origin advice is given (no stash); origins with user:password (even an unescaped `@`), a token alone, or a query token are printed redacted, an `@` in the path kept |
| `update_origin_old_fork_consent` | The consented path on a pty (`y`): the fork install, with its local edit, is moved to `previous-deepworkplan-vim` intact and a fresh install lands on the release tag |
| `update_local_modifications` | Local edits to tracked files in our own checkout: stop naming "local edits in 2 tracked file(s)" with stash advice only (origin is fine), HEAD and both edits intact, no backup |
| `update_status_unreadable` | A checkout whose `git status` fails (corrupt index) is never assumed clean: stop naming "local changes could not be inspected" |
| `update_offline` | `DWP_VIM_SOURCE` unreachable: stop naming the source, HEAD and branch unchanged, no system setup |
| `update_fetches_canonical_source` | With `DWP_VIM_SOURCE` unset the update fetches from the DeepWorkPlan Vim repository URL, not origin (proved offline: the file-only protocol refuses it) |
| `update_ours` | Idempotent rerun over our own clone: update path to the release tag, no consent prompt, Lua leg + headless bootstrap run, rc 0, no backup |
| `update_ours_source` | FIXED(I-1): dead `origin` + valid `DWP_VIM_SOURCE` updates from the source and completes (the env var is honored on updates) |
| `not_ours_local_path` | FIXED(I-2): our clone via a mirror path (URL lacks `deepworkplan-vim`) is recognized by checkout contents and updates in place when `DWP_VIM_SOURCE` names that mirror |
| `foreign_piped` | Piped/non-tty run over a foreign config: detection, "cannot ask unattended" abort, foreign file intact, no backup |
| `foreign_interactive_yes` | Pty run, consent `y`: foreign config moved to `previous-deepworkplan-vim`, fresh clone installed, rc 0 |
| `backup_collision` | Pre-existing `previous-deepworkplan-vim` aborts before touching anything |
| `dest_is_file` | `~/.config/nvim` exists as a file → clean abort |
| `unsupported_os_mingw` | MINGW64 refuses with winget instructions |
| `unsupported_os_unknown` | Unknown kernel (Haiku) dies naming the uname value |
| `bootstrap_xdg_custom_dir` | Custom `DWP_VIM_DIR`: `XDG_CONFIG_HOME` = parent + `NVIM_APPNAME` = basename composition reaches nvim; FIXED(I-19): the idempotence marker is written after a clean bootstrap |
| `update_diverged_local` | FIXED(R2, final review), tag path (the default): a local commit no remote branch or tag holds dies loudly ("update skipped… local commits") — rc non-zero, no success banner, no system setup, local commit intact |
| `delete_foreign_config` | FIXED(I-3)+(I-4)+(R1, final review), real `delete.lua` under the host's real `lua5.4`: a foreign config_dir — including a packer-style one carrying `lua/plugins.lua` but no `install.lua` — is listed as "left in place", never a removal target; a piped confirm (no tty, EOF) keeps the default (No) so the uninstall aborts without deleting |
| `bootstrap_already_installed` | Verified plugins (alpha-nvim, nvim-cmp, mason.nvim with content) short-circuit: "Plugins already installed", no nvim invocation |
| `lua_failure_handoff` | UX2-03: a failing system-setup leg ends with a paste-able agent handoff naming the `fails.log` path, **added** to the kept log + issues lines; rc non-zero |
| `delete_one_liner` | UX2-04, real `lua5.4`: the advertised one-liner — `delete.lua` by absolute path from an unrelated cwd — removes a synthetic install after piped consent `y` (config + data dirs gone, rc 0) |
| `consent_eof_safe` | R4, real `lua5.4` probes: line-mode EOF is reported as `eof` (distinct from an explicit empty line = `default`, typed `y`/`n` = `yes`/`no`); `replace_old` aborts on `eof` — nothing moved or deleted (probe simulates the Windows `can_ask=true` condition); the Unix no-tty gate stays |
| `realpath_bsd_fallback` | I-7, real `lua5.4` probes: with a BSD-style `realpath` (rejects `-m`) and with no `realpath` at all, `util.realpath` still expands `~` to `$HOME`, makes relative paths absolute against the physical cwd, and collapses `.`/`..`; `path_is_under` guard semantics intact |

**Flipped pins.** Three scenarios were committed during the audit as
KNOWN-DEFECT pins asserting the then-buggy behavior (I-1, I-2, I-19); the
remediation flipped them red→green with the red half recorded in the plan
(`RED_HALF_pins_vs_fixed_code.txt`). Any future installer change that
breaks them is a regression, not a pin.

## What it does NOT prove (bounds)

- **No real package installs** — manager shims only record argv (and
  materialize a stub `lua5.4` when a lua package is "installed"). Real
  apt/dnf/pacman/brew behavior, sudo prompts and package-name drift belong to
  the container matrix (`docker compose -f compose.yml run --rm apt_test` …).
- **No real install.lua leg** — `install.lua` runs as a stub; the
  system-setup phase (manager detection in Lua, package installs, pnpm) is
  not exercised here. `delete.lua` DOES run for real (host `lua5.4`): it
  only unlinks paths under the synthetic root. Scripts under test run LIVE
  from the working tree; anything reached through the fixture clone carries
  the last commit instead.
- **No real Neovim** — the headless bootstrap runs a stub `nvim` that records
  the `XDG_CONFIG_HOME`/`NVIM_APPNAME` composition; plugin installation,
  mason and first-launch self-healing are not covered.
- **No Windows/macOS hosts** — MINGW refusal and brew-leg behavior are
  simulated via `FAKE_UNAME` and shims; winget and real Homebrew (BSD
  `realpath`, finding I-7) are not.
- **Network** — nothing leaves the machine: clones use a local fixture
  clone of this repository; `DWP_VIM_SOURCE` always points at it.

## Layout

```
tests/installer/
├── run.sh                  # the harness (54 scenarios + shared setup)
├── container.sh            # the image one-liner in a Debian container (Docker + network)
├── lua/pnpm_fallback.lua   # real installer.lua ensure_pnpm() under a stubbed util
└── shims/
    ├── uname id sudo       # OS/identity shims (FAKE_UNAME / FAKE_UID)
    ├── apt-get             # manager shim template (logs argv; installs a lua5.4 stub)
    ├── dnf pacman brew     # generated: bash shims/_mk_manager_shim.sh
    ├── lua5.4 nvim curl    # stubs recording the Lua-leg / bootstrap / preflight calls
    └── _mk_manager_shim.sh # regenerates dnf/pacman/brew from the apt-get template
```

Shims communicate via `SHIM_LOG` (append argv) and `SHIM_BIN` (writable
scenario bin where "installed" stubs materialize). To regenerate the three
derived manager shims after editing `apt-get`:
`bash tests/installer/shims/_mk_manager_shim.sh`.
