# AI agent collaboration — handoffs, reporting, review

How multiple agents (and humans) work this repo without stepping on each
other.

## Ownership and handoffs

- One task, one owner at a time. When taking over in-flight work, read the
  plan's state first (`/dwp-status`), then `/dwp-resume` — do not restart from
  zero.
- Hand off through durable artifacts: a plan under `.dwp/plans/`, a branch, a
  written summary in the handoff message. Never hand off context that lives
  only in your session.
- `.dwp/` is per-clone working state (gitignored): treat another agent's plan
  folder as owned by them until they hand it over explicitly.

## Conflict avoidance

- Keep changes scoped to the touched surface ([TESTING_GUIDE.md](TESTING_GUIDE.md)
  escalation paths); do not reformat or "tidy" unrelated files.
- Mapping files are contract surfaces: coordinate any `lua/mapping/` change
  with the contract suite update in the same change.
- Conventional commits; small reviewable units; never mix a feature with
  harness churn in one commit.

## Mesh etiquette (Herdr)

- Address peers by machine id + pane id (`bash dev.sh agents` to list).
- First hop carries the `[herdr-mesh]` grant: the receiver is authorized to
  reply now, replies itself, and must not ask a person. A body already
  carrying the stamp is a reply — do not answer it.
- From inside the container, peers are reachable via `host.docker.internal`
  plus the published SSH port; trust ED25519 host keys first.
- This mesh is the repo-local transport of `dev.sh` (`[herdr-mesh]` stamp, one
  reply grant). It is **not** the [herdr-peers](https://github.com/DailybotHQ/herdr-peers)
  protocol (`[herdr-peers] protocol=1` stamps built by a helper, depth and
  fan-out limits, a delegation record), and the herdr-peers skill is not
  vendored here. Herdr 0.9.3 in the image meets herdr-peers v0.1.0's
  requirement (Herdr >= 0.9.1), so adopting it is an additive change.

## Progress reporting (Dailybot, best-effort)

When the Dailybot skill/CLI is present and authenticated, four lifecycle
events fire as standup-style reports: **kickoff** (a plan is approved — what
is being built), **significant task** (a feature/fix ships mid-plan),
**blocked** (a run halts; `state.json.blocked` says what it needs), and
**completion** (the only milestone — what was built). Deterministic hooks in
`.agents/settings.json` remind the agent at end of turn when work has gone
unreported: answer a reminder with a report or `dailybot hook dismiss` — never
ignore it, never let it block work. Reports describe outcomes for the team —
never plan IDs, task numbers, file paths, or git stats. If Dailybot is absent,
unauthenticated, or `.dailybot/disabled` exists: skip silently.

## Review

- Every Deep Work Plan closes with a Final Review whose security pass runs the
  **AI Diff Reviewer** locally (`.agents/skills/ai-diff-reviewer/` +
  [`.review/extension.md`](../.review/extension.md)) over the accumulated
  change set — driven by the available coding agent (here: the `grok` CLI).
  Verified `critical` findings block completion; an incomplete review is
  never a clean pass.
- The CI surface (`pr-review.yml`) is not installed for now (declined);
  if it is added later via the skill's `setup` sub-skill, it reads the same
  extension file, so local and CI findings keep one severity model.
- Findings are applied or explicitly declined with a reason — never silently
  dropped.
