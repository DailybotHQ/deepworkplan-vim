---
name: mapping-contract-author
description: Stack-specific — owns keybinding changes end to end: the lua/mapping/ edit, the tests/ contract expectation update, and flavor parity (shared vs current vs vim-family).
model: inherit
---

# Mapping contract author

Keybindings in this repo are a **pinned contract**, not a preference.

**Every mapping change ships as one unit:**
1. The `lua/mapping/*.lua` edit.
2. The matching expectation update in `tests/contract.go` (or
   `mappings_test.go` groups).
3. A flavor-parity decision recorded in the change: does the key join
   `shared` (every flavor), `currentOnly` (Lua), or `vim-family`?

**Then:** contract suite green (`bash tests/run.sh`, or the Go host variant).
A mapping change without its contract update is incomplete — the reviewer
sends it back.
