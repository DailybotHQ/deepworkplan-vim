# Development commands — deepworkplan-vim

Every command verbatim, with preconditions. The short table lives in
[AGENTS.md](../AGENTS.md); this is the authoritative expansion.

## Install (end user, host)

```bash
git clone https://github.com/DailybotHQ/deepworkplan-vim.git ~/.config/nvim
cd ~/.config/nvim && lua install.lua      # needs lua / lua5.4 / luajit + git; sudo only for packages
nvim
```

Windows: clone into `%LOCALAPPDATA%\nvim`, then `lua install.lua`.
Uninstall: `lua delete.lua` (from the clone).

## Contributor environment (Docker)

```bash
cp docker/local/dwpvim/.env.example docker/local/dwpvim/.env   # placeholders only
bash dev.sh build      # build image (cache on)
bash dev.sh up         # start compose service (detached)
bash dev.sh shell      # shell as dev in /workspace (== ~/.config/nvim)
bash dev.sh down       # stop
bash dev.sh rebuild    # rebuild image and recreate
```

Selective coding CLIs (all default **false**):

```bash
docker compose -f docker/local/docker-compose.yaml build \
  --build-arg INSTALL_CLAUDE_CLI=true --build-arg INSTALL_CODEX_CLI=true
```

(Build args: `INSTALL_CLAUDE_CLI` `INSTALL_CURSOR_CLI` `INSTALL_CODEX_CLI`
`INSTALL_PI_CLI` `INSTALL_OPENCODE_CLI` `INSTALL_CLINE_CLI` `INSTALL_GROK_CLI`.)

Herdr SSH publishes at `127.0.0.1:22035` (override `HERDR_SSH_HOST_PORT`).
VS Code / Cursor: copy `.devcontainer_example/` → `.devcontainer/`.

## Mesh

```bash
bash dev.sh agents                        # list live Herdr machines/agents
bash dev.sh ask <#> "Prompt..."           # send with reply grant (# from that listing)
bash dev.sh ask <machine-id> <pane> "Prompt..."
```

## Validation (gates)

```bash
bash -n dev.sh
bash -n docker/local/dwpvim/entrypoint.sh
find lua utilities -name '*.lua' -print0 | xargs -0 luac5.4 -p   # full Lua parse
luac5.4 -p lua/mapping/git.lua                                  # scoped Lua parse
bash tests/run.sh                                               # contract suite — needs Podman/Docker
cd tests && go test -count=1 -parallel 8 .                      # contract suite — needs Go on host
```

Status of each gate on a bare dev host (bash + lua only): the first four run;
the last two need a container or Go. See [TESTING_GUIDE.md](TESTING_GUIDE.md)
for the evidence and the fallback.

## Installer smokes (multi-distro)

```bash
docker compose -f compose.yml run --rm <service>   # root compose.yml — distro installer smokes
```

Run from the repo root; consult `compose.yml` for the service names.

## DWP harness (plan work)

```text
/dwp-create "<goal>"   /dwp-execute   /dwp-resume   /dwp-status   /dwp-verify   /dwp-upgrade
```

(`#deepworkplan-create …` or plain text on hosts without slash commands; the
flows live in `.agents/skills/deepworkplan/`, discovery is local.)

## Release

Automatic: merge (or push) to `main` triggers
`.github/workflows/auto-release.yml` — semver from commit prefixes, GitHub
Release published. `[skip release]` in the merge body suppresses. Manual
dispatch: the workflow also exposes `workflow_dispatch`.
