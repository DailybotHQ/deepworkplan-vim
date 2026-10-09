# Performance — deepworkplan-vim

Keep brief by design: this is an editor config, not a service. Two surfaces
have real budgets.

## Editor startup (the budget that matters)

- `lua/settings.lua` sets `lazyredraw` and disables swap/backup writes up
  front — keep those flags.
- pckr.nvim bootstraps lazily; `lua/plugins.lua` clones it once and reuses the
  stdpath copy. The plugin lock adds one small `dofile` (`pckr/lockfile.lua`)
  and one read of pckr's `.git/HEAD` per start — no git process unless pckr
  is away from its pin. Avoid adding work to `init.lua`'s boot chain that could be
  deferred into `composition` or a plugin's own lazy hook.
- The perceptible target: first frame on a warm cache should not regress when
  plugins are added — if an addition needs eager loading, justify it in a
  comment.

## Batch surfaces

- `lua/setUp/*` (finder, statusline, file manager) wrap tools invoked per
  keystroke or per buffer — no shell-outs on hot paths (per-keystroke
  statusline segments, per-save hooks) without caching.
- The Go contract suite runs parse-only and in parallel; keep it that way
  (no Neovim startup in tests).

## Container / CI

- Image build time is accepted cost; runtime of the dev container has no
  budget. The release workflow is event-driven and cheap; keep its steps
  linear and uncached where correctness depends on fresh tags
  (`fetch-depth: 0` for tag resolution).
