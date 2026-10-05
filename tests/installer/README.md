# Installer compatibility harness

Host-runnable compatibility and safety harness for `install.sh`. It needs
only **bash, git and coreutils** — no Docker, no network, no Neovim, no real
Lua leg — and runs the **real `install.sh`** end to end in synthetic roots.

```bash
bash tests/installer/run.sh
```

Success sentinel: `INSTALLER HARNESS: OK (16 scenarios)` (exit 0). Runtime is
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
| `update_ours` | Idempotent rerun over our own clone: update path, fetch + ff, no consent prompt, Lua leg + headless bootstrap run, rc 0, no backup |
| `update_ours_source` | FIXED(I-1): dead `origin` + valid `DWP_VIM_SOURCE` updates from the source and completes (the env var is honored on updates) |
| `not_ours_local_path` | FIXED(I-2): our clone via a mirror path (URL lacks `deepworkplan-vim`) is recognized by checkout contents and updates in place |
| `foreign_piped` | Piped/non-tty run over a foreign config: detection, "cannot ask unattended" abort, foreign file intact, no backup |
| `foreign_interactive_yes` | Pty run, consent `y`: foreign config moved to `previous-deepworkplan-vim`, fresh clone installed, rc 0 |
| `backup_collision` | Pre-existing `previous-deepworkplan-vim` aborts before touching anything |
| `dest_is_file` | `~/.config/nvim` exists as a file → clean abort |
| `unsupported_os_mingw` | MINGW64 refuses with winget instructions |
| `unsupported_os_unknown` | Unknown kernel (Haiku) dies naming the uname value |
| `bootstrap_xdg_custom_dir` | Custom `DWP_VIM_DIR`: `XDG_CONFIG_HOME` = parent + `NVIM_APPNAME` = basename composition reaches nvim; FIXED(I-19): the idempotence marker is written after a clean bootstrap |
| `delete_foreign_config` | FIXED(I-3)+(I-4), real `delete.lua` under the host's real `lua5.4`: a foreign config_dir is listed as "left in place", never a removal target; a piped confirm (no tty, EOF) keeps the default (No) so the uninstall aborts without deleting |
| `bootstrap_already_installed` | Existing marker short-circuits: "Plugins already installed", no nvim invocation |

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
├── run.sh                  # the harness (15 scenarios + shared setup)
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
