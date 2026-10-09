#!/usr/bin/env bash
# tests/installer/container.sh — the image one-liner, proven in a real image.
#
# Runs install.sh exactly as an ecosystem Dockerfile does: in a Debian
# container, as a non-root user, without a terminal, the script read from a
# pipe with `bash -s --`, and the container-mode options:
#   --version <this release> --nvim <Neovim> --skip-packages --strict
# The image gets the dependencies an ecosystem image already carries (git,
# curl, Lua, a C toolchain for treesitter, Node.js + pnpm, fontconfig);
# install.sh replaces only the clone + install.lua + headless sync + plugin
# check block. The repository source is a bare clone of the commit under
# test carrying the release tag, so nothing is fetched from this
# repository's remote; Neovim (sha256-verified) and the plugins come from
# the network, as in a real build.
#
# Needs Docker (or Podman via DOCKER=podman) and network. Writes only to a
# fresh mktemp -d directory, left in place. Env: DWP_VIM_TEST_NVIM (Neovim
# release, default 0.12.5), DWP_VIM_TEST_IMAGE (base image), GITHUB_TOKEN
# (optional, passed through for the Neovim release API).
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1
REPO="$(pwd)"
DOCKER="${DOCKER:-docker}"
NVIM="${DWP_VIM_TEST_NVIM:-0.12.5}"
IMAGE="${DWP_VIM_TEST_IMAGE:-debian:trixie-20261005-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f}"

command -v "$DOCKER" >/dev/null 2>&1 || { echo "container.sh: $DOCKER not found" >&2; exit 2; }
RELEASE_REF="$(sed -n 's/^RELEASE_REF="\(.*\)"$/\1/p' install.sh)"
[ -n "$RELEASE_REF" ] || { echo "container.sh: install.sh has no RELEASE_REF line" >&2; exit 2; }

W="$(mktemp -d "${TMPDIR:-/tmp}/dwp-vim-container.XXXXXX")" || exit 1
# --no-local copies the objects (a local clone would hardlink them with the
# source's permissions, unreadable for the container user).
git clone -q --bare --no-local "$REPO" "$W/src.git"
git -C "$W/src.git" -c user.name=t -c user.email=t@example.com \
  tag -f -a "$RELEASE_REF" -m "container test release $RELEASE_REF" "$(git rev-parse HEAD)" >/dev/null
cp install.sh "$W/install.sh"
chmod -R a+rX "$W"
echo "== container install: $RELEASE_REF (commit $(git rev-parse --short HEAD)), Neovim $NVIM, image ${IMAGE%%@*}"

LOG="$W/container.log"
RC=0
"$DOCKER" run --rm -i \
  -e "RELEASE_VERSION=${RELEASE_REF#v}" -e "NVIM=$NVIM" -e GITHUB_TOKEN \
  -v "$W:/fixture:ro" \
  "$IMAGE" bash -euo pipefail -s >"$LOG" 2>&1 <<'IN_CONTAINER' || RC=$?
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  git curl ca-certificates lua5.4 tar gzip gcc make libc6-dev nodejs npm fontconfig >/dev/null
useradd -m -s /bin/bash dev
runuser -u dev -- env RELEASE_VERSION="$RELEASE_VERSION" NVIM="$NVIM" GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
  bash -euo pipefail -c '
  export PNPM_HOME="$HOME/.local/share/pnpm"
  export PATH="$PNPM_HOME/bin:$HOME/.local/bin:$PATH"
  npm install -g --prefix "$PNPM_HOME" pnpm@10 >/dev/null 2>&1
  # The source must belong to this user (git refuses foreign-owned repos).
  cp -R /fixture/src.git "$HOME/src.git"
  # The one-liner, with a local file standing in for the download:
  cat /fixture/install.sh | DWP_VIM_SOURCE="$HOME/src.git" \
    bash -s -- --version "$RELEASE_VERSION" --nvim "$NVIM" --skip-packages --strict
  echo "CHECK user=$(id -un) uid=$(id -u)"
  echo "CHECK tty=$( [ -t 0 ] && echo yes || echo no )"
  echo "CHECK tag=$(git -C "$HOME/.config/nvim" describe --tags --exact-match HEAD)"
  echo "CHECK nvim=$("$HOME/.local/bin/nvim" --version | head -n 1)"
  opt="$HOME/.local/share/nvim/site/pack/pckr/opt"
  echo "CHECK plugins=$(ls "$opt" | wc -l | tr -d " ")"
'
IN_CONTAINER

fails=0
want() { # want <label> <fixed string>
  if grep -qF -- "$2" "$LOG"; then echo "  ok   $1"; else echo "  FAIL $1 (missing: $2)"; fails=$((fails + 1)); fi
}
want "exit 0"                  "CHECK user=dev"
want "non-root user"           "uid=1000"
want "no terminal"             "CHECK tty=no"
want "version resolved"        "DeepWorkPlan Vim $RELEASE_REF (resolved from '${RELEASE_REF#v}' via --version)"
want "Neovim sha256-verified"  "Neovim v$NVIM installed at /home/dev/.local/bin/nvim (sha256 verified)"
want "plugins verified"        "Plugins verified"
want "on the release tag"      "CHECK tag=$RELEASE_REF"
want "nvim on the version"     "CHECK nvim=NVIM v$NVIM"
[ "$RC" -eq 0 ] || { echo "  FAIL container exit status $RC"; fails=$((fails + 1)); }
if [ "$fails" -ne 0 ]; then
  echo "---- container log ($LOG) ----"
  tail -n 60 "$LOG"
  echo "CONTAINER INSTALL: FAILED ($fails)"
  exit 1
fi
grep -E '^(==>|CHECK)' "$LOG" | sed 's/^/  /'
echo "CONTAINER INSTALL: OK ($RELEASE_REF, Neovim $NVIM, non-root, no TTY, --skip-packages --strict)"
