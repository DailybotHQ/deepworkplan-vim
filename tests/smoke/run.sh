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
	if nvim --headless -u tests/smoke/minimal_init.lua \
		-c "luafile ${script}" +qa!; then
		echo "-- ${label}: PASS"
	else
		echo "-- ${label}: FAIL"
		overall=1
	fi
}

run_smoke model tests/smoke/dwp_model.lua

if [ "$overall" -eq 0 ]; then
	echo "DWP SMOKE SUITE: OK"
else
	echo "DWP SMOKE SUITE: FAILED"
fi
exit "$overall"
