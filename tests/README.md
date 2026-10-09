# Mapping tests

Go contract checks. They parse Lua and VimScript mapping files; they do not start Neovim. Mini and VimScript are tested from this repo.

```bash
# Podman or Docker (preferred)
./tests/run.sh

# Host, if you have Go
cd tests && go test -count=1 -parallel 8 .
```

`./tests/run.sh` uses Podman when it is on PATH, otherwise Docker. Compose mounts Current, Mini, and VimScript and runs the three suites in parallel.

`shared` must exist in every flavor. `current` is Lua-only. `vim-family` is Mini/VimScript.

## What lives where

| File | Responsibility |
|---|---|
| `mappings_test.go` | the contract assertions: `shared` / `currentOnly` / `vimFamily` groups, per-flavor subtests |
| `contract.go` | the expected keybinding tables the assertions check against |
| `extract.go` | parsing of Lua/VimScript mapping files into comparable keys |
| `run.sh` | Podman/Docker runner (compose mounts the three flavors) |
| `Dockerfile`, `compose.yml`, `go.mod` | the suite's own container and module |

The authoritative gates, scoped patterns, and the fallback live in
[docs/TESTING_GUIDE.md](../docs/TESTING_GUIDE.md); a mapping change in
[lua/mapping/](../lua/README.md) updates `contract.go` in the same change.

## Installer harness

`tests/installer/` is a separate, bash-only suite (not Go, not containerized):
it runs the real `install.sh` against PATH shims. See
[tests/installer/README.md](installer/README.md).
