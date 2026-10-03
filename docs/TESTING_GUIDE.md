# Testing guide — deepworkplan-vim

## Posture

This repo's automated layer is **contract-first, parse-only**: the Go suite in
`tests/` parses mapping files and asserts keybinding contracts across flavors
without ever starting Neovim. Runtime behavior (LSP sessions, plugin loading,
UI) has no automated layer today — that is a known, accepted gap, covered
manually and by the installer smokes. The unit-first behavioral base here is
the contract suite; the real seams it guards are the mapping files and the
installer contract across distros.

## Commands (current, verified)

Full suite and lint/type-check commands, with the working directory and status:

| Command | Runs from | Scope | Status |
|---|---|---|---|
| `bash -n dev.sh` | repo root | full — launcher syntax | **verified on host** |
| `bash -n docker/local/dwpvim/entrypoint.sh` | repo root | full — entrypoint syntax | **verified on host** |
| `find lua utilities -name '*.lua' -print0 \| xargs -0 luac5.4 -p` | repo root | full — every Lua file parses | **verified on host** |
| `luac5.4 -p lua/mapping/git.lua` | repo root | scoped — one file | **verified on host** (non-empty: parses that file; the full-run variant above is the cheap default) |
| `bash tests/run.sh` | repo root | full — mapping contracts via Podman/Docker | **container-required** — no Podman/Docker on the dev host; verified shape, not run here |
| `cd tests && go test -count=1 -parallel 8 .` | `tests/` | full — mapping contracts on a Go host | **unverified on this host** (no Go installed); same suite `tests/run.sh` runs in compose |

Tool versions where behavior depends on them: `luac5.4` (Lua 5.4 parse-only
mode); Neovim itself is **not** needed by any automated gate.

Expected evidence of a correct contract run: Go reports
`TestMappingContract/current`, `/mini`, `/vimscript` subtests (flavors whose
config is not mounted are skipped, not failed) with `ok` per package.

## Scoped invocation patterns

- **Lua parse (verified):** `luac5.4 -p <file>` — parse-check exactly the file
  you touched. Example: `luac5.4 -p lua/composition.lua`. When the full tree
  check costs the same (it does — one `find | xargs`), prefer the full run.
- **Go contract, one flavor (proposed/unverified):**
  `cd tests && go test -run 'TestMappingContract/current' -count=1 .` — runs
  only the current-flavor subtests. Not verifiable on this host (no Go);
  fallback: `bash tests/run.sh` in the container.
- Shell syntax checks are inherently per-file (`bash -n <file>`); there is no
  cheaper project-wide option, and that is fine — run it per touched script.

## Source-to-test mapping

`lua/mapping/*.lua` ⇄ `tests/mappings_test.go` (via `tests/contract.go` /
`tests/extract.go`): the `shared` group must hold in **every** flavor,
`currentOnly` in the Lua flavor, `vimFamily` in mini/VimScript. A change to
any mapping file requires updating the contract expectations in the same
change.

## Consumer policy

There is no affected-tests tooling. The consumers of this repo's behavior are:
(1) the other mu-vim flavors tested by the same suite, (2) end users'
muscle memory, (3) agents relying on the mapping contract. When in doubt, run
the whole contract suite — it is the full-fallback anyway.

## Blind spots

- Runtime Neovim behavior (LSP, completion, plugins, UI) — no automated layer.
- The installer's platform branches are exercised only by the multi-distro
  smokes (root `compose.yml`), not unit-tested.
- Palettes, snippets, and dicts are data exercised by use, not by tests.

## Escalation paths (always-full triggers)

- Any change under `lua/mapping/` or `tests/` → the contract suite (full).
- Any change to `install.lua` or `utilities/installation/` → installer smokes
  plus a manual rerun reasoning for all three platform families.
- Any change to `dev.sh`, `docker/`, or compose files → the full `bash -n`
  set plus a container round-trip when available.

## Fallback statement

When scoping is uncertain or a gate's precondition is missing (no Podman,
no Go), run the **full Quick Commands set** from
[AGENTS.md](../AGENTS.md) and record what could not run.

## Proposed (target, not installed)

- Adopt `stylua` for Lua formatting checks (config: 2-space, 100 cols) —
  proposed, not verified here; install is a maintainer decision.
- A startup smoke (`nvim --headless "+LazyHealth" +qa` style) inside the dev
  container would close the biggest runtime blind spot — proposed only.
