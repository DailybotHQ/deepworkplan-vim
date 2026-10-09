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
bash tests/installer/container.sh   # needs Docker + network; CI runs it too
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
`chore`. The type drives the release bump (SemVer): `feat` → minor,
`fix`/`perf` and every other type → patch,
a `BREAKING CHANGE` footer or `type!:` → major.

A DCO sign-off is **not** required.

## Pull requests

1. Branch from `main` (`feat/…`, `fix/…`, `docs/…`).
2. Keep one concern per PR; run the gate; fill in the PR template
   (summary, linked issue, test evidence, the no-secrets checklist).
3. CI must be green and one maintainer review is required; head branches
   are deleted on merge.
4. Never rewrite published history (`main`, tags).

## Plugin lock

Every plugin in `lua/plugin_specs.lua` (dependencies included) and pckr
itself is pinned to a commit in `pckr/lockfile.lua`; installs and updates
check those commits out, and `install.sh --strict` refuses any other.
Plugins move only through the refresh script:

```bash
bash scripts/update-plugin-lock.sh            # update + test; review the lock diff
bash scripts/update-plugin-lock.sh --commit   # same, then commit the lock alone
```

It syncs every plugin to its branch tip in a throwaway `HOME` (your
`~/.config/nvim` and `~/.local/share/nvim` are never touched), writes the
lock, reinstalls from it and requires every commit to match, then runs the
smoke suite and the installer harness. It needs `nvim`, `git`, `lua5.4` and
network. Read the moved plugins' upstream changes before you open the PR:
the lock is the line between upstream and every install.

Adding or removing a plugin: edit `lua/plugin_specs.lua`, then run the
script — `tests/smoke/plugin_lock.lua` fails while a plugin has no lock
entry or the lock names one that is gone. A lock change reaches users in
the next release (below).

## Releases

A merge to `main` publishes a release only when the tree describes a new
one: while `addon/surface.json` names an already-released version (docs, CI,
dependency merges), the release run ends with a notice and publishes
nothing. `[skip release]` in the merge commit body also skips it. A release PR:

1. Renames `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) to
   `## [vX.Y.Z] - YYYY-MM-DD` (the version the commit types compute) and
   adds a fresh `## [Unreleased]`.
2. Sets `version` and every tag in `install` of `addon/surface.json` to
   `vX.Y.Z`; sets `RELEASE_REF` and the release named in the header of
   `install.sh` to `vX.Y.Z` (then `install.script.sha256` to the new
   `sha256(install.sh)`); and moves the README's and AGENTS' tag pins. The
   smoke suite fails until all of them agree.
3. Merges without `[skip release]`.

The workflow refuses a release whose surface version differs from the one
the commit types compute, or whose CHANGELOG section is missing; it creates
an annotated tag, publishes the CHANGELOG section as
the notes and attaches the source archive, `install.sh`, `surface.json` and
`SHA256SUMS`. Only `main` publishes; re-running a run whose publish step
failed finishes the same release. Dry-run it first from the Actions tab (`Auto release` →
Run workflow, `dry_run` on).

## License

By contributing you agree that your contributions are licensed under
[GPL-3.0](LICENSE), the license of this project.
