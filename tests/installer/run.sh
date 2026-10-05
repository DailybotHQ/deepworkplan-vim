#!/usr/bin/env bash
# tests/installer/run.sh — installer compatibility harness.
#
# Host-runnable (bash + git + coreutils + util-linux script; no Docker, no network, no
# Neovim, no real Lua leg): every scenario runs the REAL install.sh
# against synthetic roots (mktemp -d fake $HOME) with PATH shims that
# record package-manager invocations. The uninstaller scenario runs the
# REAL delete.lua under the host's real lua5.4 — it only unlinks paths
# inside the synthetic root. (The install.lua leg stays stubbed: its
# package installs belong to the container matrix.) The former
# KNOWN-DEFECT pins (audit I-1, I-2, I-19) were flipped to fixed
# behavior by the Task-3 remediation, red half recorded in the plan.
#
# PATH layout per scenario:   $NEUTRAL_DIR : $T/bin : $BASE_BIN
#   NEUTRAL_DIR — uname/id/sudo shims only (always visible).
#   $T/bin      — the scenario's writable bin: the ONE manager shim it
#                 simulates, plus lua5.4/nvim stubs when "installed".
#   BASE_BIN    — real bash/git/coreutils, minus managers/lua/curl/nvim.
set -u
cd "$(dirname "$0")/../.."
REPO="$(pwd)"
SHIMS="$REPO/tests/installer/shims"

TOTAL_PASS=0; TOTAL_FAIL=0; SCEN_FAILS=0; SCEN=""
WG_QUIET=0

wg() { # wg <label> <pattern> <file> — pattern must appear
  if grep -q -- "$2" "$3" 2>/dev/null; then return 0; fi
  echo "   !! $SCEN/$1: pattern not found ($2) in $3"
  SCEN_FAILS=$((SCEN_FAILS+1))
}
wng() { # wng <label> <pattern> <file> — pattern must NOT appear
  if grep -q -- "$2" "$3" 2>/dev/null; then
    echo "   !! $SCEN/$1: unexpected pattern found ($2) in $3"
    SCEN_FAILS=$((SCEN_FAILS+1))
  fi
}
wx() { # wx <label> <test-expr...>
  local label="$1"; shift
  if "$@"; then return 0; fi
  echo "   !! $SCEN: $label"
  SCEN_FAILS=$((SCEN_FAILS+1))
}

run_scenario() { # run_scenario <name> <fn> [tag]
  local name="$1" fn="$2" tag="${3:-}"
  local fails_file="$WORK/last_fails"
  : >"$fails_file"
  (
    SCEN="$name"; SCEN_FAILS=0
    "$fn"
    echo "$SCEN_FAILS" >"$fails_file"
  )
  local fails; fails="$(cat "$fails_file" 2>/dev/null || echo 1)"
  case "$fails" in
    ''|*[!0-9]*) fails=1 ;;
  esac
  if [ "$fails" -eq 0 ]; then
    TOTAL_PASS=$((TOTAL_PASS+1))
    echo "-- $name: PASS${tag:+ $tag}"
  else
    TOTAL_FAIL=$((TOTAL_FAIL+1))
    echo "-- $name: FAIL ($fails assertion(s))${tag:+ $tag}"
  fi
}

# --- shared setup -----------------------------------------------------------

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fixture: a local clone standing in for the remote repository. The dir
# name contains 'deepworkplan-vim' so is_ours' substring matches it.
FIXTURE="$WORK/fixture-deepworkplan-vim"
git clone -q "$REPO" "$FIXTURE"

# NEUTRAL_DIR: shims visible in every scenario (OS identity only).
NEUTRAL_DIR="$WORK/neutral-bin"
mkdir -p "$NEUTRAL_DIR"
install -m 755 "$SHIMS/uname" "$SHIMS/id" "$SHIMS/sudo" "$NEUTRAL_DIR/"

