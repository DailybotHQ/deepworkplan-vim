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

Success sentinel: `INSTALLER HARNESS: OK (31 scenarios)` (exit 0). Runtime is
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
| `update_ours` | Idempotent rerun over our own clone: update path to the release tag, no consent prompt, Lua leg + headless bootstrap run, rc 0, no backup |
| `update_ours_source` | FIXED(I-1): dead `origin` + valid `DWP_VIM_SOURCE` updates from the source and completes (the env var is honored on updates) |
| `not_ours_local_path` | FIXED(I-2): our clone via a mirror path (URL lacks `deepworkplan-vim`) is recognized by checkout contents and updates in place |
| `foreign_piped` | Piped/non-tty run over a foreign config: detection, "cannot ask unattended" abort, foreign file intact, no backup |
| `foreign_interactive_yes` | Pty run, consent `y`: foreign config moved to `previous-deepworkplan-vim`, fresh clone installed, rc 0 |
| `backup_collision` | Pre-existing `previous-deepworkplan-vim` aborts before touching anything |
| `dest_is_file` | `~/.config/nvim` exists as a file → clean abort |
| `unsupported_os_mingw` | MINGW64 refuses with winget instructions |
| `unsupported_os_unknown` | Unknown kernel (Haiku) dies naming the uname value |
| `bootstrap_xdg_custom_dir` | Custom `DWP_VIM_DIR`: `XDG_CONFIG_HOME` = parent + `NVIM_APPNAME` = basename composition reaches nvim; FIXED(I-19): the idempotence marker is written after a clean bootstrap |
| `update_diverged_local` | FIXED(R2, final review), tag path (the default): a local commit no remote branch or tag holds dies loudly ("update skipped… local commits") — rc non-zero, no success banner, no system setup, local commit intact |
| `delete_foreign_config` | FIXED(I-3)+(I-4)+(R1, final review), real `delete.lua` under the host's real `lua5.4`: a foreign config_dir — including a packer-style one carrying `lua/plugins.lua` but no `install.lua` — is listed as "left in place", never a removal target; a piped confirm (no tty, EOF) keeps the default (No) so the uninstall aborts without deleting |
| `bootstrap_already_installed` | Existing marker short-circuits: "Plugins already installed", no nvim invocation |
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
├── run.sh                  # the harness (31 scenarios + shared setup)
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
