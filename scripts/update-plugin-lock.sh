#!/usr/bin/env bash
# Refresh pckr/lockfile.lua — the commit every plugin (and pckr itself) is
# installed at. Maintainers only; users never run this.
#
#   1. update  — in a throwaway HOME (mktemp -d, left in place), sync every
#                plugin of lua/plugin_specs.lua to its branch tip with the
#                pins ignored (DWP_VIM_LOCK_UPDATE=1), then write each
#                checkout's HEAD in pckr's lockfile format, sorted.
#   2. test    — a second throwaway HOME installs from the NEW lock and
#                every plugin HEAD must equal its pin (the same check as
#                install.sh --strict); then the smoke suite (lock coverage
#                included) and the installer harness.
#   3. commit  — with --commit, commit pckr/lockfile.lua alone as
#                "chore(deps): refresh the plugin lock", listing what moved.
#
# The real ~/.config/nvim and ~/.local/share/nvim are never touched: HOME
# and every XDG directory point into the throwaway directory, and the
# config there is a link to this checkout. A lock change ships in the next
# release (surface.json version, install.sh RELEASE_REF, CHANGELOG — see
# CONTRIBUTING.md), like any other change.
#
# Usage: scripts/update-plugin-lock.sh [--commit] [--skip-tests]
# Needs: bash, git, nvim (0.12+), network; the tests need lua5.4.
# Env: DWP_VIM_LOCK_TIMEOUT (seconds per headless sync, default 900).
# Exit: 0 refreshed (or unchanged), 1 failed, 2 usage.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd -P)"
LOCK="pckr/lockfile.lua"
PCKR_URL="https://github.com/lewis6991/pckr.nvim"
TIMEOUT="${DWP_VIM_LOCK_TIMEOUT:-900}"

commit=0
tests=1
for arg in "$@"; do
	case "$arg" in
	--commit) commit=1 ;;
	--skip-tests) tests=0 ;;
	-h | --help)
		sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "update-plugin-lock: unknown option $arg" >&2
		exit 2
		;;
	esac
done
case "$TIMEOUT" in '' | *[!0-9]*)
	echo "update-plugin-lock: DWP_VIM_LOCK_TIMEOUT must be a number of seconds" >&2
	exit 2
	;;
esac
for tool in git nvim; do
	command -v "$tool" >/dev/null 2>&1 || {
		echo "update-plugin-lock: $tool not found" >&2
		exit 1
	}
done
if [ "$commit" -eq 1 ] && ! { git diff --quiet -- "$LOCK" && git diff --cached --quiet -- "$LOCK"; }; then
	echo "update-plugin-lock: $LOCK has uncommitted changes; commit or restore it first" >&2
	exit 1
fi

W="$(mktemp -d "${TMPDIR:-/tmp}/dwp-vim-lock.XXXXXX")" || exit 1
echo "== workspace: $W (left in place)"

# sync_into <dir> <lock-update 0|1>: a headless first install of this
# checkout under <dir>, exactly as install.sh bootstraps one.
sync_into() {
	local root="$1" update="$2" log="$1.log"
	mkdir -p "$root/home" "$root/config"
	ln -s "$REPO" "$root/config/nvim"
	local runner=()
	if command -v timeout >/dev/null 2>&1; then runner=(timeout "$TIMEOUT"); fi
	# env -i + an allowlist: the sync runs plugin code nobody has reviewed yet
	# (branch tips, their build hooks), so it gets no credentials, agent
	# sockets or tokens from this shell — only what a build needs.
	if ! env -i PATH="$PATH" LANG="${LANG:-C.UTF-8}" TERM="${TERM:-dumb}" TMPDIR="${TMPDIR:-/tmp}" \
		HOME="$root/home" XDG_CONFIG_HOME="$root/config" \
		XDG_DATA_HOME="$root/home/.local/share" XDG_STATE_HOME="$root/home/.local/state" \
		XDG_CACHE_HOME="$root/home/.cache" \
		DWP_VIM_BOOTSTRAP=1 DWP_VIM_LOCK_UPDATE="$update" \
		${runner[@]+"${runner[@]}"} nvim --headless >"$log" 2>&1 </dev/null; then
		echo "update-plugin-lock: headless sync failed in $root (log: $log)" >&2
		tail -n 20 "$log" >&2
		return 1
	fi
}

