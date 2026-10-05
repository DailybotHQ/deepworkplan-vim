# Installer compatibility harness

Host-runnable compatibility and safety harness for `install.sh`. It needs
only **bash, git and coreutils** — no Docker, no network, no Neovim, no real
Lua leg — and runs the **real `install.sh`** end to end in synthetic roots.

```bash
bash tests/installer/run.sh
```

Success sentinel: `INSTALLER HARNESS: OK (15 scenarios)` (exit 0). Runtime is
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
| `update_ours_source` | **KNOWN-DEFECT pin I-1**: dead `origin` + valid `DWP_VIM_SOURCE` still dies (update ignores the env var) |
| `not_ours_local_path` | **KNOWN-DEFECT pin I-2**: our clone via a mirror path (URL lacks `deepworkplan-vim`) is misdetected as foreign and aborts unattended |
| `foreign_piped` | Piped/non-tty run over a foreign config: detection, "cannot ask unattended" abort, foreign file intact, no backup |
| `foreign_interactive_yes` | Pty run, consent `y`: foreign config moved to `previous-deepworkplan-vim`, fresh clone installed, rc 0 |
| `backup_collision` | Pre-existing `previous-deepworkplan-vim` aborts before touching anything |
| `dest_is_file` | `~/.config/nvim` exists as a file → clean abort |
| `unsupported_os_mingw` | MINGW64 refuses with winget instructions |
| `unsupported_os_unknown` | Unknown kernel (Haiku) dies naming the uname value |
| `bootstrap_xdg_custom_dir` | Custom `DWP_VIM_DIR`: `XDG_CONFIG_HOME` = parent + `NVIM_APPNAME` = basename composition reaches nvim; **KNOWN-DEFECT pin I-19**: marker not written after a clean bootstrap |
| `bootstrap_already_installed` | Existing marker short-circuits: "Plugins already installed", no nvim invocation |

**KNOWN-DEFECT pins** intentionally assert the current *buggy* behavior
(audit findings I-1, I-2, I-19 in
`.dwp/plans/PLAN_004_installer_compat_ux_audit/analysis_results/INSTALLER_AUDIT.md`).
A fix that changes installer behavior must flip these scenarios red→green
consciously: update the assertion, the tag comment and this README together.

## What it does NOT prove (bounds)

- **No real package installs** — manager shims only record argv (and
  materialize a stub `lua5.4` when a lua package is "installed"). Real
  apt/dnf/pacman/brew behavior, sudo prompts and package-name drift belong to
  the container matrix (`docker compose -f compose.yml run --rm apt_test` …).
- **No real Lua leg** — `install.lua` runs as a stub; the system-setup phase
  (manager detection in Lua, pckr install, pnpm) is not exercised here.
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
