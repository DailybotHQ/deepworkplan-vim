# lua/ — the editor config

The Neovim configuration itself. Boot chain lives in
[init.lua](../init.lua) (settings → mapping → autocommand → plugins →
composition); concerns live in the sub-modules below. Full picture:
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).

| Module | Responsibility |
|---|---|
| `settings.lua` | `vim.opt` basics and performance flags (`lazyredraw`, no swap/backup) |
| `plugins.lua` | pckr.nvim bootstrap (checked out at its pin) + hands pckr the pinned plugin list |
| `plugin_specs.lua` | the curated plugin list — pure data |
| `plugin_lock.lua` | commit pins: reads `pckr/lockfile.lua`, applies each pin as the spec's `commit` (requires included), reports lock coverage (pure functions; `tests/smoke/plugin_lock.lua`) |
| `composition.lua` | wires every plugin's set-up (setUp, LSP, scheme) |
| `autocommand.lua` | autocommands |
| `mapping/` | **keybindings — a contract surface** (see below) |
| `dwp/` | plan browser: `.dwp/plans` discovery (`plans`), defensive state derivation — five machine states (`state.derive`) plus the rich plain-language layer (`state.derive_rich`: label, icon, progress, current task, blocked signal, friendly title) — the plans sidebar (`sidebar`, `SPC P` / `:DwpPlans`: sections, progress bars, expandable task checklists, mouse + keyboard), the plan reader (`reader`, Enter on a plan: one-page plain-language view), the clickable statusline segment (`statusline`: active plan + progress, event-fed cache, zero fs per redraw), and the dashboard overview builder (`greeter_plans`: top-3 rows for the greeter, Enter opens the reader; the dashboard builds its section on first draw, never at boot); smoke: `bash tests/smoke/run.sh` — lazy; **self-contained** (requires only `dwp.*`, enforced by `tests/smoke/dwp_self_contained.lua` — the v7.1 `deepworkplan.nvim` extraction boundary) |
| `mapping/markdown.lua` | markdown viewer: `SPC m p` browser preview, `SPC m r` in-buffer render; `SPC x` markdown branch shares it |
| `setUp/` | per-plugin set-up: greeter, finder, statusline, file manager, autosave, buffer, diff, highlight, indentation, markdown render |
| `lsp/` | lspconfig/mason servers, formatters, linters, completion, capabilities; `npm_guard` makes Mason's `npm` the real npm when a pnpm stand-in sits first on PATH |
| `scheme/` | theme apply/picker + `palettes/` (declarative color tables) |

## The mapping contract

`mapping/*.lua` is pinned by the Go contract suite in
[../tests/](../tests/README.md): the `shared` group must exist in every
mu-vim flavor, `current` is Lua-only, `vim-family` covers mini/VimScript.
**Any change here updates `tests/mappings_test.go` in the same change.**

Give every mapping a `{ desc = "…" }` option: `SPC h h`
(`mapping/glossary.lua`) builds the command index live from
`nvim_get_keymap` at open time, so the index never drifts — a mapping
defined anywhere (mapping files, a plugin, ad hoc at runtime) appears with
zero registration, and `desc` is the text it shows.

The VS Code gestures (`<C-a>` select all, `SPC y` system-clipboard yank)
and the two panels also have terminal-independent entry points —
`:DwpCommands` and `:DwpPlans` — for setups where a leader chord misfires;
both are user commands with `desc`, defined next to their mappings.

## Conventions

- New plugins: list in `plugin_specs.lua`, wire in `composition.lua` (or
  comment why they need no wiring), then pin it with
  `bash scripts/update-plugin-lock.sh` — the smoke suite fails while a
  plugin has no lock entry ([CONTRIBUTING](../CONTRIBUTING.md#plugin-lock)).
- Palettes are data, not logic.
- Validate edits: `luac5.4 -p <file>` (or the full-tree variant in
  [AGENTS.md](../AGENTS.md)).
