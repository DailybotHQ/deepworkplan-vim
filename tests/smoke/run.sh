#!/usr/bin/env bash
# dwp smoke suite — host-runnable (needs only bash + nvim; no container,
# no plugin sync, no network). Each section is a headless nvim run over
# the repo's lua/ tree with a minimal runtime (tests/smoke/minimal_init.lua).
# Task sections are appended by the plan tasks that own them; every
# section must pass for this script to exit 0.
set -u
cd "$(dirname "$0")/../.."

overall=0

run_smoke() {
	local label="$1" script="$2"
	echo "== dwp ${label} smoke =="
	local out
	out=$(nvim --headless -u tests/smoke/minimal_init.lua \
		-c "luafile ${script}" +qa! 2>&1)
	echo "$out"
	# The OK sentinel must appear AND no Lua error may have aborted the
	# script (nvim can exit 0 after an E5113 crash mid-script).
	if echo "$out" | grep -q "assertions OK" && ! echo "$out" | grep -q "^Error in command line"; then
		echo "-- ${label}: PASS"
	else
		echo "-- ${label}: FAIL"
		overall=1
	fi
}

run_smoke model tests/smoke/dwp_model.lua
run_smoke sidebar tests/smoke/dwp_sidebar.lua
run_smoke reader tests/smoke/dwp_reader.lua
run_smoke statusline tests/smoke/dwp_statusline.lua
run_smoke greeter tests/smoke/dwp_greeter.lua
run_smoke render tests/smoke/dwp_render.lua
run_smoke consistency tests/smoke/dwp_consistency.lua
run_smoke "self-contained" tests/smoke/dwp_self_contained.lua
run_smoke "addon surface" tests/smoke/addon_surface.lua
run_smoke "plugin lock" tests/smoke/plugin_lock.lua
run_smoke "npm guard" tests/smoke/npm_guard.lua

if [ "$overall" -eq 0 ]; then
	echo "DWP SMOKE SUITE: OK"
else
	echo "DWP SMOKE SUITE: FAILED"
fi
exit "$overall"
