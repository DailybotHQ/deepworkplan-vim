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

## Keys

| Key | Does |
|---|---|
| `Enter` | open the plan in the reader; on a section name, show or hide the group |
| `Tab` | show or hide a plan's tasks and files |
| `r` | refresh |
| `?` | help |
| `q` / `Esc` | close |
| click / double-click | expand / open |

## Guarded by

`tests/smoke/dwp_sidebar.lua` (the window, the keys, the event, the hierarchy,
the collapse, the title width), `tests/smoke/dwp_render.lua` (no row wraps at any
width), `tests/smoke/dwp_consistency.lua` (one vocabulary across surfaces) and
`scripts/boot-check.sh` (the toggle with the real plugins).
