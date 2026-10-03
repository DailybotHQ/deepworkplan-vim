# docker/ — contributor container

The **dev** environment for working on this repo (the editor itself mounts in;
no second clone). Operational detail lives in
[docker/local/README.md](local/README.md); the full picture in
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).

| Piece | Responsibility |
|---|---|
| `local/docker-compose.yaml` | the `dwpvim` service: Neovim 0.12.5 + Herdr, `/workspace` mount, loopback SSH publish, `.env` loading |
| `local/dwpvim/Dockerfile` | image build; coding-CLI build args, **all default false** |
| `local/dwpvim/entrypoint.sh` | CLI-auth persistence: guarded symlink surgery onto `~/.claude*` (and peers) backed by volumes |
| `local/.env.example`, `local/dwpvim/.env.example` | **placeholder-only** env templates; real copies are created 0600 by `dev.sh` |
| `custom_commands.sh` | extra image commands |

Hard rules (enforced by review — see [docs/SECURITY.md](../docs/SECURITY.md)):
host `~/.ssh` mounts **read-only**; SSH publishes on `127.0.0.1` only; no SSH
private host keys baked into the image; no real values in `.env.example`.

Daily driver: `bash dev.sh` (`up` / `down` / `shell` / `build` / `rebuild` /
`agents` / `ask`) — see [docs/DEVELOPMENT_COMMANDS.md](../docs/DEVELOPMENT_COMMANDS.md).
