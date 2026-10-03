# utilities/ — installer and generators

Support modules for the editor config's install flow and generated assets.

| Sub-module | Responsibility |
|---|---|
| `installation/` | the multi-distro installer behind [install.lua](../install.lua): `cli.lua` (arg parsing), `util.lua` (paths, platform detection), `installer.lua` (package managers: pacman/apt/dnf, Homebrew, winget), `greeter.lua` / `done.lua` (UX), plus the bundled Iosevka Nerd Font |
| `snippets/` | snippet tooling: `parser.sh`, Node-based `getters/` (see `package.json`) that produce the committed [../snippets/](../snippets/README.md) sources |
| `spelling/` | `generateLang.sh` — regenerates the spell dictionaries committed under [../dicts/](../dicts/README.md) |

## Invariants (review-critical)

- The installer is **idempotent** and moves the user's previous config to
  `~/.config/previous-deepworkplan-vim` — never deletes it.
- `sudo` only for package installation, never for config writes.
- All three platform families are first class; a change reasoning about one
  family only is incomplete. See [docs/STANDARDS.md](../docs/STANDARDS.md).

Smoke coverage: multi-distro installer smokes via the root `compose.yml`.
