# AGENTS.md — DeepWorkPlan Vim

Public Neovim configuration. Language: English. Conventional commits. GPL-3.0.

DWP standard: 6.0.0 (onboarded 2026-10-03; upgraded 2026-10-03; skill 6.0.2)

## Product

DeepWorkPlan Vim is the terminal editor for [Deep Work Plan](https://deepworkplan.com). Host install: `curl -fsSL https://deepworkplan.com/vim/install.sh | bash` (or manually: clone to `~/.config/nvim` and `lua install.lua`). This repo **is** the config; do not nest a second clone inside Docker.

Roadmap: optional DWP **v7** addon. Not v6. (That line is about the *editor* being offered as an onboard addon upstream; the harness in this repo runs skill 6.0.2 per the provenance line above.)

## Documentation index

| Guide | Purpose |
|---|---|
| [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md) | What the editor is, who it serves, non-goals |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Boot chain, module map, container, tests, release |
| [docs/STANDARDS.md](docs/STANDARDS.md) | Language, commits, Lua/shell conventions, hard rules |
| [docs/TESTING_GUIDE.md](docs/TESTING_GUIDE.md) | Gates, scoped patterns, mapping rule, fallback |
| [docs/DEVELOPMENT_COMMANDS.md](docs/DEVELOPMENT_COMMANDS.md) | Every command verbatim, with preconditions |
| [docs/SECURITY.md](docs/SECURITY.md) | Secrets, SSH surface, installer safety, mesh trust |
| [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | Startup budget, hot paths |
| [docs/AI_AGENT_ONBOARDING.md](docs/AI_AGENT_ONBOARDING.md) | First-session checklist |
| [docs/AI_AGENT_COLLAB.md](docs/AI_AGENT_COLLAB.md) | Handoffs, reporting, review, mesh etiquette |
| [lua/README.md](lua/README.md) · [utilities/](utilities/README.md) · [docker/](docker/README.md) · [tests/](tests/README.md) · [snippets/](snippets/README.md) · [dicts/](dicts/README.md) | Per-module docs |
| [.agents/docs/skills_agents_catalog.md](.agents/docs/skills_agents_catalog.md) · [COMMANDS_REFERENCE.md](.agents/docs/COMMANDS_REFERENCE.md) | Skills/agents/commands catalogs |

Repo shape (2 levels): `init.lua` + `lua/{mapping,lsp,scheme,setUp}` (editor
config) · `utilities/installation` (installer) · `install.lua`/`delete.lua` ·
`dev.sh` + `docker/local` (contributor container + Herdr) · `tests/` (Go
mapping contracts) · `snippets/` `dicts/` (data) · `.agents/` (harness) ·
`.dwp/` (plan output, gitignored) · `tmp/` (scratch, gitignored).

## Deep Work Plans — invocation

Structured work runs through the local DWP flows (`.agents/commands/dwp-*`
delegators; the flows live in `.agents/skills/deepworkplan/` — discovery is
local, no network service is consulted):

| Intent | Route |
|---|---|
| "plan this work", "create a plan" | `/dwp-create` |
| "execute / run the plan" | `/dwp-execute` |
| "continue / resume the interrupted plan" | `/dwp-resume` |
| "plan status", "what's left" | `/dwp-status` (read-only) |
| "verify the repo / the plan" | `/dwp-verify` (read-only) |
| ordinary direct edit ("fix this", "rename that") | done directly — never silently becomes a plan |

Hosts without slash commands invoke the same flows by name
(`#deepworkplan-create` or plain text). `trust`/`auto` authorizes unattended
continuation within the requested flow; it is not a flow selector, and
read-only routes stay read-only.

## Local container

| Item | Value |
|------|--------|
| User | `dev` (uid 1000) |
| Workdir | `/workspace` (this git tree, also `~/.config/nvim`) |
| Editor | Neovim 0.12.5 tarball (`EDITOR=nvim`) |
| Herdr SSH | `127.0.0.1:22035` |
| Launcher | `bash dev.sh` — `up` `down` `shell` `build` `rebuild` `agents` `ask` |

Coding CLIs (`INSTALL_CLAUDE_CLI`, …) default **false**. Herdr is always installed.

### Mesh

```bash
bash dev.sh agents
bash dev.sh ask <#> "Prompt..."
bash dev.sh ask <machine-id> <pane> "Prompt..."
```

Address is **machine id + pane id**. `#` dies with that listing. First hop includes `[herdr-mesh]` grant: the receiver is **authorized to reply now**, must send the reply itself, must not ask a person. A body that already has the stamp is a reply — do not answer it.

Peers from inside the container use `host.docker.internal` plus the published SSH port. Trust ED25519 host keys before `herdr agent list`.

Install Herdr on the host: https://herdr.dev/docs/install/ — show the command; do not pipe an installer without consent.

## Quick Commands

| Purpose | Command | Scope |
|---|---|---|
| Syntax-check launcher | `bash -n dev.sh` | full |
| Syntax-check entrypoint | `bash -n docker/local/dwpvim/entrypoint.sh` | full |
| Parse-check all Lua | `find lua utilities -name '*.lua' -print0 \| xargs -0 luac5.4 -p` | full (scoped: `luac5.4 -p <file>`) |
| dwp runtime smokes | `bash tests/smoke/run.sh` | full — host-runnable (bash + nvim); model/sidebar/reader/statusline/greeter/render/consistency over fixtures (render proves screen-grid output; consistency proves one vocabulary across surfaces) |
| Installer compat harness | `bash tests/installer/run.sh` | full — host-runnable (bash + git + coreutils + util-linux `script`); real install.sh over PATH shims: manager legs, sudo policy, consent/backup envelope, clone-vs-update incl. diverged-local die, XDG/APPNAME composition, real-Lua uninstaller guards |
| Mapping-contract tests | `bash tests/run.sh` | full — needs Podman or Docker |
| Mapping tests, Go host | `cd tests && go test -count=1 -parallel 8 .` | full — needs Go (not on this host; unverified here) |

Gates are selected from the touched surface, with the full set above as the fallback. Host toolchain here: `bash`, `lua5.4`/`luac5.4`; Podman/Docker and Go live in the container/CI.

## Installed DWP addons

- **AI Diff Reviewer (local, required baseline)** — vendored skill at
  `.agents/skills/ai-diff-reviewer/` (v3.2.3) + repo-tailored
  [`.review/extension.md`](./.review/extension.md). **Flow A (local-only)** is
  active: every plan's Final Review security pass runs the local review over
  the accumulated change set, driven by the available coding agent (in this
  environment: the `grok` CLI). The CI surface (Flow B) was declined for now —
  it can be added later via the skill's `setup` sub-skill.
- **Dailybot (optional, team reporting)** — vendored skill at
  `.agents/skills/dailybot/` (v3.23.2). Four lifecycle events fire as
  best-effort reports when a plan starts (kickoff), a significant task ships,
  a run blocks, and on completion (the only milestone): kickoff, significant
  task, blocked, completion. Reporting **never blocks work** — if Dailybot is
  absent, unauthenticated, or `.dailybot/disabled` exists, skip silently.
  Auth belongs to the Dailybot skill's own flow (`dailybot login`), never to
  an agent prompt. Reports describe outcomes for the team, never plan IDs,
  task numbers, file paths, or git stats. **Deterministic hooks are active**
  (`.agents/settings.json`: `session-start` / `activity` / `stop`; local-only,
  always exit 0) — answer a hook reminder with a report or
  `dailybot hook dismiss`, never silently, never blocking.

## Working principles

Defaults within the current request — they never override host permissions, a
narrower scope, plan gates, or this repository's rules above.

- **Own the outcome.** Carry authorized work through investigation, execution, and validation.
- **Be resourceful before asking.** Inspect the repo, docs, and vendored skills first.
- **Decide routine matters independently**; state consequential assumptions.
- **Ask when judgment or authorization is missing** — bring options and a recommendation.
- **Make approvals concrete.** Finish authorized preparation, then present a reviewable result.
- **Work through obstacles**; respect stop conditions and escalate when blocked.
- **Respect intent and scope.** An analysis request stays analysis.
- **Apply proportionate rigor** — match validation to impact.
- **Communicate directly and precisely**; distinguish facts from assumptions.
- **Verify before declaring completion.** Never claim a check that did not run.

## Do not

- Commit secrets or private hostnames
- Bake SSH host private keys into the image
- Require Dailybot-only paths or `dbdev`
- Change `LICENSE` away from GPL-3.0
- Drop [CREDITS.md](./CREDITS.md)
