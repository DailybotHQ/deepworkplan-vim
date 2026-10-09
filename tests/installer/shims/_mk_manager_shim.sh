#!/usr/bin/env bash
# Generates the dnf/pacman/brew shims from the apt-get template: the
# only difference between manager shims is the argv prefix they log.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
for m in dnf pacman brew; do
  sed "s/^# tests\/installer\/shims\/apt-get /# tests\/installer\/shims\/$m /; s/apt-get %s\\\\n/$m %s\\\\n/" \
    "$here/apt-get" >"$here/$m"
  chmod +x "$here/$m"
done
echo "generated: dnf pacman brew"
