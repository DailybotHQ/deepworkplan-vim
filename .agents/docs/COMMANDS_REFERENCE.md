# Commands reference — deepworkplan-vim

Slash commands under [`.agents/commands/`](../commands/). Three invocation
forms, so flow discovery stays local and host-portable:

1. **Claude Code:** `/<name>` (e.g. `/dwp-create`)
2. **Agents that intercept `/` (Codex, Cursor, …):** `#<name>` (e.g. `#dwp-create`)
3. **Any host, plain text:** "run `<name>`" (e.g. "run dwp-create …")

## DWP flows (thin delegators to the `deepworkplan` skill)

| Command | Routes to | Use for |
|---|---|---|
| [`/dwp-create`](../commands/dwp-create.md) | `create` sub-skill | turn a goal into an executable plan (Lite by default; `full`/`lite`/`trust` modifiers) |
| [`/dwp-execute`](../commands/dwp-execute.md) | `execute` | run the plan task-by-task, validating each gate |
| [`/dwp-refine`](../commands/dwp-refine.md) | `refine` | add/remove/reorder tasks; promote Lite → Full |
| [`/dwp-resume`](../commands/dwp-resume.md) | `resume` | reconstruct state and continue an interrupted plan |
| [`/dwp-status`](../commands/dwp-status.md) | `status` | progress report, read-only |
| [`/dwp-verify`](../commands/dwp-verify.md) | `verify` | objective conformance verdict, read-only |
| [`/dwp-upgrade`](../commands/dwp-upgrade.md) | `upgrade` | check for a newer skill; diff + consent before installing |

## Kit authoring

| Command | Routes to | Use for |
|---|---|---|
| [`/skill-create`](../commands/skill-create.md) | `author` | author/update a skill in this repo |
| [`/agent-create`](../commands/agent-create.md) | `author` | author/update an agent persona |

The sub-skills behind every command are directly invocable too
(`/deepworkplan-create`, `#deepworkplan-create`, …) — the `dwp-*` files are
the short aliases. Commands are thin by design: the flow content lives in the
skill, never duplicated in the command.
