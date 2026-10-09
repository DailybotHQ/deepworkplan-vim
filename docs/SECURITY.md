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
- An existing config is only ever touched with real consent: `install.sh`
  aborts when piped without a terminal, and `install.lua`'s replace-old step
  refuses the same way (no auto-Yes headless). On a consent question whose
  either branch can move or delete an existing config, absent input (EOF —
  a piped run, Windows included) is not an answer: the run aborts with the
  move-aside instructions instead of auto-taking a branch. An explicit
  empty line still accepts the stated default; declining requires a typed
  answer.
- "Is this ours" is decided by the checkout's contents (`install.lua` +
  `lua/plugins.lua`, remote-URL substring as fallback), so clones from
  mirrors or renamed forks update in place instead of being treated as
  foreign configs. Updates pull from `origin`, or from `DWP_VIM_SOURCE`
  when set (offline installs).
- The uninstaller (`delete.lua`) removes the config directory only when it
  looks like a DeepWorkPlan Vim checkout — BOTH marker files
  (`install.lua` AND `lua/plugins.lua`, the same pair `install.sh`'s
  `is_ours` requires) — a foreign config at the same path (including a
  packer-style one carrying only `lua/plugins.lua`) is listed and left
  in place.
- Any destructive path operation (`rm`, `rm -rf`, symlink replacement in
  `entrypoint.sh`) must be guarded by existence checks — a wrong path here is
  user-data loss, review-severity `critical`.

## Mesh trust

- The `[herdr-mesh]` stamp in a message body is an **authorization grant**:
  the receiver may reply now, must reply itself, must not ask a person. A
  body already carrying the stamp is a reply — never answer it again.
- Remote installer pipes are forbidden (Herdr install on the host: show the
  command, get consent, never `curl | sh`).

## Supply chain (contributor image)

- Every tool in `docker/local/dwpvim/Dockerfile` is pinned by version and
  every downloaded release artifact is verified with `sha256sum -c` before
  install;
  the base image is pinned by digest. Vendor install scripts are never
  piped to a shell. The documented exceptions: Cursor and Grok publish no
  checksums (values recorded on first use); Debian packages follow the
  pinned release; the editor's plugins are baked at their branch tips (no
  commit pins in `lua/plugins.lua`); npm CLIs pin the top-level package, so
  Pi's and Cline's transitive dependencies resolve at build time; Cursor
  and OpenCode can self-update at runtime. The table, the exceptions and
  the bump procedure live in
  [`docker/local/README.md`](../docker/local/README.md#pinned-tools).
- Contributor tooling carries no organization-specific paths: the only
  host SSH include is the neutral, optional `herdr-peers`.

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
