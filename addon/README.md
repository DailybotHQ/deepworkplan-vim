# Addon surface — `addon/surface.json`

`surface.json` is the machine-readable contract between DeepWorkPlan Vim
and anything that integrates it — first of all the DeepWorkPlan `vim`
addon, which reads this file instead of guessing paths, versions or
features. The editor never requires DeepWorkPlan, and DeepWorkPlan never
requires the editor; this file only makes the optional integration exact.

## Versioning

| Field | Meaning |
|---|---|
| `interface` | Integer version of **this file's shape and semantics**. `1` today. A breaking change (a key removed or renamed, a meaning changed) bumps it **and** the product's major version. Integrators refuse an unknown interface with one warning and treat the editor as not available — never as an error. |
| `version` | The release tag this tree is (or becomes). It never lags the newest `vX.Y.Z` tag; at a tagged commit it equals that tag. |

Additive changes (a new optional key, a new feature entry) keep
`interface: 1`. Pin the editor by tag (`v0.4.0`), never by branch.

## Sections

- **`detect`** — read-only detection. The config dir
  (`${XDG_CONFIG_HOME:-$HOME/.config}/nvim`, `%LOCALAPPDATA%\nvim` on
  Windows, or `DWP_VIM_DIR` when the installer was pointed elsewhere) is
  DeepWorkPlan Vim when it holds **both** identity files `install.lua` and
  `lua/plugins.lua` — the same pair the installer's "is this ours" check
  and `delete.lua` use. From v0.4.0 the config dir also carries
  `addon/surface.json`: read `interface` and `version` from it. The four
  states (`installed`, `installed_without_surface`, `existing_config`,
  `absent`) and what each implies are spelled out in the file.
  The **marker** `<data>/<appname>/pckr/.dwp-vim-bootstrapped` is written
  by `install.sh` after a clean headless plugin install; its absence does
  not mean the editor is absent (a manual `lua install.lua` install has no
  marker). The **legacy marker** `deepworkplan-vim-installed` was written
  by `install.lua` up to v0.3.1 only.
- **`install`** — the tag-pinned path: download `install.sh` from the
  tag's raw URL, verify `script.sha256`, run it with `DWP_VIM_REF` set to
  the tag. Download, verify and run are separate steps on purpose — no
  step pipes a download into a shell. `manual` and `windows` list the
  clone-at-tag alternatives; `consent` restates the installer's absolute
  rule: an existing config is moved aside only after an interactive yes,
  and a run without a terminal aborts and touches nothing.
- **`capabilities.plan_reader`** — what the editor's plan surfaces read:
  the plan's `manifest.json`, `journal.ndjson`, `state.json`, `README.md`
  checkboxes and `contract.json`, under `<cwd>/.dwp/plans` and
  `<config_dir>/.dwp/plans`. It is **read-only**: nothing under `.dwp/` is
  ever written by the editor.
- **`features`** — the user-facing features shipped by this tag, with
  their keys, commands and the first tag that ships them in their current
  form. Only features present in the tagged tree are listed.

## How it stays true

`tests/smoke/addon_surface.lua` (part of `bash tests/smoke/run.sh`) fails
when the file stops describing this tree: unparseable JSON, an interface
other than `1`, a version older than the newest tag (or different from
the tag at a tagged HEAD, or from `CHANGELOG.md`'s newest release), an
installer checksum that is not `sha256(install.sh)`, a marker name
`install.sh` does not write, a plan-reader file `lua/dwp` does not read,
or a feature key or command that is not defined in `lua/`.

When `install.sh` changes, update `install.script.sha256` in the same
commit; when a release is cut, bump `version`, `install.ref` and every
tag in `install` together.
