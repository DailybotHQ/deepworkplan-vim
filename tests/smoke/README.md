# Smoke suite — `lua/dwp/` runtime behavior

One command, host-runnable with **bash + nvim only** (no container, no
plugin sync, no network):

```bash
bash tests/smoke/run.sh
```

Each section boots a headless Neovim over the repo's `lua/` tree with a
minimal runtime (`minimal_init.lua`: repo prepended to `runtimepath`,
swapfile off, shada none) and runs one Lua assertion script. A section
passes only if its `assertions OK` sentinel prints **and** no
`Error in command line` appears (nvim exits 0 even after a mid-script
crash — the runner rejects both failure shapes). The script exits 0 only
when every section passes.

## Sections and what each asserts

| Smoke | Asserts |
|---|---|
| `dwp_model.lua` (81) | The Task-2 model: v1 `derive()` stays byte-compatible; `derive_rich()` labels/icons/highlights/percent for all five machine states; current-task derivation (state-first, journal fallback); blocked overlay (blocker or blocked, `vim.NIL` guards); friendly-title chain; `scan()` carries rich fields; corrupt plans still list. |
| `dwp_sidebar.lua` (80) | The sidebar: opens as a `dwp-plans` buffer, sections in most-attention-first order, plan rows with bars/counts, corrupt plans listed, expand/collapse of task checklists and files, toggle keeps its roots on reopen, side and width from `vim.g.dwp_plans_side` / `_width` (left by default, right, a width ceiling that a narrow terminal still shrinks, fallbacks for bad values), a quiet window (list off even when the editor sets it, fixed width, spell/colorcolumn/foldcolumn off, edit keys silent), the `User DwpPlansOpened` event, and the visual hierarchy (header summary, section counts, segment highlights by status, dim for settled plans, two virtual rules, a long Done collapsing with the choice kept, titles growing with the window), buffer-local keys, help overlay, `<leader>P` mapping + `:DwpPlans` command with the pinned desc. |
| `dwp_reader.lua` (34) | The reader: full render for a v6-shaped running plan (title, goal sentence, badge word, bar + counts + percent, checklist with the current task phrasing, jump lines resolving to real files, resume one-liner), blocked attention line with reason, graceful draft and corrupt renders, nomodifiable, clean close, and the sidebar Enter wiring. |
| `dwp_statusline.lua` (31) | The segment: click-expression shape, icon/title/bar/counts, active-plan choice (in-flight first), the empty case, the cache proof (repeated renders add **zero** scans, counter-asserted), event-driven refresh after fixtures change on disk, and the click handler toggling the sidebar. |
| `dwp_greeter.lua` (17) | The overview builder: header phrasing, top-3 bound, per-row icon/title/8-cell bar/counts/status word, 26-char title truncation, hint line, empty-state phrasing. No alpha session is loaded. |
| `dwp_render.lua` (77) | What the user **sees**, proven on the screen grid (`vim.fn.screenstring`), not buffer text: sidebar at 60/80/120 columns (responsive width, counts never clipped, bar block display-column aligned, CJK and unheaded titles truncate with `…`, last row lands where the row count says — no wrap/bleed), empty state at 60, 11-plan stress, reader goal and blocked prose wrapping to the real window width at 80/60/44 — at 44 the goal's unspaced CJK run and long URL exercise the hard-split path: every row within the cap, no row starting mid-codepoint, byte round-trip equal, cell budget inside exact bounds (final-review finding D-6, with a red/green proof) — greeter bar-column alignment, statusline left-`<` degradation at 60/30/12/8, and resize re-fit (cap follows the window, `VimResized` wired). |
| `dwp_self_contained.lua` (80) | `lua/dwp/` stays extractable: every module requires only `dwp.*` (literal names; dynamic `require`, `dofile`, `loadfile`, `luafile`, `package.loaded/preload` are violations), every required `dwp.*` module exists, and outside `lua/dwp` the editor reaches dwp only lazily (no column-0 `require` of a dwp module in `lua/` or `init.lua`). The scanner first proves itself on synthetic violations and allowed shapes (comments and prose never match). Red-checked on the real tree: a `require("mapping.glossary")` appended to `lua/dwp/state.lua` and a top-level `require("dwp.sidebar")` in `lua/mapping/navigation.lua` each fail. |
| `addon_surface.lua` (57) | `addon/surface.json` stays true of the tree: parses, `interface` 1, `version` never older than the newest `vX.Y.Z` tag (equal at a tagged HEAD and to `CHANGELOG.md`'s newest release), installer `sha256` equals `install.sh`, the marker is the one `install.sh` writes, identity files exist, every plan-reader file is one `lua/dwp` reads and the reader declares no writes, each feature key is mapped in `lua/mapping` and each command defined in `lua/`, features are exactly F1–F5, no install step pipes a download into a shell. Mutation-checked: stale version, wrong checksum, invented key, unread file and interface 2 each fail. |
| `plugin_lock.lua` (223) | `pckr/lockfile.lua` covers `lua/plugin_specs.lua` exactly: every plugin and dependency (and pckr) has a full-commit entry, no entry names an undeclared plugin, every line is pckr's own sorted lock format, `lua/plugin_lock.lua` applies each repository's pin exactly once to the spec pckr receives (requires included, on the table spec when there is one, run/config hooks kept) and never gives a repository two non-simple specs (pckr warns on every start about that). Self-checks: an added plugin and its dependency are reported missing and get no commit, a stale entry is reported, a short sha is not a pin, a missing lockfile reads as no pins. |
| `dwp_consistency.lua` (138) | One record, four surfaces, one vocabulary: for every fixture the sidebar row, reader header, statusline segment and greeter line agree on icon, status word, counts and percent; the spec'd divergences hold exactly (bar cells 8/10/6/8, title caps 28/60/20/26, counts absent from the sidebar row by recorded amendment, the blocked word on the statusline only when blocked); truncate caps FILL as well as respect (phantom-cell regression, D-4). |
| `npm_guard.lua` (14) | `lua/lsp/npm_guard.lua` in a throwaway directory: a script that forwards to pnpm is recognised as a stand-in (a real entry point, a binary, a missing file and nil are not), the real npm that ships beside `node` is linked first on PATH and `npm` then resolves to it, a second call changes nothing, a real npm is left alone and creates no directory, and a stand-in with no real npm — or no npm at all — is reported with a reason instead of guessed. |
| `plugin_refs.lua` (11) | Static, hermetic guards over the Lua tree: every plugin module `require`d under `lua/` and `init.lua` (also as `pcall(require, "m")`) belongs to a plugin declared in `lua/plugin_specs.lua`; no retired module (`lint`) is required; `init.lua` enables `vim.loader` before its first require; and `docs/PLUGINS.md` has an entry for every plugin and every server in `lua/lsp/server.lua`. The scanner proves itself on a planted tree (red) and a clean one (green); red-checked on the real tree with a stray `pcall(require, "lint")` and with an entry removed from the doc. |
| `userconfig.lua` (33) | `lua/userconfig.lua` over temporary directories: defaults, the editor-dir file overriding them, the project file overriding that, per-key validation (bad side, too small or too large or fractional or non-numeric width, unknown section or key reported, the rest still applied), `$comment` and `_` keys ignored, malformed JSON / an array / a non-object section reported, `apply()` publishing the globals `lua/dwp` reads and defining `:DwpConfig`, `sidebars.exclusive` (default true, false honoured, non-boolean rejected), and the shipped `dwpvim.json` loading clean with the documented defaults. |

Fixtures live in `tests/fixtures/dwp_plans/` (five synthetic plans:
draft, running, done, blocked, corrupt) plus `tests/fixtures/dwp_render/`
(two hostile-content plans: a 60-cell CJK title with a long goal, and an
unheaded README exercising the humanized folder-name title). They are
harness-authored and never written by editor UI code at runtime; the
many-plans and empty-state cases synthesize temporary roots under
`vim.fn.tempname()` inside the smoke.

## What this suite does not cover (manual checks)

Honest bounds — these are recorded as manual in the plan logs, not
automated here:

- The alpha dashboard actually drawing (plugin session, real layout).
- Real mouse rendering: clicking the statusline segment under lualine,
  click/double-click in the sidebar, click on reader jump lines.
- The lualine component in a live statusline (placement, cond, theme).
- Anything outside `lua/dwp/` — LSP, completion, plugin loading stay
  uncovered; see `docs/TESTING_GUIDE.md` for the blind-spots list.

## Running one section

```bash
nvim --headless -u tests/smoke/minimal_init.lua \
  -c "luafile tests/smoke/dwp_model.lua" +qa!
```

The exit code is not trustworthy alone (see the crash note above) — read
the output for the `assertions OK` sentinel.
