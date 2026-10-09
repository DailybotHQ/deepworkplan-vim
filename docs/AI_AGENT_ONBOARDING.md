# AI agent onboarding — first session checklist

Ten minutes from zero to productive in this repo. Read
[AGENTS.md](../AGENTS.md) first — it is the entry point and carries the rules.

## 1. Orient (read-only)

- [ ] [AGENTS.md](../AGENTS.md) — rules, Quick Commands, DWP routing
- [ ] [docs/ARCHITECTURE.md](ARCHITECTURE.md) — boot chain and module map
- [ ] [docs/TESTING_GUIDE.md](TESTING_GUIDE.md) — the gates you will be asked to run
- [ ] `git log --oneline -10` — the repo's convention in practice

## 2. Get a runnable environment

Host (lightest — enough for most tasks):

- [ ] Verify toolchain: `bash`, `lua5.4`/`luac5.4`, `git` are present (Go,
  Podman/Docker usually are not — that is expected; see the guide's fallback).

Container (for contract tests, installer smokes, mesh work):

- [ ] `cp docker/local/dwpvim/.env.example docker/local/dwpvim/.env`
- [ ] `bash dev.sh build && bash dev.sh up && bash dev.sh shell`

## 3. Verify you can validate (run the cheap gates once)

```bash
bash -n dev.sh
bash -n docker/local/dwpvim/entrypoint.sh
find lua utilities pckr -name '*.lua' -print0 | xargs -0 luac5.4 -p
```

All three must pass before you touch anything. If you have the container:
`bash tests/run.sh` (mapping contracts).

## 4. Know where things live

| Need | Where |
|---|---|
| Rules / commands | [AGENTS.md](../AGENTS.md), [DEVELOPMENT_COMMANDS.md](DEVELOPMENT_COMMANDS.md) |
| Gates | [TESTING_GUIDE.md](TESTING_GUIDE.md) |
| Security surface | [SECURITY.md](SECURITY.md) |
| Plan work | `/dwp-*` flows (`.agents/commands/`), output in `.dwp/` (gitignored) |
| Scratch (never plan output) | `tmp/` (gitignored) |
| Skills catalog | [`.agents/docs/skills_agents_catalog.md`](../.agents/docs/skills_agents_catalog.md) |

## 5. Structured work

Anything multi-step or long-horizon goes through the DWP flows:
`/dwp-create "<goal>"` → `/dwp-execute` → `/dwp-resume`; `/dwp-status` and
`/dwp-verify` are read-only. Ordinary direct edits never silently become
plans.

## 6. Report (optional, never blocking)

If Dailybot is present and authenticated, lifecycle reports fire on plan
kickoff, significant tasks, blocks, and completion (see
[AI_AGENT_COLLAB.md](AI_AGENT_COLLAB.md)). If it is absent — continue; work
never waits on reporting.
