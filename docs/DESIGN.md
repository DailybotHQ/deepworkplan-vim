# DeepWorkPlan Vim design system

## Overview

Profile: **cli-output**, including the editor's terminal UI. Neovim's native
buffer/window rendering, `lua/scheme/`, `lua/dwp/` and the command glossary are
the design sources. No web visual UI or product messaging profile is present.
The editor presents files, diffs and plan progress with quiet windows, readable
text and keyboard/mouse actions. This guide documents the existing system;
it adds no rendering dependency or palette.

## Output voice and intent

Use concise English labels and literal actions. Plan states are `Working`,
`Needs attention`, `Ready`, `Not started`, `Done` and `Unknown`; derive them from
`dwp.state` rather than inventing a competing vocabulary. A status carries its
label, symbol and progress together. Show unavailable live state explicitly;
never infer idle or success from a failed command.

## Semantic colors and styles

The theme lives in `lua/scheme/palettes/` and is applied by `scheme.apply`.
The default is `deep-ocean`, set by `scheme.theme`; users can choose another
palette. The default tokens below are descriptive, not hardcoded UI colors:

| Palette token | Default value | Role |
| --- | --- | --- |
| `bg` / `bg_alt` | `#0F111A` / `#181A1F` | Main and alternate surfaces |
| `fg` | `#C5C8D4` | Body text |
| `dim` | `#6B7089` | Secondary decoration |
| `red` / `yellow` | `#F07178` / `#FFCB6B` | Error and warning palette inputs |
| `green` / `blue` | `#C3E88D` / `#82AAFF` | Success and informational palette inputs |
| `accent` | `#84FFFF` | Palette emphasis |

DWP surfaces derive highlight groups from the active theme. Sidebar groups:
`DwpPlansHeader` from `Title` (bold), `DwpPlansSummary`, `DwpPlansRule` and
`DwpPlansDim` from `Comment`, `DwpPlansTitle` from `Normal` (bold), and
`DwpPlansPlain` from `Normal`. Plan status highlights come from `dwp.state`:
`MoreMsg` for Working, `WarningMsg` for Needs attention, `Directory` for Ready,
`Special` for Done and `Comment` for Not started/Unknown. Retain these semantic
relationships on theme changes; never copy a palette hex into a DWP component.

## Output components

- **Plans sidebar (`dwp.sidebar`):** a persistent split with status sections,
  progress bars and expandable tasks/files. Keyboard navigation skips decoration;
  mouse routing follows the window under the pointer. `?` explains the actions.
- **Plan reader (`dwp.reader`):** a plain-language goal, task checklist and file
  jump list. Wrap prose to the available width; preserve full blocker reasons.
- **Lanes (`dwp.lanes`):** a separate read-only split containing recorded fields
  and optional live snapshots. Display the timestamp and refresh action; do not
  label it continuous monitoring. Failed lookups retain recorded membership.
- **Command index (`mapping.glossary`):** derive rows from live keymaps and their
  `desc`, with search and grouped presentation; do not maintain a duplicate list.
- **Statusline/dashboard (`dwp.statusline`, `dwp.greeter_plans`):** compact plan
  summaries consistent with the richer sidebar and reader.

## Layout conventions

`dwp.sidebar` has a 48-column default ceiling and 34-column readable floor,
with a responsive share on narrow terminals and user width overrides.
The title cap follows window width; the progress bar is eight cells. Count
terminal display cells, including CJK width, rather than bytes or characters.
Use existing theme-derived rules and blank lines to separate sections.
Read-only windows disable `list` so global whitespace markers do not obscure
prose. Keep editing guards and explanatory refresh/close hints.

## Degradation and environment

These are Neovim terminal buffers, not a stdout CLI with a `--json` or `NO_COLOR`
mode. Do not claim those options. Labels and symbols carry meaning without
highlight color; retain that information in headless buffer text. Narrow-window
handling must preserve progress and actionable text. Live lookup is optional,
fixed-argv and bounded by a three-second timeout; its stderr is not rendered.
For scripts, preserve their existing stderr/exit behavior and release checksums.

## Do's and don'ts

- Use existing highlight roles and shared state labels; never convey state by
  color alone or silently replace unavailable with idle.
- Preserve read-only scratch buffers and the no-plan-write boundary.
- Preserve keyboard operation and pointer-based mouse routing together.
- Verify narrow/CJK rendering with the existing render and consistency smokes.
- Assess actual palette pairings when changing themes; this document does not
  claim every theme or decorative pairing meets a fixed contrast ratio.
- Keep `lua/dwp/` self-contained and lazy; add no external theme/plugin require.

## Agent prompt guide

Before changing terminal UI, read this guide and the relevant rendering source.
Reuse named highlight groups, state derivation and live mapping discovery.
Run the corresponding smoke through `bash tests/smoke/run.sh`; include render
and consistency checks for layout changes. Changes to palettes use the real
`lua/scheme/palettes/` tokens and must preserve readable text and color-independent
status. Record any uncovered design behavior before introducing another pattern.
