# Security — deepworkplan-vim

This repository ships code that runs on end-user machines **with sudo** (the
installer) and builds containers that touch the developer's SSH setup. Every
change is reviewed against the surfaces below; the AI Diff Reviewer extension
at [`.review/extension.md`](../.review/extension.md) encodes the same rules as
review severities.

## Secrets

- **Committed `.env.example` files carry placeholders only**
  (`docker/local/.env.example`, `docker/local/dwpvim/.env.example`). Real
  `.env` files are gitignored and created **0600** from the examples by
  `ensure_env_from_examples` in `dev.sh` — never loosen that umask.
- No API keys, tokens, or private hostnames in any tracked file, ever
  (explicit `AGENTS.md` rule).
- Coding-CLI auth inside the container lives on persistence volumes
  (`~/.claude_data` etc.) managed by `entrypoint.sh`; it never enters the
  image or the repo.

## SSH surface

- Host `~/.ssh` is mounted into the dev container **read-only** at
  `/home/dev/.ssh_host` (`docker/local/docker-compose.yaml`).
- Herdr SSH publishes on **loopback only**: `127.0.0.1:${HERDR_SSH_HOST_PORT:-22035}:22`.
- **Never** bake SSH host **private** keys into the image (hard rule).
- Trust host keys (ED25519) before `herdr agent list`; peers are read from
  the user's own `config.d` files by `dev.sh`.

## Installer safety

- `install.lua` runs with sudo **only** for package installation
  (apt/dnf/pacman); config writes happen as the user.
- The user's previous config is moved to `~/.config/previous-deepworkplan-vim`,
  never deleted; reruns are idempotent.
- Any destructive path operation (`rm`, `rm -rf`, symlink replacement in
  `entrypoint.sh`) must be guarded by existence checks — a wrong path here is
  user-data loss, review-severity `critical`.

## Mesh trust

- The `[herdr-mesh]` stamp in a message body is an **authorization grant**:
  the receiver may reply now, must reply itself, must not ask a person. A
  body already carrying the stamp is a reply — never answer it again.
- Remote installer pipes are forbidden (Herdr install on the host: show the
  command, get consent, never `curl | sh`).

## CI / release

- `.github/workflows/auto-release.yml` holds `permissions: contents: write`
  and interpolates commit messages into shell — treat changes there as
  release-blocking and keep inputs escaped.
- No review workflow is installed for now; if the AI Diff Reviewer's CI
  surface is added later, its provider secret lives in GitHub Actions
  secrets, never in the repo tree.

## What agents MUST NOT write into docs or code

Real credential values, real hostnames or mesh peer addresses, SSH key
material (public or private), and any `.env` content beyond placeholders.