# BASE_BIN: real tools install.sh needs, minus everything the scenarios
# fake (managers, lua, curl, nvim).
BASE_BIN="$WORK/base-bin"
mkdir -p "$BASE_BIN"
for t in bash sh git mkdir mv rm ls grep dirname basename touch mktemp env timeout cat chmod; do
  p="$(command -v "$t" 2>/dev/null)" && ln -s "$p" "$BASE_BIN/$t"
done

scen_root() { # scen_root — new scenario root; echoes the path
  local T; T="$(mktemp -d)"
  mkdir -p "$T/home/.config" "$T/bin"
  printf '%s' "$T"
}

run_install() { # run_install <T> <out-file> [VAR=value...] — sets RC
  local T="$1" out="$2"; shift 2
  RC=0
  env -i HOME="$T/home" PATH="$NEUTRAL_DIR:$T/bin:$BASE_BIN" \
    SHIM_LOG="$T/shim.log" SHIM_BIN="$T/bin" \
    "$@" bash "$REPO/install.sh" </dev/null >"$out" 2>&1 || RC=$?
}

# --- scenarios --------------------------------------------------------------

scenario_fresh_apt() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/apt-get" "$T/bin/apt-get"
  run_install "$T" "$T/out.log" FAKE_UID=1000 DWP_VIM_SOURCE="$FIXTURE"
  wg "apt update first"        "apt-get update"                "$T/shim.log"
  wg "curl via apt"            "apt-get install -y curl"       "$T/shim.log"
  wg "debian lua name"         "apt-get install -y lua5.4"     "$T/shim.log"
  wg "sudo prefix (non-root)"  "sudo apt-get"                  "$T/shim.log"
  wg "lua leg ran (stub)"      "lua5.4 install.lua"            "$T/shim.log"
  wg "completion line"         "DeepWorkPlan Vim is installed at" "$T/out.log"
  wg "nvim-absent note"        "nvim is not on PATH"           "$T/out.log"
  wx "exit 0"                  test "$RC" -eq 0
  wx "no backup created"       test ! -e "$T/home/.config/previous-deepworkplan-vim"
}

scenario_fresh_dnf() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/dnf" "$T/bin/dnf"
  run_install "$T" "$T/out.log" FAKE_UID=0 DWP_VIM_SOURCE="$FIXTURE"
  wg "dnf install lua"         "dnf install -y lua"            "$T/shim.log"
  wng "no sudo when root"      "sudo dnf"                      "$T/shim.log"
  wg "lua leg ran (stub)"      "lua5.4 install.lua"            "$T/shim.log"
  wg "completion line"         "DeepWorkPlan Vim is installed at" "$T/out.log"
  wx "exit 0"                  test "$RC" -eq 0
}

scenario_fresh_pacman() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/pacman" "$T/bin/pacman"
  run_install "$T" "$T/out.log" FAKE_UID=1000 DWP_VIM_SOURCE="$FIXTURE"
  wg "pacman -Sy --noconfirm"  "pacman -Sy --noconfirm lua"    "$T/shim.log"
  wg "sudo prefix (non-root)"  "sudo pacman"                   "$T/shim.log"
  wg "lua leg ran (stub)"      "lua5.4 install.lua"            "$T/shim.log"
  wx "exit 0"                  test "$RC" -eq 0
}

scenario_fresh_brew() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/brew" "$T/bin/brew"
  run_install "$T" "$T/out.log" FAKE_UID=1000 DWP_VIM_SOURCE="$FIXTURE"
  wg "brew install bare"       "brew install lua"              "$T/shim.log"
  wng "brew never sudo"        "sudo "                         "$T/shim.log"
  wg "lua leg ran (stub)"      "lua5.4 install.lua"            "$T/shim.log"
  wx "exit 0"                  test "$RC" -eq 0
}

scenario_update_ours() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  install -m 755 "$SHIMS/nvim" "$T/bin/nvim"
  git clone -q "$FIXTURE" "$T/home/.config/nvim"
  run_install "$T" "$T/out.log"
  wg "update path taken"       "Existing DeepWorkPlan Vim install" "$T/out.log"
  wg "updating to ref"         "updating to 'main'"            "$T/out.log"
  wng "no consent prompt"      "Move it to"                    "$T/out.log"
  wg "lua leg ran (stub)"      "lua5.4 install.lua"            "$T/shim.log"
  wg "bootstrap ran"           "nvim --headless"               "$T/shim.log"
  wg "plugins marker"          "Plugins installed"             "$T/out.log"
  wx "exit 0"                  test "$RC" -eq 0
  wx "no backup created"       test ! -e "$T/home/.config/previous-deepworkplan-vim"
}

