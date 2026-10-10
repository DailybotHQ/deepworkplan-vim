# Configuration — `dwpvim.json`

Where the two sidebars sit and how wide they are. One JSON file, in the
repository, with a per-project override.

## Where the settings live

Later wins, and each key is checked on its own:

1. **Built-in defaults** (below).
2. **`dwpvim.json`** in the editor's own directory — the repository you cloned
   to `~/.config/nvim`. It ships with the defaults; edit it to change them for
   every project.
3. **`.dwpvim.json`** in the directory you started Neovim in — one project's
   override. Commit it to share it with the team, or keep it local.

A missing file is fine. A file that is not valid JSON, an unknown key or an invalid
value is **ignored and reported**, never fatal: the editor starts with the
next layer's value for that key.

## The keys

```json
{
  "tree":  { "side": "left", "width": 40 },
  "plans": { "side": "left", "width": 48 }
}
```

| Key | Values | Default | What it moves |
|---|---|---|---|
| `tree.side` | `"left"` or `"right"` | `"left"` | the file tree (`SPC n`) |
| `tree.width` | whole number, 20–120 | `40` | its maximum width; the tree still shrinks to its content |
| `plans.side` | `"left"` or `"right"` | `"left"` | the plans sidebar (`SPC P`) |
| `plans.width` | whole number, 20–120 | `48` | its maximum width; a narrow terminal still gets a proportional share, never an unreadable one |

Keys starting with `$` or `_` (such as the `"$comment"` the shipped file carries)
are documentation and are ignored. JSON has no comments, so use one of those keys.

## Examples

Both sidebars on the right:

```json
{ "tree": { "side": "right" }, "plans": { "side": "right" } }
```

A wider plans sidebar for one project (`.dwpvim.json` in that project):

```json
{ "plans": { "width": 72 } }
```

## Check what is in effect

`:DwpConfig` opens a small window with every value, the file it came from (or
`(default)`) and any problem found. Press `q` to close it. Settings are read once
at startup: restart Neovim after editing a file.

## For contributors

`lua/userconfig.lua` loads and validates the layers and sets
`vim.g.dwp_plans_side` / `vim.g.dwp_plans_width` for `lua/dwp/sidebar.lua`, which
must stay self-contained and so never requires the module itself. The file tree's
setup (`lua/setUp/fileManager.lua`) calls `userconfig.get`. Tests:
`tests/smoke/userconfig.lua` (layers, validation, the shipped file) and
`tests/smoke/dwp_sidebar.lua` (both sides, the width ceiling, the fallbacks).
To add a setting: a default and a rule in `lua/userconfig.lua`, the reader, a test,
and a row in the table above.
