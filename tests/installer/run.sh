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
# The fixture stands in for the remote, whose default branch is 'main'
# (clones of the fixture follow its HEAD). A clone only creates the
# source's CURRENT branch, so when the harness runs from a feature branch
# the fixture would have no 'main' at all: point 'main' at the commit under
# test and check it out (a no-op when the harness already runs on 'main').
git -C "$FIXTURE" checkout -q -B main
# install.sh installs the release tag baked into it (RELEASE_REF) unless
# DWP_VIM_REF says otherwise. Before that release exists, and to test the
# commit under test rather than the published one, the fixture carries the
# tag — annotated, like real releases — on its main.
RELEASE_REF="$(sed -n 's/^RELEASE_REF="\(.*\)"$/\1/p' "$REPO/install.sh")"
[ -n "$RELEASE_REF" ] || { echo "install.sh has no RELEASE_REF line" >&2; exit 1; }
git -C "$FIXTURE" -c user.name=t -c user.email=t@example.com \
  tag -f -a "$RELEASE_REF" -m "fixture release $RELEASE_REF" >/dev/null

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

# pty_answer <input> <command-string> — run the command on a pseudo-terminal
# with <input> typed into it; the exit status is the command's.
# util-linux script: -qec runs the command and forwards its exit status.
# BSD script (macOS): there is no -c; and when stdin reaches end-of-input it
# forwards ^D, which can overtake the typed answer — so stdin is held open
# until the command has exited (bounded at 60 s).
pty_answer() {
  local input="$1" cmd="$2" done_flag n
  if script -qec true /dev/null >/dev/null 2>&1; then
    printf '%s' "$input" | script -qec "$cmd" /dev/null
    return
  fi
  done_flag="$WORK/pty_done.$$.$RANDOM"   # inside $WORK: the EXIT trap removes it
  { printf '%s' "$input"
    n=0
    while [ ! -e "$done_flag" ] && [ "$n" -lt 300 ]; do sleep 0.2; n=$((n+1)); done
  } | { script -q /dev/null bash -c "$cmd"; rc=$?; : >"$done_flag"; exit "$rc"; }
  local status=$?
  rm -f "$done_flag"
  return "$status"
}

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

