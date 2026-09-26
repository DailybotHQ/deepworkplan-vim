# Contributor container

See the root `README.md` and `AGENTS.md`.

- Image: Debian Trixie, user `dev`, Neovim 0.12.5, Herdr
- Repo mount: `/workspace` → `~/.config/nvim`
- SSH: `127.0.0.1:22035`
- Copy `dwpvim/.env.example` to `dwpvim/.env` before `bash dev.sh up`
