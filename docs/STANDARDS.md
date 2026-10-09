# Standards — deepworkplan-vim

## Language and communication

- All code, comments, and documentation in **English**.
- Commit messages: **Conventional Commits** (`feat:`, `fix:`, `perf:`, `docs:`,
  `refactor:`, `test:`, `chore:`, `ci:`). The release workflow parses the
  prefix (SemVer) — `feat:` bumps minor, `fix:`/`perf:` and everything else
  patch, a `BREAKING CHANGE` footer or `!:` major. A merge publishes a release only when `addon/surface.json` names a new version (see CONTRIBUTING.md → Releases); `[skip release]` in the body also publishes nothing.

## Formatting (`.editorconfig` is the source of truth)

- UTF-8, LF, final newline, trailing whitespace trimmed.
- Indent: 2 spaces; max line 100 — except `*.vim` (120).
- Markdown: keep sentences tight; this repo's docs are read by agents under
  token pressure.

## Lua (config tree)

- Module-per-concern under `lua/` (boot files at the root of `lua/`, concerns
  in subdirectories). `require` targets stay relative to the boot chain in
  `init.lua`.
- **Mapping changes are contract changes:** anything touching
  `lua/mapping/*.lua` must keep `tests/mappings_test.go` expectations green in
  the same change (see [TESTING_GUIDE.md](TESTING_GUIDE.md)).
- **`lua/dwp/` is self-contained** (it becomes the standalone
  `deepworkplan.nvim` plugin in v7.1): its modules require only `dwp.*`
  (Neovim's `vim.*` APIs need no require) — no dynamic `require`,
  `dofile`, `loadfile`, `luafile` or `package.loaded` reach-around — and the
  rest of the editor reaches `dwp` only lazily (inside functions or command
  strings, never a top-level `require`). Enforced by
  `tests/smoke/dwp_self_contained.lua`.
- Theme palettes in `lua/scheme/palettes/` are declarative tables — no logic.
- No plugin is added to `lua/plugins.lua` without its set-up wired in
  `lua/composition.lua` (or a comment saying why it needs none).

## Shell (`dev.sh`, `docker/`, `tests/run.sh`)

- `#!/usr/bin/env bash` + `set -euo pipefail` on every entry point.
- Quote all variable expansions in paths; guard destructive operations
  (`rm`, `rm -rf`, `mv` over existing targets) with existence/link checks —
  see the symlink surgery in `docker/local/dwpvim/entrypoint.sh` for the
  expected pattern.
- User-facing failure = `die "message"` to stderr with a non-zero exit; no
  silent partial states.
- Never pipe a remote installer into a shell; downloads are verified
  (checksum) before execution.

## Installer (`install.lua`, `utilities/installation/`)

- Idempotent: a rerun must converge, not duplicate or destroy.
- The user's previous config is moved aside to `previous-deepworkplan-vim`,
  never deleted.
- `sudo` is used only for package installation (apt/dnf/pacman), never for
  config writes.
- All three platform families (pacman/apt/dnf, Homebrew, winget) are first
  class; a change reasoning about only one family is incomplete.

## Security invariants (hard rules)

- Never commit secrets or private hostnames; `.env.example` files carry
  placeholders only.
- Never bake SSH **private** host keys into any image.
- `~/.ssh` stays mounted read-only; SSH publishes on loopback only.
- Keep `LICENSE` (GPL-3.0) and `CREDITS.md` (mu-vim lineage) intact in every
  change.
- Do not require Dailybot-only paths or internal-only tooling; do not flip coding-CLI build
  args away from default `false`.

## Docs hygiene

- Update `docs/` when a command, module, or convention changes
  ([DOCUMENTATION_GUIDE conventions per file in README.md](README.md)).
- No placeholder text ships (`[TODO]`, `<your command here>`).
- Cross-link instead of duplicating: commands live in
  [DEVELOPMENT_COMMANDS.md](DEVELOPMENT_COMMANDS.md), gates in
  [TESTING_GUIDE.md](TESTING_GUIDE.md).