run_install_piped() { # run_install_piped <T> <out-file> [VAR=value...] — sets RC
  # The script arrives through a PIPE, exactly as when a download is piped
  # into bash (a file redirect is seekable and would hide a stray stdin
  # read): nothing in it may consume stdin, and with no terminal the
  # consent gate must stay safe.
  local T="$1" out="$2"; shift 2
  RC=0
  cat "$REPO/install.sh" | env -i HOME="$T/home" PATH="$NEUTRAL_DIR:$T/bin:$BASE_BIN" \
    SHIM_LOG="$T/shim.log" SHIM_BIN="$T/bin" \
    "$@" bash >"$out" 2>&1 || RC=$?
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
  wg "uninstall mirror row"    "Remove"                        "$T/out.log"
  wg "uninstall mirror names delete.lua" "delete.lua"          "$T/out.log"
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
  wg "updating to ref"         "updating to '$RELEASE_REF'"    "$T/out.log"
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
  pty_answer $'y\n' \
    "env -i HOME=$T/home PATH=$NEUTRAL_DIR:$T/bin:$BASE_BIN SHIM_LOG=$T/shim.log SHIM_BIN=$T/bin DWP_VIM_SOURCE=$FIXTURE bash $REPO/install.sh" \
    >"$T/out.log" 2>&1 || rc=$?
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
  # Review R2 (final review): a local commit the source does not have must
  # die loudly — never complete rc 0 with the success banner while silently
  # staying on (or leaving behind) the local work. Default ref = the
  # release tag, so this exercises the tag path.
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

scenario_update_diverged_local_main() {
  # The same R2 rule on the branch path (DWP_VIM_REF=main).
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  git clone -q "$FIXTURE" "$T/home/.config/nvim"
  git -C "$T/home/.config/nvim" -c user.email=t@example.com -c user.name=t \
    commit -q --allow-empty -m "local edit"
  local LOCAL_HEAD; LOCAL_HEAD="$(git -C "$T/home/.config/nvim" rev-parse HEAD)"
  run_install "$T" "$T/out.log" DWP_VIM_SOURCE="$FIXTURE" DWP_VIM_REF=main
  wg "divergence named"   "update skipped"            "$T/out.log"
  wng "setup not run"     "Running the system setup"  "$T/out.log"
  wx "rc non-zero"        test "$RC" -ne 0
  wx "local commit intact" test "$(git -C "$T/home/.config/nvim" rev-parse HEAD)" = "$LOCAL_HEAD"
}

scenario_ref_default_release_tag() {
  # A5: with no DWP_VIM_REF the fresh install lands exactly on the release
  # tag baked into install.sh (detached), never on the moving main.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  run_install "$T" "$T/out.log" DWP_VIM_SOURCE="$FIXTURE"
  local D="$T/home/.config/nvim"
  wg "clone names the tag"  "Cloning DeepWorkPlan Vim ('$RELEASE_REF')" "$T/out.log"
  wg "version row"          "Version       $RELEASE_REF"  "$T/out.log"
  wng "no detached advice"  "detached HEAD"               "$T/out.log"
  wx "exit 0"               test "$RC" -eq 0
  wx "HEAD is exactly the tag" test "$(git -C "$D" describe --tags --exact-match HEAD 2>/dev/null)" = "$RELEASE_REF"
  wx "HEAD detached (not main)" test -z "$(git -C "$D" symbolic-ref -q HEAD)"
}

scenario_ref_main_explicit() {
  # DWP_VIM_REF=main is the explicit opt-in to the moving branch.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  run_install "$T" "$T/out.log" DWP_VIM_SOURCE="$FIXTURE" DWP_VIM_REF=main
  wg "clone names main"    "Cloning DeepWorkPlan Vim ('main')" "$T/out.log"
  wx "exit 0"              test "$RC" -eq 0
  wx "on branch main"      test "$(git -C "$T/home/.config/nvim" symbolic-ref -q HEAD)" = "refs/heads/main"
}

scenario_update_older_to_tag() {
  # An install on an older upstream commit (e.g. a v0.4.0 install that
  # followed main) moves to the release tag; its local branch is kept.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  local D="$T/home/.config/nvim"
  git clone -q "$FIXTURE" "$D"
  git -C "$D" reset -q --hard HEAD~1
  local OLD; OLD="$(git -C "$D" rev-parse HEAD)"
  run_install "$T" "$T/out.log"
  wng "not refused"        "update skipped"              "$T/out.log"
  wg "setup ran"           "Running the system setup"    "$T/out.log"
  wx "exit 0"              test "$RC" -eq 0
  wx "HEAD is the tag"     test "$(git -C "$D" describe --tags --exact-match HEAD 2>/dev/null)" = "$RELEASE_REF"
  wx "local main kept"     test "$(git -C "$D" rev-parse refs/heads/main)" = "$OLD"
}

scenario_skip_packages_missing_tool() {
  # DWP_VIM_SKIP_PACKAGES=1 never calls a package manager: a missing tool
  # stops the run before anything is cloned.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/apt-get" "$T/bin/apt-get"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  run_install "$T" "$T/out.log" FAKE_UID=1000 DWP_VIM_SOURCE="$FIXTURE" DWP_VIM_SKIP_PACKAGES=1
  wg "names the switch"    "DWP_VIM_SKIP_PACKAGES is set" "$T/out.log"
  wg "names the missing"   "missing: lua"                 "$T/out.log"
  wng "no manager call"    "apt-get"                      "$T/shim.log"
  wx "rc non-zero"         test "$RC" -ne 0
  wx "nothing cloned"      test ! -e "$T/home/.config/nvim"
}

scenario_skip_packages_present() {
  # With every tool present the run completes, installs no package, and
  # hands the switch to install.lua.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/apt-get" "$T/bin/apt-get"
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  run_install "$T" "$T/out.log" FAKE_UID=1000 DWP_VIM_SOURCE="$FIXTURE" DWP_VIM_SKIP_PACKAGES=1
  wg "announced"           "no system packages will be installed" "$T/out.log"
  wg "passed to install.lua" "lua5.4 install.lua skip_packages=1" "$T/shim.log"
  wng "no manager call"    "apt-get"                      "$T/shim.log"
  wx "exit 0"              test "$RC" -eq 0
}

scenario_skip_packages_zero_is_off() {
  # 0 means off: the preflight installs the missing tool as usual and
  # install.lua is not told to skip.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/apt-get" "$T/bin/apt-get"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  run_install "$T" "$T/out.log" FAKE_UID=1000 DWP_VIM_SOURCE="$FIXTURE" DWP_VIM_SKIP_PACKAGES=0
  wg "lua installed"       "apt-get install -y lua5.4"    "$T/shim.log"
  wng "switch not passed"  "skip_packages="               "$T/shim.log"
  wx "exit 0"              test "$RC" -eq 0
}

scenario_pnpm_fallback_no_pipe() {
  # The REAL installer.lua ensure_pnpm() under the host's real lua5.4 with
  # a stubbed util: pnpm comes from npm (pinned major, no lifecycle scripts,
  # user prefix), npm is added on its own apt call only when missing, an old
  # Node.js fails clearly, and nothing it runs pipes a download into a shell.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  local L="$REPO/tests/installer/lua/pnpm_fallback.lua"
  lua5.4 "$L" "$REPO" unix npm 22 >"$T/unix.log" 2>&1
  lua5.4 "$L" "$REPO" windows npm 22 >"$T/win.log" 2>&1
  lua5.4 "$L" "$REPO" unix no-npm 22 >"$T/nonpm.log" 2>&1
  lua5.4 "$L" "$REPO" unix apt-adds-npm 22 >"$T/aptnpm.log" 2>&1
  lua5.4 "$L" "$REPO" unix npm 12 >"$T/oldnode.log" 2>&1
  lua5.4 "$L" "$REPO" unix npm 22 '/stub home/$x"q' >"$T/quote.log" 2>&1
  wg "unix: npm user prefix"  'EXEC npm install -g --ignore-scripts --prefix "/stub-home/.local/share/pnpm" pnpm@10' "$T/unix.log"
  wg "unix: result true"      "RESULT true"            "$T/unix.log"
  wg "windows: npm global"    "EXEC npm install -g --ignore-scripts pnpm@10" "$T/win.log"
  wg "apt adds npm alone"     "EXEC sudo apt-get update && sudo apt-get install -y npm" "$T/aptnpm.log"
  wg "then pnpm via npm"      "EXEC npm install -g --ignore-scripts --prefix" "$T/aptnpm.log"
  wg "no npm: clear failure"  "npm is not available"   "$T/nonpm.log"
  wg "no npm: result false"   "RESULT false"           "$T/nonpm.log"
  wg "old node: clear failure" "Node.js 12 is too old"  "$T/oldnode.log"
  wng "old node: no install"  "EXEC npm"               "$T/oldnode.log"
  wx "prefix quoted for sh"   grep -qF -- '--prefix "/stub home/\$x\"q/.local/share/pnpm"' "$T/quote.log"
  local f
  for f in "$T/unix.log" "$T/win.log" "$T/aptnpm.log"; do
    wx "no pipe in $(basename "$f")" test -z "$(grep 'EXEC' "$f" | grep '|')"
  done
}

scenario_piped_stdin_fresh() {
  # The URL piped into bash keeps working: a fresh install completes from a
  # script read on stdin and lands on the release tag.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  install -m 755 "$SHIMS/nvim" "$T/bin/nvim"
  run_install_piped "$T" "$T/out.log" DWP_VIM_SOURCE="$FIXTURE" SHIM_STDIN_LOG="$T/lua_stdin.log"
  wg "completion line"     "DeepWorkPlan Vim is installed at" "$T/out.log"
  wx "install.lua read no script text from stdin" test -e "$T/lua_stdin.log" -a ! -s "$T/lua_stdin.log"
  wg "lua leg ran (stub)"  "lua5.4 install.lua"               "$T/shim.log"
  wg "bootstrap ran"       "nvim --headless"                  "$T/shim.log"
  wx "exit 0"              test "$RC" -eq 0
  wx "on the release tag"  test "$(git -C "$T/home/.config/nvim" describe --tags --exact-match HEAD 2>/dev/null)" = "$RELEASE_REF"
}

scenario_piped_stdin_foreign_safe() {
  # Piped with no terminal, an existing foreign config is never touched.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  install -m 755 "$SHIMS/lua5.4" "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  mkdir -p "$T/home/.config/nvim"
  echo "-- mine" >"$T/home/.config/nvim/init.lua"
  run_install_piped "$T" "$T/out.log" DWP_VIM_SOURCE="$FIXTURE"
  wg "cannot ask unattended" "ran without a terminal"          "$T/out.log"
  wng "setup not run"        "Running the system setup"        "$T/out.log"
  wx "rc non-zero"           test "$RC" -ne 0
  wx "foreign config intact" test "$(cat "$T/home/.config/nvim/init.lua")" = "-- mine"
  wx "no backup made"        test ! -e "$T/home/.config/previous-deepworkplan-vim"
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

scenario_lua_failure_handoff() {
  # UX2-03: a failed system-setup leg ends with a paste-able agent
  # handoff naming the fails.log path — ADDED to the existing log +
  # issues lines, never replacing them (both are still asserted).
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  # A lua5.4 that always fails: the system-setup leg must die, not pass.
  printf '#!/bin/sh\necho "simulated setup failure" >&2\nexit 1\n' >"$T/bin/lua5.4"
  chmod 755 "$T/bin/lua5.4"
  install -m 755 "$SHIMS/curl" "$T/bin/curl"
  run_install "$T" "$T/out.log" FAKE_UID=1000 DWP_VIM_SOURCE="$FIXTURE"
  wg "failure names its log"   "fails.log"                     "$T/out.log"
  wg "agent handoff sentence"  "hand it to your agent"         "$T/out.log"
  wg "paste line names the log" "Read $T/home/.config/nvim/fails.log" "$T/out.log"
  wg "issues url kept"         "issues/new"                    "$T/out.log"
  wx "exit non-zero"           test "$RC" -ne 0
}

scenario_delete_one_liner() {
  # UX2-04: the advertised one-liner — delete.lua invoked by absolute
  # path from an unrelated cwd — removes a DeepWorkPlan Vim install
  # under a synthetic root after its consent question (real lua5.4;
  # piped 'y' answers it). The config dir is a full fixture clone —
  # delete.lua requires utilities/installation from its own tree.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  ln -s "$(command -v lua5.4)" "$T/bin/lua5.4"
  git clone -q "$FIXTURE" "$T/home/.config/nvim"
  mkdir -p "$T/home/.local/share/nvim/pckr"
  : >"$T/home/.local/share/nvim/pckr/.dwp-vim-bootstrapped"
  RC=0
  (
    cd "$T"
    printf 'y\n' | env -i HOME="$T/home" PATH="$NEUTRAL_DIR:$T/bin:$BASE_BIN" \
      lua5.4 "$T/home/.config/nvim/delete.lua"
  ) >"$T/out.log" 2>&1 || RC=$?
  wg "config queued as target" "DeepWorkPlan Vim config"       "$T/out.log"
  wg "uninstall finished"      "user data is gone"             "$T/out.log"
  wx "exit 0"                  test "$RC" -eq 0
  wx "config dir removed"      test ! -e "$T/home/.config/nvim"
  wx "data dir removed"        test ! -e "$T/home/.local/share/nvim"
}

scenario_consent_eof_safe() {
  # R4 (PLAN_004 final review): absent input on a consent question must
  # resolve to the SAFE answer on every platform path. cli.confirm now
  # reports HOW it answered (second return: eof|default|yes|no|answered),
  # and util.replace_old treats eof as "no answer" — neither branch of
  # its question (Yes moves the config, No deletes it) may auto-taken.
  # Probes run the real lua5.4 modules from the repo cwd.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  ln -s "$(command -v lua5.4)" "$T/bin/lua5.4"
  local LUA_ENV="HOME=$T/home PATH=$NEUTRAL_DIR:$T/bin:$BASE_BIN"

  # 1-2. Line-mode EOF is eof, on both defaults (pre-fix: nil source).
  RC=0
  env -i $LUA_ENV lua5.4 -e 'local c=require("utilities.installation.cli") local v,s=c.confirm("Q?",true) io.write(tostring(v).." "..tostring(s).."\n")' \
    </dev/null >"$T/eof_yes.log" 2>&1 || RC=$?
  wg "EOF default-yes => true+eof" "true eof"    "$T/eof_yes.log"
  RC=0
  env -i $LUA_ENV lua5.4 -e 'local c=require("utilities.installation.cli") local v,s=c.confirm("Q?",false) io.write(tostring(v).." "..tostring(s).."\n")' \
    </dev/null >"$T/eof_no.log" 2>&1 || RC=$?
  wg "EOF default-no => false+eof" "false eof"   "$T/eof_no.log"

  # 3-4. An explicit empty line is a human accepting the default — a
  # different source than EOF; typed y/n are their own sources.
  RC=0
  printf '\n' | env -i $LUA_ENV lua5.4 -e 'local c=require("utilities.installation.cli") local v,s=c.confirm("Q?",false) io.write(tostring(v).." "..tostring(s).."\n")' \
    >"$T/empty.log" 2>&1 || RC=$?
  wg "empty line => default" "false default"     "$T/empty.log"
  RC=0
  printf 'y\n' | env -i $LUA_ENV lua5.4 -e 'local c=require("utilities.installation.cli") local v,s=c.confirm("Q?",false) io.write(tostring(v).." "..tostring(s).."\n")' \
    >"$T/yes.log" 2>&1 || RC=$?
  wg "typed y => yes" "true yes"                 "$T/yes.log"
  RC=0
  printf 'n\n' | env -i $LUA_ENV lua5.4 -e 'local c=require("utilities.installation.cli") local v,s=c.confirm("Q?",true) io.write(tostring(v).." "..tostring(s).."\n")' \
    >"$T/no.log" 2>&1 || RC=$?
  wg "typed n => no" "false no"                  "$T/no.log"

  # 5. replace_old on eof (unit probe simulating the Windows condition:
  #    io.open("/dev/tty") succeeds — Windows sets can_ask=true — and the
  #    cli.confirm stub returns exactly what the fixed line-mode returns
  #    on EOF, isolating replace_old's handling of it; production reach
  #    is a piped Windows run or Ctrl-D at a terminal): aborts, target
  #    intact, message says so.
  mkdir -p "$T/home/target-dir"; echo keep >"$T/home/target-dir/init.vim"
  RC=0
  env -i $LUA_ENV PROBE_TARGET="$T/home/target-dir" PROBE_BACKUP="$T/home/backup-dir" \
    lua5.4 -e 'local real_open=io.open io.open=function(p,m) if p=="/dev/tty" then return {close=function() end} end return real_open(p,m) end package.preload["utilities.installation.cli"]=function() return { confirm=function(q,d) return d~=false,"eof" end } end local u=require("utilities.installation.util") local ok=u.replace_old(os.getenv("PROBE_TARGET"),os.getenv("PROBE_BACKUP")) io.write("rc= "..(ok and "true" or "false").."\ntarget-intact= "..(u.path_exists(os.getenv("PROBE_TARGET")) and "yes" or "no").."\n")' \
    </dev/null >"$T/ro_eof.log" 2>&1 || RC=$?
  wg "eof aborts replace" "no answer"                       "$T/ro_eof.log"
  wg "eof leaves nothing touched" "Nothing was touched"     "$T/ro_eof.log"
  wg "eof result false" "rc= false"               "$T/ro_eof.log"
  wg "eof target intact" "target-intact= yes"    "$T/ro_eof.log"
  wx "target really intact" test -f "$T/home/target-dir/init.vim"
  wx "no backup materialized" test ! -e "$T/home/backup-dir"

  # 6. Regression guard, real legs: the Unix no-tty gate in replace_old
  #    still aborts a piped run (nothing weakened by the eof source).
  mkdir -p "$T/home/target2"; echo keep >"$T/home/target2/init.vim"
  RC=0
  env -i $LUA_ENV PROBE_TARGET="$T/home/target2" PROBE_BACKUP="$T/home/backup2" \
    lua5.4 -e 'local u=require("utilities.installation.util") local ok=u.replace_old(os.getenv("PROBE_TARGET"),os.getenv("PROBE_BACKUP")) io.write("rc= "..(ok and "true" or "false").."\n")' \
    </dev/null >"$T/ro_notty.log" 2>&1 || RC=$?
  wg "unix no-tty gate message" "no terminal to ask"        "$T/ro_notty.log"
  wg "unix gate false" "rc= false"                "$T/ro_notty.log"
  wx "unix gate target intact" test -f "$T/home/target2/init.vim"
}

scenario_realpath_bsd_fallback() {
  # I-7 (PLAN_004 audit): when GNU realpath -m is unavailable — macOS BSD
  # realpath rejects -m, some minimal images lack realpath entirely —
  # util.realpath must still resolve the path in pure Lua (expand ~,
  # make absolute, normalize . / .. / //) instead of returning the input
  # unresolved. Probes call the real module from the repo cwd.
  local T; T="$(scen_root)"
  trap "rm -rf '$T'" EXIT
  ln -s "$(command -v lua5.4)" "$T/bin/lua5.4"
  local LUA_ENV="HOME=$T/home PATH=$NEUTRAL_DIR:$T/bin:$BASE_BIN"

  # A. BSD-style realpath on PATH: rejects -m (the util's probe flag).
  cat >"$T/bin/realpath" <<'SH'
#!/bin/sh
# Models macOS BSD realpath: -m and -- are illegal options.
for a in "$@"; do
  case "$a" in
    -m*|--*) echo "realpath: illegal option -- ${a#-}" >&2; exit 1 ;;
  esac
done
exec /usr/bin/realpath "$@"
SH
  chmod 755 "$T/bin/realpath"
  RC=0
  env -i $LUA_ENV lua5.4 -e 'local u=require("utilities.installation.util") io.write("A "..u.realpath("~/.config/nvim").."\n")' \
    >"$T/a.log" 2>&1 || RC=$?
  wg "tilde expanded to HOME" "A $T/home/.config/nvim" "$T/a.log"
  wng "no literal tilde survives" "~"                      "$T/a.log"

  # B. No realpath on PATH at all: a relative path still resolves to the
  #    physical cwd with . / .. collapsed (harness PATH has no realpath).
  local PHYS; PHYS="$(pwd -P)"
  RC=0
  env -i $LUA_ENV lua5.4 -e 'local u=require("utilities.installation.util") io.write("B "..u.realpath("./sub/../nvim").."\n")' \
    >"$T/b.log" 2>&1 || RC=$?
  wg "relative normalized to cwd" "B $PHYS/nvim"           "$T/b.log"

  # C. Guard semantics intact: the resolved ~ path is under the resolved
  #    HOME and not under an unrelated sibling (regression guard for the
  #    run-from-inside check, install.lua's path_is_under clause).
  RC=0
  env -i $LUA_ENV lua5.4 -e 'local u=require("utilities.installation.util") local r=u.realpath("~/.config/nvim") io.write("C "..tostring(u.path_is_under(r,u.realpath("~"))).." "..tostring(u.path_is_under(r,u.realpath("~/elsewhere"))).."\n")' \
    >"$T/c.log" 2>&1 || RC=$?
  wg "under HOME, not under sibling" "C true false"        "$T/c.log"
}

# --- run them all -----------------------------------------------------------

echo "== installer compatibility harness =="
run_scenario ref_default_release_tag     scenario_ref_default_release_tag
run_scenario ref_main_explicit           scenario_ref_main_explicit
run_scenario update_older_to_tag         scenario_update_older_to_tag
run_scenario update_diverged_local_main  scenario_update_diverged_local_main
run_scenario skip_packages_missing_tool  scenario_skip_packages_missing_tool
run_scenario skip_packages_present       scenario_skip_packages_present
run_scenario skip_packages_zero_is_off   scenario_skip_packages_zero_is_off
run_scenario pnpm_fallback_no_pipe       scenario_pnpm_fallback_no_pipe
run_scenario piped_stdin_fresh           scenario_piped_stdin_fresh
run_scenario piped_stdin_foreign_safe    scenario_piped_stdin_foreign_safe
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
run_scenario lua_failure_handoff        scenario_lua_failure_handoff
run_scenario delete_one_liner           scenario_delete_one_liner
run_scenario consent_eof_safe           scenario_consent_eof_safe
run_scenario realpath_bsd_fallback      scenario_realpath_bsd_fallback

TOTAL=$((TOTAL_PASS+TOTAL_FAIL))
if [ "$TOTAL_FAIL" -eq 0 ] && [ "$TOTAL" -ge 11 ]; then
  echo "INSTALLER HARNESS: OK ($TOTAL scenarios)"
  exit 0
fi
echo "INSTALLER HARNESS: FAILED (pass=$TOTAL_PASS fail=$TOTAL_FAIL of $TOTAL)"
exit 1
