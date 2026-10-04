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
| `dwp_sidebar.lua` (46) | The sidebar: opens as a `dwp-plans` buffer, sections in most-attention-first order, plan rows with bars/counts, corrupt plans listed, expand/collapse of task checklists and files, toggle keeps its roots on reopen, buffer-local keys, help overlay, `<leader>P` mapping + `:DwpPlans` command with the pinned desc. |
| `dwp_reader.lua` (34) | The reader: full render for a v6-shaped running plan (title, goal sentence, badge word, bar + counts + percent, checklist with the current task phrasing, jump lines resolving to real files, resume one-liner), blocked attention line with reason, graceful draft and corrupt renders, nomodifiable, clean close, and the sidebar Enter wiring. |
| `dwp_statusline.lua` (31) | The segment: click-expression shape, icon/title/bar/counts, active-plan choice (in-flight first), the empty case, the cache proof (repeated renders add **zero** scans, counter-asserted), event-driven refresh after fixtures change on disk, and the click handler toggling the sidebar. |
| `dwp_greeter.lua` (17) | The overview builder: header phrasing, top-3 bound, per-row icon/title/8-cell bar/counts/status word, 26-char title truncation, hint line, empty-state phrasing. No alpha session is loaded. |
| `dwp_render.lua` (72) | What the user **sees**, proven on the screen grid (`vim.fn.screenstring`), not buffer text: sidebar at 60/80/120 columns (responsive width, counts never clipped, bar block display-column aligned, CJK and unheaded titles truncate with `…`, last row lands where the row count says — no wrap/bleed), empty state at 60, 11-plan stress, reader goal and blocked prose wrapping to the real window width at 80 and 60, greeter bar-column alignment, statusline left-`<` degradation at 60/30/12/8, and resize re-fit (cap follows the window, `VimResized` wired). |
| `dwp_consistency.lua` (138) | One record, four surfaces, one vocabulary: for every fixture the sidebar row, reader header, statusline segment and greeter line agree on icon, status word, counts and percent; the spec'd divergences hold exactly (bar cells 8/10/6/8, title caps 28/60/20/26, counts absent from the sidebar row by recorded amendment, the blocked word on the statusline only when blocked); truncate caps FILL as well as respect (phantom-cell regression, D-4). |

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
