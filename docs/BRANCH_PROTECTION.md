# Branch protection — pull requests only, CI required

The rule: **nothing reaches `main` except through a pull request whose `CI gate`
is green.** This repository documents the rule ([CONTRIBUTING.md](../CONTRIBUTING.md#pull-requests-only),
[AGENTS.md](../AGENTS.md)); GitHub enforces it through a ruleset. Agents
cannot change repository settings, so the ruleset ships as a file for the
**owner** to apply once.

## What the ruleset enforces

[`ruleset-main.json`](ruleset-main.json), applied to the default branch:

| Rule | Effect |
|---|---|
| Pull request required | no direct pushes; stale approvals are dismissed on a new push; review threads must be resolved |
| Required status check `CI gate` | the single job at the end of `.github/workflows/ci.yml`; it passes only when hygiene, lint, smoke, the installer harness, the mapping contracts and the container install (with the boot check) all passed, and the branch must be up to date |
| No force-push, no deletion | history is never rewritten |
| Linear history | merges are squash or rebase; the pull-request title becomes the commit, which the release flow reads |
| No bypass actors | the rule binds everyone |

`required_approving_review_count` is **0** in the file: GitHub does not let an
author approve their own pull request, so with a single maintainer a required
review would block every merge. The owner's act of merging after a green gate
is the approval. With a team, raise it to 1 and set `require_code_owner_review`
to `true` (`.github/CODEOWNERS` names the owner).

## Apply it (owner, one time)

Needs repository admin and the GitHub CLI.

```bash
# See what is configured today
gh api repos/DailybotHQ/deepworkplan-vim/rulesets
gh api repos/DailybotHQ/deepworkplan-vim/branches/main/protection   # classic rules, if any

# Create the ruleset from the file in this repository
gh api --method POST repos/DailybotHQ/deepworkplan-vim/rulesets --input docs/ruleset-main.json
```

If a classic branch-protection rule already exists, keep one mechanism: remove
the classic rule once the ruleset is active, or add the same checks there. The
required check's name is `CI gate` (the job name in `ci.yml`); the check only
appears in the picker after the workflow has run once on a pull request.

## Why one aggregate check

Branch protection matches checks by name. Listing every job would break the
moment a job is renamed or added; a skipped required job counts as passed. The
`gate` job `needs` all of them, runs `if: always()`, and fails unless every
result is `success`, so one name covers the whole pipeline.

## What this does not do

It does not review code. The owner does; a CI self-review by the AI Diff
Reviewer is not installed in this repository (a documented decision in
`AGENTS.md`), though the local reviewer is available before a pull request.