scenario_update_ours_source() {
  # FIXED(I-1): the ours-branch honors DWP_VIM_SOURCE — a dead origin no
  # longer kills the update when a valid source is exported.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  git clone -q "$FIXTURE" "$T/home/.config/nvim"
  git -C "$T/home/.config/nvim" remote set-url origin "$T/dead-deepworkplan-vim"
  run_install "$T" "$T/out.log" DWP_VIM_SOURCE="$FIXTURE"
  wg "recognized as ours"   "Existing DeepWorkPlan Vim install" "$T/out.log"
  wg "update completed"     "DeepWorkPlan Vim is installed at"  "$T/out.log"
  wng "no fetch failure"    "git fetch failed"                  "$T/out.log"
  wg "lua leg ran (stub)"   "lua5.4 install.lua"                "$T/shim.log"
  wx "exit 0"               test "$RC" -eq 0
  wx "DEST left a git repo" test -d "$T/home/.config/nvim/.git"
}

scenario_not_ours_local_path() {
  # FIXED(I-2): is_ours identifies the checkout by its contents
  # (install.lua + lua/plugins.lua), so a clone from a mirror path whose
  # URL lacks 'deepworkplan-vim' updates in place instead of being
  # treated as a foreign config.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  git clone -q --bare "$FIXTURE" "$T/m"
  git clone -q "$T/m" "$T/home/.config/nvim"
  run_install "$T" "$T/out.log"
  wg "recognized as ours"  "Existing DeepWorkPlan Vim install" "$T/out.log"
  wg "lua leg ran (stub)"  "lua5.4 install.lua"                "$T/shim.log"
  wng "no consent prompt"  "Move it to"                        "$T/out.log"
  wng "no foreign abort"   "refusing to touch an existing config unattended" "$T/out.log"
  wx "exit 0"              test "$RC" -eq 0
  wx "clone is a repo"     test -d "$T/home/.config/nvim/.git"
  wx "install.lua intact"  test -f "$T/home/.config/nvim/install.lua"
}

scenario_foreign_piped() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  mkdir -p "$T/home/.config/nvim"
  echo "foreign init.vim" >"$T/home/.config/nvim/init.vim"
  run_install "$T" "$T/out.log"
  wg "foreign detected"        "An existing Neovim config was found" "$T/out.log"
  wg "cannot ask unattended"   "ran without a terminal"        "$T/out.log"
  wg "interactive rerun hint"  "run it interactively"          "$T/out.log"
  wx "exit non-zero"           test "$RC" -ne 0
  wx "foreign file intact"     test "$(cat "$T/home/.config/nvim/init.vim")" = "foreign init.vim"
  wx "no backup created"       test ! -e "$T/home/.config/previous-deepworkplan-vim"
}

scenario_foreign_interactive_yes() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  mkdir -p "$T/home/.config/nvim"
  echo "foreign init.vim" >"$T/home/.config/nvim/init.vim"
  # A pty so /dev/tty opens and ask_consent can read the 'y'.
  local rc=0
  printf 'y\n' | script -qec \
    "env -i HOME=$T/home PATH=$NEUTRAL_DIR:$T/bin:$BASE_BIN SHIM_LOG=$T/shim.log SHIM_BIN=$T/bin DWP_VIM_SOURCE=$FIXTURE bash $REPO/install.sh" \
    /dev/null >"$T/out.log" 2>&1 || rc=$?
  wg "consent offered"         "Move it to"                    "$T/out.log"
  wg "backup announced"        "Moving the existing config"    "$T/out.log"
  wg "completion line"         "DeepWorkPlan Vim is installed at" "$T/out.log"
  wx "exit 0"                  test "$rc" -eq 0
  wx "backup holds old config" test -f "$T/home/.config/previous-deepworkplan-vim/init.vim"
  wx "DEST is the fresh clone" test -f "$T/home/.config/nvim/install.lua"
}

