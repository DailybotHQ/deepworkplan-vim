#!/usr/bin/env bash
# Print the CHANGELOG.md section of one release (its body, without the
# "## [vX.Y.Z] - date" heading), for the GitHub release notes.
# Accepts both "## [vX.Y.Z] - date" and the older "## vX.Y.Z — date".
#
# Usage: scripts/release-notes.sh vX.Y.Z [changelog]
# Exit: 0 printed, 1 no section (or an empty one) for that tag, 2 usage.
set -euo pipefail

tag="${1:?usage: release-notes.sh vX.Y.Z [changelog]}"
file="${2:-$(git rev-parse --show-toplevel)/CHANGELOG.md}"
case "$tag" in v[0-9]*) ;; *)
	echo "release-notes: not a vX.Y.Z tag: $tag" >&2
	exit 2
	;;
esac

body="$(awk -v tag="$tag" '
	/^## / {
		if (found) exit
		h = $0
		sub(/^## \[?/, "", h)
		sub(/[] ].*$/, "", h)
		if (h == tag) { found = 1; next }
	}
	/^\[[^]]+\]: / && found { exit }
	found { print }
' "$file")"

# Trim leading and trailing blank lines.
body="$(printf '%s\n' "$body" | sed -e '/./,$!d')"
if [ -z "$(printf '%s' "$body" | tr -d '[:space:]')" ]; then
	echo "release-notes: CHANGELOG has no section for $tag — add '## [$tag] - YYYY-MM-DD' before releasing" >&2
	exit 1
fi
printf '%s\n' "$body"
