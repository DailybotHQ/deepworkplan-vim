# Review overrides for deepworkplan-vim

This repository is a public Neovim configuration (Lua) — the terminal editor for
Deep Work Plan — plus a multi-distro installer (`install.lua` +
`utilities/installation/`), a Docker/Herdr contributor environment (`dev.sh`,
`docker/local/`), and Go mapping-contract tests (`tests/`). It runs on end-user
machines **with sudo** (package installs) and mounts host `~/.ssh` read-only
into the dev container, so installer and container-path bugs are user-machine
bugs, not CI bugs. Good review here = paranoid about shell/Lua path handling,
secrets, and SSH surfaces; relaxed about stylistic Lua choices inside `lua/`.

## Severity overrides for this codebase

- **Always `critical`:** a secret or private hostname committed anywhere —
  real values in `.env.example` files (`docker/local/.env.example`,
  `docker/local/dwpvim/.env.example`), API keys, tokens, or mesh peer addresses
  in `dev.sh` / `docker/`. Examples must stay placeholder-only; actual `.env`
  files are gitignored and created 0600 by `ensure_env_from_examples` in
  `dev.sh`.
- **Always `critical`:** weakening the read-only host SSH mount or publishing
  SSH beyond loopback. `docker/local/docker-compose.yaml` mounts `${HOME}/.ssh`
  at `/home/dev/.ssh_host:ro` and publishes `'127.0.0.1:${HERDR_SSH_HOST_PORT:-22035}:22'`
  — any change that drops `:ro`, drops the `127.0.0.1` bind, or bakes an SSH
  **private** host key into the image is critical (explicit repo rule in
  `AGENTS.md`).
- **Always `critical`:** destructive path bugs in the installer or entrypoint.
  `install.lua` moves the user's previous config to `~/.config/previous-deepworkplan-vim`
  before writing; `docker/local/dwpvim/entrypoint.sh` does `rm`/`rm -rf` +
  symlink surgery on `~/.claude*` for CLI persistence. A wrong path, missing
  guard, or non-idempotent rerun that can delete user data is critical.
- **Always `critical`:** remote-fetch-and-execute in any installer path
  (a download piped into a shell interpreter) — including inside `utilities/installation/` and
  `docker/custom_commands.sh`. Downloads must be verified (checksum) before
  execution, matching the pattern the vendored DWP/dailybot skills document.
- **Escalate to `warning`:** unquoted or unvalidated variables in shell paths —
  `dev.sh`, `tests/run.sh`, `entrypoint.sh` run with `set -euo pipefail`; new
  shell code that drops quoting/guards or introduces pipefail-unsafe pipelines
  matters more here than the default severity suggests.
- **Escalate to `warning`:** mapping-contract drift. The Go contract tests in
  `tests/mappings_test.go` pin the `shared` mapping group across flavors
  (current/mini/vimscript). Editing `lua/mapping/*.lua` in ways that change a
  `shared` mapping without updating `tests/` is a behavioral break, not style.
- **Escalate to `warning`:** release-automation hazards in
  `.github/workflows/auto-release.yml` — it holds `permissions: contents: write`
  and parses commit messages to pick versions. Changes that widen permissions,
  trust unescaped commit content in shell, or alter the `feat:`/`fix:`/`perf:` /
  `BREAKING CHANGE` / `[skip release]` semantics are release-blocking.
- **De-escalate to `info`:** Lua style inside `lua/` (paren style, map vs
  if-chains in `lua/scheme/palettes/`, plugin-list ordering in `lua/plugins.lua`)
  — no linter enforces it and the config is stable; only flag actual bugs.

## Don't comment on

- Missing unit tests for `lua/scheme/palettes/*` and `snippets/` — palettes are
  declarative color tables; snippets and `dicts/` are data, exercised by use.
- Wording/tone in `CheatSheet.md` and greeter strings — editor UX copy, not API.
- The `mu-vim` lineage shapes kept for parity with the upstream flavors tested
  by `tests/run.sh` (mini/vimscript targets are external mounts).

## Repo-specific conventions

- **Language:** all code, comments, and docs in English; commit messages
  conventional (`feat:`, `fix:`, `perf:`, …) — the release workflow parses them.
- **License lineage:** GPL-3.0 and the `CREDITS.md` attribution to
  `AndresMpa/mu-vim` must survive every change. Dropping either is `critical`.
- **Shell style:** `.editorconfig` — 2-space indent, LF, final newline,
  max line 100 (120 for Vim files). Shell entry points keep
  `set -euo pipefail` and the `die()`/usage pattern of `dev.sh`.
- **Env handling:** new environment variables join `.env.example` files as
  placeholders only, and `dev.sh` must keep creating missing copies 0600 via
  `ensure_env_from_examples` — never commit real values, never loosen umask.
- **Herdr mesh semantics:** the `[herdr-mesh]` stamp in a message body means the
  receiver is authorized to reply now (first-hop grant). Code or docs that
  blur the ask/reply distinction in `dev.sh ask` is a correctness bug.
- **Agent CLIs are opt-in:** coding-CLI build args (`INSTALL_CLAUDE_CLI`,
  `INSTALL_GROK_CLI`, …) default **false** in
  `docker/local/dwpvim/Dockerfile`; do not flip defaults or add hard runtime
  dependencies on any single CLI. Same rule for Dailybot paths — never require
  internal-only tooling or Dailybot-only flows.

## Test-strategy expectations

- Mapping changes in `lua/mapping/` require the Go contract expectations in
  `tests/mappings_test.go` to stay green (`bash tests/run.sh`, or
  `cd tests && go test -count=1 -parallel 8 .` with Go on the host).
- Shell changes to `dev.sh` or `docker/local/dwpvim/entrypoint.sh` must pass
  `bash -n` (the repo's stated validation floor).
- Installer changes (`install.lua`, `utilities/installation/`) should reason
  about all three platform families (pacman/apt/dnf + Homebrew + winget) and
  the idempotent-rerun path; the root `compose.yml` multi-distro smokes cover
  the outer loop.