scenario_backup_collision() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  mkdir -p "$T/home/.config/previous-deepworkplan-vim"
  mkdir -p "$T/home/.config/nvim"
  echo "foreign init.vim" >"$T/home/.config/nvim/init.vim"
  run_install "$T" "$T/out.log"
  wg "collision aborts"        "backup path"                   "$T/out.log"
  wg "nothing touched"         "Nothing was touched"           "$T/out.log"
  wx "exit non-zero"           test "$RC" -ne 0
  wx "foreign file intact"     test "$(cat "$T/home/.config/nvim/init.vim")" = "foreign init.vim"
}

scenario_dest_is_file() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  : >"$T/home/.config/nvim"
  run_install "$T" "$T/out.log"
  wg "not-a-directory abort"   "exists and is not a directory" "$T/out.log"
  wx "exit non-zero"           test "$RC" -ne 0
}

scenario_unsupported_os_mingw() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  run_install "$T" "$T/out.log" FAKE_UNAME="MINGW64_NT-10.0-19045"
  wg "windows shell detected"  "Windows shell detected"        "$T/out.log"
  wg "winget instructions"     "winget install -e --id Neovim.Neovim" "$T/out.log"
  wx "exit non-zero"           test "$RC" -ne 0
}

scenario_unsupported_os_unknown() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  run_install "$T" "$T/out.log" FAKE_UNAME="Haiku"
  wg "unsupported die"         "unsupported OS: Haiku"         "$T/out.log"
  wx "exit non-zero"           test "$RC" -ne 0
}

scenario_bootstrap_xdg_custom_dir() {
  # FIXED(I-19): after a clean headless bootstrap the idempotence marker
  # IS written — the installer mkdir -p's the marker's parent before
  # touching it, so a rerun short-circuits instead of re-bootstrapping.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  install -m 755 "$SHIMS/nvim" "$T/bin/nvim"
  run_install "$T" "$T/out.log" DWP_VIM_DIR="$T/home/.config/dwpvim" DWP_VIM_SOURCE="$FIXTURE"
  wg "custom DEST used"        "installed at $T/home/.config/dwpvim" "$T/out.log"
  wg "headless bootstrap"      "nvim --headless"               "$T/shim.log"
  wg "XDG parent composition"  "nvim-env XDG_CONFIG_HOME=$T/home/.config NVIM_APPNAME=dwpvim" "$T/shim.log"
  wx "marker under appname"    test -f "$T/home/.local/share/dwpvim/pckr/.dwp-vim-bootstrapped"
  wx "exit 0"                  test "$RC" -eq 0
}

scenario_delete_foreign_config() {
  # FIXED(I-3) + FIXED(I-4), real Lua: delete.lua leaves a foreign
  # config_dir in place, and a piped confirm (no tty, EOF) keeps the
  # default — the uninstall aborts without deleting anything.
  # delete.lua runs LIVE from the repo tree (like install.sh above) —
  # a fixture clone would carry the last commit, not this working tree.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  ln -s "$(command -v lua5.4)" "$T/bin/lua5.4"
  # Review R1 (final review): the foreign config also carries a
  # packer-style lua/plugins.lua and NO install.lua — the identity
  # predicate must require BOTH marker files, or this exact shape gets
  # queued for deletion.
  mkdir -p "$T/home/.config/nvim/lua"
  echo "foreign init.vim" >"$T/home/.config/nvim/init.vim"
  echo "return {}" >"$T/home/.config/nvim/lua/plugins.lua"
  RC=0
  env -i HOME="$T/home" PATH="$NEUTRAL_DIR:$T/bin:$BASE_BIN" \
    lua5.4 "$REPO/delete.lua" \
    </dev/null >"$T/out.log" 2>&1 || RC=$?
  wg "foreign config left in place" "left in place"  "$T/out.log"
  wg "uninstall aborted (default No)" "Aborted"      "$T/out.log"
  # The target-line why-text "(this repo…)" only appears when the
  # config_dir IS queued; the left-in-place NOTE shares the phrase.
  wng "not queued as a removal target" "DeepWorkPlan Vim config (this repo" "$T/out.log"
  wx "exit 0"          test "$RC" -eq 0
  wx "foreign intact"  test "$(cat "$T/home/.config/nvim/init.vim")" = "foreign init.vim"
  wx "plugins.lua intact" test "$(cat "$T/home/.config/nvim/lua/plugins.lua")" = "return {}"
  wx "no data dirs removed" test ! -e "$T/home/.local/share/nvim"
}

