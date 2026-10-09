# Contributing to DeepWorkPlan Vim

Thanks for helping. This is one curated Neovim configuration (GPL-3.0,
derived from mu-vim — see [CREDITS.md](CREDITS.md)); changes are welcome
when they keep it fast, consent-first and usable by both people and coding
agents. AI agents start at [AGENTS.md](AGENTS.md), which links every guide.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
Security problems go through [SECURITY.md](SECURITY.md), never a public issue.

## Development setup

Host tools for the gates (no container needed):

| Tool | Used by |
|---|---|
| `bash`, `git`, `grep`, coreutils | everything |
| Neovim 0.12+ (`nvim` on PATH) | smoke suite |
| Lua 5.4 (`lua5.4`, `luac5.4` on PATH) | Lua parse, installer harness |
| `script` (util-linux or BSD/macOS) | installer harness |
| Go 1.23 (optional) | mapping contracts — CI runs them for every PR |

Homebrew now ships Lua 5.5 only; build Lua 5.4 from the lua.org tarball
(verify its published sha256) and put it on PATH —
[docs/TESTING_GUIDE.md](docs/TESTING_GUIDE.md) explains why `luac5.5` is
not a substitute. Optional: the contributor container
(`bash dev.sh build && bash dev.sh up`, see
[docs/DEVELOPMENT_COMMANDS.md](docs/DEVELOPMENT_COMMANDS.md)).

To try your branch as your editor, clone it to `~/.config/nvim` (back up
your own config first) or use `NVIM_APPNAME`:

```bash
git clone <your-fork> ~/.config/dwpvim-dev && NVIM_APPNAME=dwpvim-dev nvim
```

## The gate

Run the full host gate before opening a pull request — CI runs the same
commands (plus the Go mapping contracts) and branch protection requires them:

```bash
bash scripts/check-public-hygiene.sh && bash tests/hygiene/run.sh
find lua utilities -name '*.lua' -print0 | xargs -0 luac5.4 -p
for f in dev.sh install.sh docker/local/dwpvim/entrypoint.sh scripts/*.sh; do bash -n "$f"; done
bash tests/smoke/run.sh
bash tests/installer/run.sh
(cd tests && go test -count=1 -parallel 8 .)   # if you have Go; otherwise CI runs it
```

Scoped variants and the source-to-test mapping (which change needs which
test in the same commit) are in [docs/TESTING_GUIDE.md](docs/TESTING_GUIDE.md).
A keymap change updates `tests/contract.go`; a `lua/dwp` change keeps its
smoke green; an `install.sh` change updates `install.script.sha256` in
`addon/surface.json`.

## Public hygiene

This repository is public. Never commit secrets, personal absolute paths,
private repository or internal tool names, non-public email addresses,
customer data or internal hostnames. `scripts/check-public-hygiene.sh`
enforces the rules; a deliberate exception goes in `.public-hygiene-allow`
with a reason (secret-shaped test fixtures must be obviously fake).

## Commits

[Conventional Commits](https://www.conventionalcommits.org/):
`<type>(<optional scope>): <description>`, in English, imperative mood.
Types: `feat`, `fix`, `perf`, `docs`, `style`, `refactor`, `test`, `ci`,
`chore`. The type drives the release bump: `feat`/`fix`/`perf` → minor,
a `BREAKING CHANGE` footer or `type!:` → major, anything else → patch.

A DCO sign-off is **not** required.

## Pull requests

1. Branch from `main` (`feat/…`, `fix/…`, `docs/…`).
2. Keep one concern per PR; run the gate; fill in the PR template
   (summary, linked issue, test evidence, the no-secrets checklist).
3. CI must be green and one maintainer review is required; head branches
   are deleted on merge.
4. Never rewrite published history (`main`, tags).

## Releases

Merging to `main` cuts a release unless the merge commit body contains
`[skip release]`. **Every merge that does not ship a release carries
`[skip release]`.** A release PR:

1. Renames `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) to
   `## [vX.Y.Z] - YYYY-MM-DD` (the version the commit types compute) and
   adds a fresh `## [Unreleased]`.
2. Sets `version` and every tag in `install` of `addon/surface.json` to
   `vX.Y.Z` (and the README's pinned tag).
3. Merges without `[skip release]`.

The workflow refuses a release whose CHANGELOG section or surface version
does not match, creates an annotated tag, publishes the CHANGELOG section as
the notes and attaches the source archive, `install.sh`, `surface.json` and
`SHA256SUMS`. Dry-run it first from the Actions tab (`Auto release` →
Run workflow, `dry_run` on).

## License

By contributing you agree that your contributions are licensed under
[GPL-3.0](LICENSE), the license of this project.
