#!/usr/bin/env bash
# Build the assets of one release from its tag, plus SHA256SUMS over them:
#   deepworkplan-vim-<tag>.tar.gz   source archive of the tagged tree
#   install.sh                      the installer at that tag
#   install.sh.sha256               "<sha256>  install.sh" — the file the
#                                   website publishes next to its copy
#   surface.json                    addon/surface.json at that tag (v0.4.0+)
# Everything is read from the tag with git, never from the working tree, so
# an old release's assets can be rebuilt and backfilled. install.sh and
# surface.json are byte-identical on every machine; the .tar.gz bytes depend
# on the git and gzip versions, so SHA256SUMS always describes the archive
# that was actually uploaded with it.
#
# Usage: scripts/release-assets.sh vX.Y.Z OUTDIR
# Exit: 0 built, 1 tag missing, 2 usage.
set -euo pipefail

tag="${1:-}"
out="${2:-}"
if [ -z "$tag" ] || [ -z "$out" ]; then
	echo "usage: release-assets.sh vX.Y.Z OUTDIR" >&2
	exit 2
fi
if ! git rev-parse -q --verify "refs/tags/$tag^{commit}" >/dev/null; then
	echo "release-assets: tag $tag does not exist" >&2
	exit 1
fi

mkdir -p "$out"
name="deepworkplan-vim-$tag"
git archive --format=tar --prefix="$name/" "$tag" | gzip -n -9 >"$out/$name.tar.gz"
if git cat-file -e "$tag:install.sh" 2>/dev/null; then
	git show "$tag:install.sh" >"$out/install.sh"
fi
if git cat-file -e "$tag:addon/surface.json" 2>/dev/null; then
	git show "$tag:addon/surface.json" >"$out/surface.json"
fi

if command -v sha256sum >/dev/null 2>&1; then
	sum() { sha256sum "$@"; }
else
	sum() { shasum -a 256 "$@"; }
fi
(
	cd "$out"
	files=()
	for f in "$name.tar.gz" install.sh surface.json; do
		[ -f "$f" ] && files+=("$f")
	done
	if [ -f install.sh ]; then
		sum install.sh >install.sh.sha256
		files+=(install.sh.sha256)
	fi
	sum "${files[@]}" >SHA256SUMS
)
echo "release-assets: $tag -> $out"
cat "$out/SHA256SUMS"
