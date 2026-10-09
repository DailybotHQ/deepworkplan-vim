# Testing guide — deepworkplan-vim

## Posture

This repo's automated layer has two legs. The **contract suite** (Go, in
`tests/`) parses mapping files and asserts keybinding contracts across flavors
without ever starting Neovim. The **smoke suite** (`bash tests/smoke/run.sh`)
boots headless Neovim and exercises the `lua/dwp/` plan surfaces for real —
model, sidebar, reader, statusline segment, greeter builder — against
committed fixtures. Runtime behavior beyond `lua/dwp/` (LSP sessions, plugin
loading, the alpha draw) has no automated layer today — that is a known,
accepted gap, covered manually and by the installer smokes. The contract
suite guards the mapping files and the installer contract across distros;
the smoke suite guards the dwp UI's behavior contracts.

## Commands (current, verified)

Full suite and lint/type-check commands, with the working directory and status:

| Command | Runs from | Scope | Status |
|---|---|---|---|
| `bash -n dev.sh` | repo root | full — launcher syntax | **verified on host** |
| `bash -n docker/local/dwpvim/entrypoint.sh` | repo root | full — entrypoint syntax | **verified on host** |
| `find lua utilities -name '*.lua' -print0 \| xargs -0 luac5.4 -p` | repo root | full — every Lua file parses | **verified on host** |
| `luac5.4 -p lua/mapping/git.lua` | repo root | scoped — one file | **verified on host** (non-empty: parses that file; the full-run variant above is the cheap default) |
| `bash tests/smoke/run.sh` | repo root | full — dwp runtime smokes (model, sidebar, reader, statusline, greeter, render, consistency, self-contained, addon surface) over committed fixtures, the `lua/dwp` sources and `addon/surface.json` (and the README and install.sh release pins); 564 assertions | **verified on host** |
| `bash tests/installer/run.sh` | repo root | full — installer compatibility harness: 31 scenarios over the real `install.sh` (release-tag default and tag updates, `DWP_VIM_SKIP_PACKAGES`, the script read through a pipe, the pnpm fallback under real Lua, OS gate, per-manager sudo policy, consent/backup envelope, clone-vs-update incl. the diverged-local die, XDG/APPNAME bootstrap composition, real-Lua uninstaller guards); bounds in `tests/installer/README.md` | **verified on host** |
| `bash scripts/check-public-hygiene.sh` | repo root | full — public-hygiene rules over every tracked file except vendored `.agents/skills/` (personal paths, private org/repo/tool names, non-public `@dailybot.com` emails, secret shapes; secret hits redacted); exceptions in `.public-hygiene-allow`, each with a reason, stale entries fail | **verified on host** |
| `bash tests/hygiene/run.sh` | repo root | full — self-test of the hygiene check: planted fakes in throwaway git repos prove each rule fires, lookalikes pass, allow entries are path-scoped, stale/reasonless entries fail, secret allows need a fake marker, values never print, the allowlist itself is vetted, grep failures fail closed, new token formats (xAI, npm, GitLab, Stripe, Hugging Face, JWT, Bearer, PGP, unquoted assignments) fire, downloads run by a shell are caught in code and prose (pipes, path-qualified shells, sudo/env, intermediate pipes, process/command substitution, iex); 52 assertions | **verified on host** |
| `bash tests/run.sh` | repo root | full — mapping contracts via Podman/Docker | **container-required** — no Podman/Docker on the dev host; verified shape, not run here |
| `cd tests && go test -count=1 -parallel 8 .` | `tests/` | full — mapping contracts on a Go host | **runs in CI** (`ci.yml` → Mapping contracts, Go 1.23 on ubuntu-24.04); not on this host (no Go); same suite `tests/run.sh` runs in compose |

Tool versions where behavior depends on them: `luac5.4` (Lua 5.4 parse-only
mode); Neovim 0.12+ on PATH is needed by the smoke suite (and by nothing
else among the automated gates); the installer harness needs a real
`lua5.4` interpreter on PATH and a `script` (util-linux or BSD/macOS —
both supported) and runs from any branch. A host whose package manager
moved to Lua 5.5 (Homebrew) has no `luac5.4`/`lua5.4`: build Lua 5.4 from
the lua.org tarball (verify its published sha256) and put it on PATH for
the gates — `luac5.5` is not a substitute for the documented gate.

Expected evidence of a correct contract run: Go reports
`TestMappingContract/current`, `/mini`, `/vimscript` subtests (flavors whose
config is not mounted are skipped, not failed) with `ok` per package.

CI (`.github/workflows/ci.yml`) runs the hygiene check and its self-test,
the Lua parse and shell syntax, the smoke suite, the installer harness and
the Go mapping contracts on every pull request and push to `main`; branch
protection requires them. A red CI job is a failed gate, never a flake to
re-run blindly.

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
- **dwp smoke, one section (verified):** the suite runs every section by
  design; to iterate on one, run it directly —
  `nvim --headless -u tests/smoke/minimal_init.lua -c "luafile tests/smoke/dwp_model.lua" +qa!`
  — and read the output for the `assertions OK` sentinel (nvim exits 0 even
  after a mid-script crash, so the exit code alone is not a pass).

## Source-to-test mapping

`lua/mapping/*.lua` ⇄ `tests/mappings_test.go` (via `tests/contract.go` /
`tests/extract.go`): the `shared` group must hold in **every** flavor,
`currentOnly` in the Lua flavor, `vimFamily` in mini/VimScript. A change to
any mapping file requires updating the contract expectations in the same
change.

`lua/dwp/*.lua` (its requires) and every `lua/**/*.lua` / `init.lua` that
references dwp ⇄ `tests/smoke/dwp_self_contained.lua`: a new `require` in
`lua/dwp/` must name a `dwp.*` module, and the editor reaches dwp lazily.

`addon/surface.json`, `install.sh`, `lua/mapping/*.lua`, `lua/dwp/*.lua` ⇄
`tests/smoke/addon_surface.lua`: the surface's claims are checked against
those files, so a change to any of them (an installer edit changes its
sha256; a removed key or command breaks a feature claim) requires the
surface smoke to stay green in the same change — update `surface.json`
alongside.

`lua/dwp/*.lua` ⇄ `tests/smoke/dwp_*.lua` (fixtures in
`tests/fixtures/dwp_plans/`, runner `tests/smoke/run.sh`, per-smoke docs in
`tests/smoke/README.md`): a change to any dwp module requires its smoke to
stay green in the same change; new behavior ships with assertions in the
same change.

`scripts/check-public-hygiene.sh` ⇄ `tests/hygiene/run.sh`: a rule change
ships with a planted case in the self-test in the same change. Every tracked
file ⇄ `scripts/check-public-hygiene.sh`: run it after adding or renaming
files, not only after editing them.

## Consumer policy

There is no affected-tests tooling. The consumers of this repo's behavior are:
(1) the other mu-vim flavors tested by the same suite, (2) end users'
muscle memory, (3) agents relying on the mapping contract. When in doubt, run
the whole contract suite — it is the full-fallback anyway.

## Blind spots

- Runtime Neovim behavior outside `lua/dwp/` (LSP, completion, plugin
  loading, the alpha draw) — no automated layer. The dwp surfaces are
  smoke-covered headlessly; what the smokes still leave manual there: real
  mouse rendering (statusline click under lualine, sidebar clicks), the
  alpha dashboard actually drawing, and the lualine component in a live
  statusline. Those are recorded as manual checks in the plan logs.
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
  container would close the plugin-loading blind spot — proposed only (the
  dwp surfaces already have runtime coverage via `tests/smoke/`).