# heads <root>: "<url> <sha>" for pckr and every installed plugin, sorted.
# An empty clone (no tracked file) is an error, not an entry.
heads() {
	local data="$1/home/.local/share/nvim" dir url
	for dir in "$data/pckr/pckr.nvim" "$data"/site/pack/pckr/opt/* "$data"/site/pack/pckr/start/*; do
		[ -d "$dir/.git" ] || continue
		if [ -z "$(git -C "$dir" ls-files | head -n 1)" ]; then
			echo "update-plugin-lock: empty clone: $dir" >&2
			return 1
		fi
		if [ "$dir" = "$data/pckr/pckr.nvim" ]; then
			url="$PCKR_URL"
		else
			url="$(git -C "$dir" remote get-url origin)"
			url="${url%.git}" # pckr's key: plugin.url without .git
		fi
		printf '%s %s\n' "$url" "$(git -C "$dir" rev-parse HEAD)"
	done | LC_ALL=C sort
}

# --- 1. update ---------------------------------------------------------
echo "== syncing every plugin to its branch tip (pins ignored)"
sync_into "$W/update" 1
heads "$W/update" >"$W/heads.txt"
n="$(wc -l <"$W/heads.txt" | tr -d ' ')"
grep -q "^$PCKR_URL " "$W/heads.txt" || {
	echo "update-plugin-lock: pckr.nvim was not installed" >&2
	exit 1
}
cp "$LOCK" "$W/lockfile.before.lua" 2>/dev/null || : >"$W/lockfile.before.lua"
mkdir -p "$(dirname "$LOCK")"
{
	echo "return {"
	while read -r url sha; do
		printf '  ["%s"] = { commit = "%s" },\n' "$url" "$sha"
	done <"$W/heads.txt"
	echo "}"
} >"$LOCK"
echo "== wrote $LOCK ($n repositories)"
if cmp -s "$W/lockfile.before.lua" "$LOCK"; then
	echo "== lock unchanged: every pin is already at its branch tip"
	changed=0
else
	changed=1
fi

# --- 2. test -------------------------------------------------------------
if [ "$tests" -eq 1 ]; then
	echo "== installing from the new lock in a fresh HOME"
	sync_into "$W/verify" 0
	heads "$W/verify" >"$W/verify.txt"
	if ! diff -u "$W/heads.txt" "$W/verify.txt"; then
		echo "update-plugin-lock: a pinned install does not match the lock (diff above)" >&2
		exit 1
	fi
	echo "== pinned install matches the lock ($n repositories)"
	bash tests/smoke/run.sh
	bash tests/installer/run.sh
fi

# --- 3. commit -----------------------------------------------------------
if [ "$commit" -eq 1 ] && [ "$changed" -eq 1 ]; then
	# Lock keys are pckr's plugin.url (no .git): "> " lines are new pins,
	# "< " lines whose plugin has no new pin were removed.
	moved="$(diff "$W/lockfile.before.lua" "$LOCK" | sed -n 's/^> *\["https:\/\/github.com\/\(.*\)"\] = { commit = "\(.......\).*/- \1 -> \2/p')"
	[ -n "$moved" ] || moved="- (no pin moved; format only)"
	if [ "$tests" -eq 1 ]; then
		how="verified by a pinned reinstall and the test suites"
	else
		how="NOT verified: --skip-tests"
	fi
	git commit -q -m "chore(deps): refresh the plugin lock" -m "Moved to the branch tip ($how):
$moved" -- "$LOCK"
	echo "== committed: $(git log --oneline -1)"
elif [ "$commit" -eq 1 ]; then
	echo "== nothing to commit"
fi
echo "PLUGIN LOCK: OK ($n repositories)"
