---
name: lib-upgrade
description: Upgrade Vim dependencies through the DeepWorkPlan dependency-upgrade flow and the pinned plugin refresh gate.
---

# /lib-upgrade

Invoke `.agents/skills/deepworkplan/addons/dependency-upgrade/SKILL.md`.
This command is inert: installation runs no dependency upgrade.

Reason about the actual dependency source before choosing an update command:
Neovim plugins and pckr are pinned in `pckr/lockfile.lua` with specs in
`lua/plugin_specs.lua`; the Go mapping-test module lives under `tests/`.
For plugin changes, use the repository-owned `scripts/update-plugin-lock.sh`
process and its isolation rules from CONTRIBUTING.md, never hand-edit the lock
or substitute npm tooling. For a Go dependency change, use its actual manifest
and gate inside `tests/`. Classify requested changes, preserve recoverable
snapshots, validate each batch with the appropriate smoke/installer/mapping
gates and revert failures. Major upgrades require explicit approval; plugin
updates execute upstream build hooks only under the repository's consent rules.
Present the verified diff and report; do not auto-commit or auto-upgrade.
