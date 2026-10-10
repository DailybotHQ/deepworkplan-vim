# Product spec — DeepWorkPlan Vim

## What this is

The official **terminal editor** for [Deep Work Plan](https://deepworkplan.com):
a very good editor to **navigate files**, **see which files changed**, **read
the diff** and **approve or discard changes easily** — as friendly and
lightweight as possible, **agent-first**, and wired to Deep Work Plan so the
status of the plans is always in view.

It serves two users at once: **a person** working in a terminal — most often
reviewing what a coding agent just did — and **a coding agent** living in a
terminal pane (including Herdr mesh panes on other machines). It is a
git repository that *is* the product: clone it to `~/.config/nvim`, run
`lua install.lua`, and Neovim becomes the DeepWorkPlan editor.

## Positioning

DeepWorkPlan Vim **is DeepWorkPlan's editor**. DeepWorkPlan v7 offers it as
the optional `vim` addon during onboarding, pinned by tag; the addon reads
this repository's machine-readable surface instead of guessing. Two
directions of independence hold at all times:

- **DeepWorkPlan never requires it.** The methodology works with any editor,
  or none; declining the addon leaves a repository fully conformant.
- **It never requires DeepWorkPlan.** The editor installs and runs without
  the DeepWorkPlan skill; when a repository has no `.dwp/plans/`, the
  plan surfaces show an empty state ("No plans yet") and the statusline
  segment stays hidden.

## Product focus

> A very good **terminal editor** to **navigate files**, **see which files
> have changes**, **see the diff** and **approve or discard changes easily** —
> as **friendly** and **lightweight** as possible, **agent-first**, and
> **integrated with Deep Work Plan** so the status of the plans is always in
> view.

Every decision — a plugin added or dropped, a mapping, a default — is judged
against this sentence. If a feature does not help one of the six pillars, it
needs a reason to exist.

| Pillar | You can | Done when |
|---|---|---|
| **Navigate** | open the tree, find a file by name, search text, jump to recent files and bookmarks | any file in a project is two keystrokes away, from the dashboard too |
| **See what changed** | tell at a glance which files changed (tree marks, margin signs, status, the diff panel's file list) | a changed file is never hidden from view |
| **Review the diff** | open a side-by-side diff of every change, per file | reviewing an agent's work takes one chord and no commands |
| **Approve or discard** | stage or discard a file or a hunk, then commit — with a confirmation wherever work would be lost | accepting or throwing away a change is one obvious action, never a git incantation |
| **Agent-first** | rely on pinned mappings, a self-generated command index and a headless-testable config; read an agent's changes as easily as a human's | an agent in a terminal pane has the same surface a person has |
| **Deep Work Plan in view** | see plan status in the sidebar, the reader, the statusline and the dashboard | the state of every plan is visible without leaving the editor (read-only, never required) |

Two properties cut across all six. **Friendly**: discoverable (the dashboard,
`SPC h h`), plain language, safe by default. **Lightweight**: a small, pinned
plugin set, a startup budget and no feature that costs time at the dashboard
for something the user has not asked for. Both are enforced by tests and CI,
and every change reaches `main` through a reviewed pull request.

Architecture mapping of each pillar to modules and tests:
[ARCHITECTURE.md → Capability map](ARCHITECTURE.md#capability-map).

## Who it is for

- **The person reviewing agent work** — the central user. An agent changes
  files; the person needs to see *what* changed, read the diff, and accept or
  throw away each change in a few obvious keystrokes, without leaving the
  terminal or remembering git incantations.
- **Coding agents** that need a stable, predictable editing environment:
  deterministic mappings (a documented contract, not vibes), LSP and
  formatting wired, and a config that survives agent-driven churn — and whose
  own changes are as easy to review as a human's.
- **Deep Work Plan practitioners** who want the state of their plans next to
  the code (status, progress, the current task) during the long, structured
  sessions the methodology prescribes.
- **Contributors** developing the editor itself — the Docker + Herdr
  environment in this repo exists for them.

## Key capabilities

Grouped by the pillars of the product focus. Where a pillar is only partly
delivered, the last list says so.

### Navigate
- **File tree and fuzzy finding** — `SPC n` opens the tree; `SPC f f` finds a
  file by name, `SPC f o` jumps to recent files, `SPC f w` searches text,
  `SPC b m` lists bookmarks; the dashboard offers the same shortcuts and Enter
  runs them.
- **VS Code gestures** — the familiar chords work where they cost one key:
  `<C-a>` selects all (normal mode; visual keeps the native increment), and
  `SPC y` yanks to the system clipboard in normal and visual mode.

### See what changed
- The tree marks changed files in the sign column (`M A D U R`), margin signs
  mark changed lines with hunk jumps (`]c` / `[c`), `SPC g s t` opens the git
  status, and the diff panel lists every changed file.

### Review the diff
- `SPC g d` opens a side-by-side diff of every change (themed to the active
  palette), with blame (`SPC g b l`) and the last commit (`SPC g s h`) one
  chord away.

### Approve or discard
- In the diff panel a file is staged with `-` or `s` and discarded with `d`
  or a right-click, after a "Discard / Keep" confirmation (`X` still restores
  without one — see the roadmap); `SPC g a p` stages a file hunk by hunk;
  `SPC g c` commits.

### Agent-first
- **A stable mapping contract** — the keybindings are pinned by Go contract
  tests (`tests/`), shared across the mu-vim flavor family, so muscle memory
  and agent expectations both survive updates.
- **A self-generated command index** — `SPC h h` renders every live
  mapping from `nvim_get_keymap` with human descriptions, so it can never
  drift: a mapping defined anywhere appears with zero registration.
- **Headless-testable by construction** — a hermetic smoke suite and a boot
  check run the real config without a UI; the contributor container and Herdr
  mesh (`dev.sh`) put an agent in the same editor a person uses.

### Deep Work Plan in view
- **DWP-aware navigation, in plain language** — `SPC P` opens a plans
  sidebar over every `.dwp/plans/` root (working directory and config
  directory), grouped most-attention-first (Working, Needs attention,
  Ready, Not started, Done) with progress bars; Enter on a plan opens a
  one-page reader (goal in one sentence, status, progress, the task
  checklist with the current task marked, plain-language jumps into the
  plan's own files); the statusline carries the live active plan as a
  clickable segment; the dashboard lists the top three plans and opens
  any of them in the reader. Read-only: the surfaces
  explain plans, they never write under `.dwp/` (`lua/dwp/`, smoke-covered
  in `tests/smoke/`).

### Friendly and lightweight
- **A dashboard that orients** — the shortcuts and the top plans on one
  screen; the command index is one chord away.
- **A small, pinned plugin set** — every plugin is pinned to a commit
  (`pckr/lockfile.lua`); language servers install on first start; formatting
  runs through biome, black, shfmt and stylua. There are no linters and no
  plugin that serves none of the pillars.
- **A first-class markdown viewer** — `SPC m p` previews the buffer in a
  browser, `SPC m r` renders it in place (render-markdown.nvim, loaded only
  for markdown buffers); both share the implementation behind `SPC x`.

### Foundations
- **One-command install/uninstall** across Linux (pacman/apt/dnf), macOS
  (Homebrew), and Windows (winget), with the user's previous config backed
  up, never destroyed (`install.lua` / `delete.lua`).
- **Contributor dev container** — Docker environment with Neovim pinned,
  Herdr mesh connectivity, opt-in coding CLIs, and persistence volumes for
  CLI auth (`dev.sh`, `docker/local/`).
- **Reviewed delivery** — every change reaches `main` through a pull request
  that CI validates; merging publishes a versioned GitHub Release driven by
  conventional-commit prefixes.

### Partly delivered (the roadmap, by pillar)
- **See / Review / Approve:** a one-chord "changed files" list, hunk-level
  discard with the same confirmation as the file discard, the same
  confirmation on every destructive key in the diff panel, file and branch
  history chords, and friendlier verbs for the review chords.
- **Agent-first:** a guided "review what this plan changed" jump from the plan
  reader to the diff (read-only toward `.dwp/`).
- **Lightweight:** the startup budget (byte-code cache, deferred LSP and
  completion, command-driven loading of rarely used plugins).

## Success criteria

- A fresh machine goes from `git clone` to a working editor with one command,
  on all three platform families, idempotently.
- A person can go from "the agent says it is done" to *every changed file
  seen, each diff read, each change accepted or discarded* without typing a
  git command, and nothing is discarded without a confirmation.
- The mapping contract suite stays green across flavors; keybindings never
  change silently.
- The state of every plan in a repository is visible without leaving the
  editor, and the editor never fails because there are no plans.
- Agents can sit in this editor (or a mesh pane) and edit code with the same
  LSP and formatting surface a human gets.
- The editor stays light: a pinned plugin set, a measured startup, and no
  feature that costs time at the dashboard for something not asked for.
- Every change lands through a pull request whose CI gate — hygiene, lint,
  the smoke suite, the installer harness, the mapping contracts, a container
  install and the boot check — passes.
- Nothing private ever ships: no secrets, no private hostnames, no baked SSH
  keys.

## Non-goals

- **Not a requirement of DeepWorkPlan, and not dependent on it.** The
  editor is an optional addon (see Positioning); it does not install or
  require the DeepWorkPlan skill to function as an editor, and the
  methodology never requires the editor.
- Not a framework, distro, or plugin marketplace — one curated config.
- Not an IDE: no debugger, no project scaffolding, no feature that does not
  serve the six pillars of the product focus.
- Not a wrapper around any single coding CLI: agent CLIs are opt-in build
  args, and no path requires a specific vendor (no Dailybot-only flows, no
  internal-only tooling).
- No support for Neovim < 0.12.
