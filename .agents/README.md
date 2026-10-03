# .agents/ — the cross-agent home

The canonical, agent-neutral home for everything that defines how AI
assistants behave in this repo. `.claude` and `.cursor` are symlinks to this
directory, so every agent reads the same files — nothing is Claude-only.

```
.agents/
├── agents/    worker personas (reviewer, architect, installer-maintainer, …)
├── commands/  thin dwp-* delegators + skill-create/agent-create
├── skills/    vendored, tag-pinned skills (deepworkplan, ai-diff-reviewer, dailybot, …)
├── docs/      skills_agents_catalog.md + COMMANDS_REFERENCE.md (match disk exactly)
└── settings.json  harness config (Dailybot hooks; no secrets)
```

Conventions:

- **Canonical paths are `.agents/...`** — never write `.claude/...` or
  `.cursor/...` in new content, and edit the real files here, not through the
  symlinks.
- **Commands stay thin** — they route to a skill's sub-skill; flow content is
  never duplicated (no drift).
- **Skills are vendored and tag-pinned** — recorded with content hashes in
  [`skills-lock.json`](../skills-lock.json); refresh through the documented
  channel (`npx --yes skills add <repo>@<tag> --skill <name> --force -y`),
  never by hand-editing a vendored skill except the deliberately repo-adapted
  `deepworkplan` copy (upgrades go through its `upgrade` sub-skill).
- **Catalogs match disk** — adding/removing a skill, agent, or command updates
  [docs/skills_agents_catalog.md](docs/skills_agents_catalog.md) or
  [docs/COMMANDS_REFERENCE.md](docs/COMMANDS_REFERENCE.md) in the same change.