scenario_update_diverged_local() {
  # Review R2 (final review): a local main that diverged from the source
  # must die loudly — never complete rc 0 with the success banner while
  # silently staying on the old commit.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  git clone -q "$FIXTURE" "$T/home/.config/nvim"
  git -C "$T/home/.config/nvim" -c user.email=t@example.com -c user.name=t \
    commit -q --allow-empty -m "local edit"
  local LOCAL_HEAD; LOCAL_HEAD="$(git -C "$T/home/.config/nvim" rev-parse HEAD)"
  run_install "$T" "$T/out.log" DWP_VIM_SOURCE="$FIXTURE"
  wg "divergence named"  "update skipped"  "$T/out.log"
  wng "no success banner" "System setup finished" "$T/out.log"
  wng "setup not run"     "Running the system setup" "$T/out.log"
  wx "rc non-zero"        test "$RC" -ne 0
  wx "still a git repo"   test -d "$T/home/.config/nvim/.git"
  wx "local commit intact" test "$(git -C "$T/home/.config/nvim" rev-parse HEAD)" = "$LOCAL_HEAD"
}

scenario_bootstrap_already_installed() {
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  install -m 755 "$SHIMS/nvim" "$T/bin/nvim"
  git clone -q "$FIXTURE" "$T/home/.config/nvim"
  mkdir -p "$T/home/.local/share/nvim/pckr"
  touch "$T/home/.local/share/nvim/pckr/.dwp-vim-bootstrapped"
  run_install "$T" "$T/out.log"
  wg "already installed"       "Plugins already installed"     "$T/out.log"
  wng "bootstrap skipped"      "nvim --headless"               "$T/shim.log"
  wx "exit 0"                  test "$RC" -eq 0
}

# --- run them all -----------------------------------------------------------

echo "== installer compatibility harness =="
run_scenario fresh_apt                   scenario_fresh_apt
run_scenario fresh_dnf                   scenario_fresh_dnf
run_scenario fresh_pacman                scenario_fresh_pacman
run_scenario fresh_brew                  scenario_fresh_brew
run_scenario update_ours                 scenario_update_ours
run_scenario update_ours_source          scenario_update_ours_source
run_scenario not_ours_local_path         scenario_not_ours_local_path
run_scenario foreign_piped               scenario_foreign_piped
run_scenario foreign_interactive_yes     scenario_foreign_interactive_yes
run_scenario backup_collision            scenario_backup_collision
run_scenario dest_is_file                scenario_dest_is_file
run_scenario unsupported_os_mingw        scenario_unsupported_os_mingw
run_scenario unsupported_os_unknown      scenario_unsupported_os_unknown
run_scenario bootstrap_xdg_custom_dir    scenario_bootstrap_xdg_custom_dir
run_scenario update_diverged_local     scenario_update_diverged_local
run_scenario delete_foreign_config      scenario_delete_foreign_config
run_scenario bootstrap_already_installed scenario_bootstrap_already_installed

TOTAL=$((TOTAL_PASS+TOTAL_FAIL))
if [ "$TOTAL_FAIL" -eq 0 ] && [ "$TOTAL" -ge 11 ]; then
  echo "INSTALLER HARNESS: OK ($TOTAL scenarios)"
  exit 0
fi
echo "INSTALLER HARNESS: FAILED (pass=$TOTAL_PASS fail=$TOTAL_FAIL of $TOTAL)"
exit 1
