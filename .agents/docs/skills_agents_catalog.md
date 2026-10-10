# Skills & agents catalog — deepworkplan-vim

What actually exists on disk under [`.agents/`](../README.md). No phantom
entries: if it is listed here, the file exists; if it exists, it is listed.

## Skills (`.agents/skills/`)

| Skill | Version | Source | Purpose |
|---|---|---|---|
| [`deepworkplan`](../skills/deepworkplan/SKILL.md) | 7.0.1 | `DailybotHQ/deepworkplan-skill` (vendored, tag-pinned) | The DWP engine: create/execute/refine/resume/status/verify/upgrade/onboard/author sub-skills. Standard 7.0.0 — Lite and Full plans |
| [`ai-diff-reviewer`](../skills/ai-diff-reviewer/SKILL.md) | 3.2.3 | `DailybotHQ/ai-diff-reviewer` (vendored, tag-pinned) | Local + CI diff review (six sub-skills: review, generate-extension, setup, open-pr, apply-review, address-review). Local review is the required Final Review pass; config at [`.review/extension.md`](../../.review/extension.md) |
| [`dailybot`](../skills/dailybot/SKILL.md) | 3.23.2 | `DailybotHQ/agent-skill` (vendored, tag-pinned) | 17-capability Dailybot pack; wired into DWP only for lifecycle **reporting** (never blocks). |
| [`fix-frontmatter`](../skills/fix-frontmatter/SKILL.md) | 1.0.0 | `DailybotHQ/deepworkplan-skill` (vendored utility) | Validates/fixes `SKILL.md` frontmatter against the contract |
| [`shellcheck-fix`](../skills/shellcheck-fix/SKILL.md) | 1.0.0 | `DailybotHQ/deepworkplan-skill` (vendored utility) | shellcheck over the shipped shell scripts (applies to `dev.sh`, `docker/`, `tests/run.sh`) |
| [`write-bats-test`](../skills/write-bats-test/SKILL.md) | 1.0.0 | `DailybotHQ/deepworkplan-skill` (vendored utility) | bats-core test authoring, following the upstream skill repo's `tests/` convention (this repo's own suite is Go — the skill applies if a bats layer is ever added) |

Provenance and content hashes: [`skills-lock.json`](../../skills-lock.json).
Refresh policy: `deepworkplan` is repo-adapted — upgrade only through its
`upgrade` sub-skill (check → diff → consent); the two addon skills are
tag-pinned and safe to re-pin via `npx --yes skills add <repo>@<tag> --skill <name> --force -y`.

## Agents (`.agents/agents/`)

| Agent | Role |
|---|---|
| [`reviewer`](../agents/reviewer.md) | change-set review against contracts + severities (read-only) |
| [`architect`](../agents/architect.md) | structural planning across boot chain / installer / container |
| [`executor`](../agents/executor.md) | task + plan execution with gate evidence |
| [`debugger`](../agents/debugger.md) | reproduce → isolate → fix → verify |
| [`qa`](../agents/qa.md) | gate selection, verified-vs-proposed honesty |
| [`perf-optimizer`](../agents/perf-optimizer.md) | startup budget, hot paths |
| [`security-auditor`](../agents/security-auditor.md) | security surface pass; criticals block |
| [`mapping-contract-author`](../agents/mapping-contract-author.md) | stack-specific: keybinding contract end to end |
| [`installer-maintainer`](../agents/installer-maintainer.md) | stack-specific: multi-distro installer invariants |

## Settings

[`settings.json`](../settings.json) — Dailybot deterministic hooks
(`session-start` / `activity` / `stop`): local-only, always exit 0,
respect `.dailybot/disabled`. Uninstall: remove the three `dailybot hook`
entries.

## Authoring

New entries go through `/skill-create` and `/agent-create` (thin delegators to
the deepworkplan `author` sub-skill), and this catalog is updated in the same
change. See [`.agents/README.md`](../README.md) for conventions.
