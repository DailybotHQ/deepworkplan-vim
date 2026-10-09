# Contributor container

See the root `README.md` and `AGENTS.md`.

- Image: Debian Trixie (pinned by digest), user `dev`, Neovim 0.12.5, Herdr 0.9.3 — every tool pinned and verified (see below)
- Repo mount: `/workspace` → `~/.config/nvim`
- SSH: `127.0.0.1:22035`
- Copy `dwpvim/.env.example` to `dwpvim/.env` before `bash dev.sh up`

## Pinned tools

Every tool the contributor image installs is pinned in
`dwpvim/Dockerfile` by an `ARG` version, and every downloaded release
artifact is checked with `sha256sum -c` before it is installed. **No vendor
install script is piped to a shell.**

| Tool | Pin | Source | Verification |
|---|---|---|---|
| Base image | `debian:trixie-20261005-slim@sha256:a29215…` | Docker Hub | digest |
| Debian packages (git, lua5.4, nodejs, npm, ripgrep, …) | the base image's Debian release (trixie) | apt | apt signatures; versions follow trixie's stable updates (exception: not frozen per package) |
| gh | `2.83.2` | GitHub release tarball | sha256 from `gh_<v>_checksums.txt` |
| Neovim | `0.12.5` | GitHub release tarball | sha256 = the release asset digest |
| Herdr (always) | `0.9.3` | GitHub release binary | sha256 from `herdr.dev/latest.json` |
| pnpm | `10.34.6` | npm registry | npm integrity hash |
| Biome | `2.5.15` | npm (`pnpm add -g`) | registry integrity hash |
| Claude Code (`INSTALL_CLAUDE_CLI`) | `2.1.286` | native binary, `downloads.claude.ai/claude-code-releases/<v>/` | sha256 from that version's `manifest.json`; `DISABLE_AUTOUPDATER=1` keeps it pinned |
| Cursor CLI (`INSTALL_CURSOR_CLI`) | `2026.10.01-e373342` | versioned package tarball, `downloads.cursor.com/lab/<v>/` | sha256 recorded when pinned (exception below) |
| Grok CLI (`INSTALL_GROK_CLI`) | `1.0.50` | versioned binary, `x.ai/cli/grok-<v>-linux-<arch>` | sha256 recorded when pinned (exception below) |
| Codex (`INSTALL_CODEX_CLI`) | `@openai/codex@0.162.0` | npm registry | npm integrity hash |
| OpenCode (`INSTALL_OPENCODE_CLI`) | `opencode-ai@1.18.35` | npm registry | npm integrity hash |
| Pi (`INSTALL_PI_CLI`) | `@mariozechner/pi-coding-agent@0.73.1` | npm registry | npm integrity hash |
| Cline (`INSTALL_CLINE_CLI`) | `cline@3.0.70` | npm registry | npm integrity hash |

Coding CLIs stay **opt-in** (`INSTALL_*_CLI=true`); the default build
installs none of them.

**Exceptions (documented):**

- **Cursor and Grok publish no checksums.** Their versioned artifacts are
  pinned by URL, and the sha256 values in the Dockerfile were computed from
  those exact artifacts when the pin was taken (trust on first use). A
  vendor that republishes different bytes under the same version fails the
  build — by design.
- **Debian packages** are pinned to the base image's release, not to
  per-package versions; the base image itself is pinned by digest.

**Bumping a pin:** change the version `ARG` and every sha256 `ARG` of that
tool in the same commit, taking each checksum from the vendor's published
source named above (or, for Cursor/Grok, from the downloaded artifact), and
rebuild (`bash dev.sh rebuild`).

## Peer include

The entrypoint adds one optional SSH include,
`Include ~/.ssh_host/config.d/herdr-peers`, only when the host provides
`~/.ssh/config.d/herdr-peers` (mounted read-only). `dev.sh` reads the same
neutral names (`herdr-peers`, `herdr-workspaces`). Nothing else from the
host's SSH config is included.
