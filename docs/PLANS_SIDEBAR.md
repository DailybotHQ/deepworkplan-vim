# The plans sidebar — design

`SPC P` (or `:DwpPlans`, the dashboard shortcut, the statusline segment) opens
the plans sidebar. It is the editor's one view of every Deep Work Plan in the
repository; read-only, never written to `.dwp/`. This page records why it looks
the way it does, from a UX review of the live window.

## What you see

```
Plans  2 working · 1 need attention
──────────────────────────────────────
Working · 2
◉ website pilot — the dwpwebs…   ▸▰▰▰▰▰▰▰▰ 100%
◉ DeepWorkPlan v7 ecosystem —…   ▸▰▰▰▰▰▰▰▱ 89%

Needs attention · 1
⚠ …

Done ▸ 39 hidden
──────────────────────────────────────
? help · r refresh · Enter open · Tab expand
click a plan to open it · the arrow shows tasks
```

- **Header:** the title in an accent and a quiet summary of what is live.
- **Sections** in most-attention-first order (Working, Needs attention, Ready,
  Not started, Done), each with its count; a blank row separates them.
- **Rows:** a status icon, the title, an 8-cell bar and a percent. The icon and the
  bar's fill take the status colour; the title is strong while the plan is live
  and recedes when it is settled; the percent and empty bar cells are dim.
- **Done** opens collapsed when it holds more than six plans (`Done ▸ 39 hidden`);
  Enter on the header shows it, and your choice sticks.
- **Titles** use the room the window has: 28 characters at the default 48
  columns, up to 44 in a wider sidebar (`plans.width` in `dwpvim.json`).

Colours are derived from the active theme (`DwpPlansHeader`, `DwpPlansSection`,
`DwpPlansTitle`, `DwpPlansDim`, …) and follow `:colorscheme`; none is a fixed hex.

## One sidebar at a time

Opening the plans closes the file tree and opening the tree closes the plans, so
you look at one thing at a time. Turn it off with `sidebars.exclusive: false`
([CONFIGURATION.md](CONFIGURATION.md)). The two sides talk through events
(`User DwpPlansOpened` from the sidebar, nvim-tree's `TreeOpen`), so `lua/dwp`
stays free of any plugin: `lua/setUp/sidebars.lua` is the only place that knows
both.

## A quiet window

The window turns the editor's global `list` off (no dots for spaces, no arrows at
line ends), keeps a fixed width so a neighbour cannot stretch it, and ignores
editing keys silently — it is read-only, so `i`, `a`, `x` and friends do nothing
instead of printing `E21`.

## Mouse and keyboard

| Action | Does |
|---|---|
| **click a plan** | open it in the reader (the click acts on the row under the pointer) |
| click the small `▸` / `▾` arrow | show or hide that plan's tasks and files |
| click a section name | show or hide the group |
| click a task or file | open it |
| `j` `k` / `↓` `↑` / `Ctrl-n` `Ctrl-p` | jump to the next / previous plan (and to section names, tasks and files); blanks, rules and the footer are skipped; `3j` repeats |
| `gg` / `G` | first / last row you can act on |
| `Enter` | open the plan; on a section name, show or hide the group |
| `Tab` | show or hide a plan's tasks and files |
| `r` · `?` · `q` / `Esc` | refresh · help · close |

The cursor lands on the first plan when the sidebar opens. The reader window on
the right is as quiet as the sidebar (no dots or arrows) and a click on one of its
file lines opens that file.

## Guarded by

`tests/smoke/dwp_sidebar.lua` (the window, the keys, the event, the hierarchy,
the collapse, the title width), `tests/smoke/dwp_render.lua` (no row wraps at any
width), `tests/smoke/dwp_consistency.lua` (one vocabulary across surfaces) and
`scripts/boot-check.sh` (the toggle with the real plugins).

## Orchestra lanes

Press `L` on a plan or one of its tasks to open a separate read-only lanes split.
`SPC O` / `:DwpLanes` selects an orchestrator plan; `SPC hh` lists the mapping
under Deep Work Plans. These entry points load `dwp.lanes` only when invoked.

The view reads Markdown tables with a `Lane` or `Child Plan` / `Child DWP`
column from `ORCHESTRATOR_MANIFEST.md` and `README.md`. Manifest fields take
precedence; matching lane, repository or child-plan identifiers merge the README
fields. Columns include repository, pane/peer, account/profile, branch, status,
child plan and dependencies. Ordinary documentation tables are ignored. This
view never follows child paths, writes plans, sends messages or controls agents.

When `herdr-peers` is on PATH, the view asynchronously runs the fixed read-only
command `herdr-peers lanes --json` with a three-second timeout. It accepts the
`herdr-peers/lanes-v1`, protocol 1 envelope and joins runtime entries by exact
`peer` address. It shows live state (`working`, `idle`, `blocked`, `done`,
`unknown`, `no_agent`, `unreachable`), agent/profile, attention screen and open
ask count. Unknown JSON fields are ignored. Peers outside the plan are omitted;
recorded status is shown separately from live status.

`r` reloads disk and live data; `q` / `Esc` closes the split. The timestamp marks
a snapshot, not continuous monitoring. Missing helpers (including older helpers
without `lanes`), failures, timeouts or unsupported JSON display an explicit
unavailable message while retaining recorded lanes. Unmatched peers show
`unavailable`; zero live peers is a valid snapshot. Command stderr is never
rendered. Late callbacks cannot overwrite a newer refresh or a closed buffer.

Guard: `tests/smoke/dwp_lanes.lua`, included in `bash tests/smoke/run.sh`.
