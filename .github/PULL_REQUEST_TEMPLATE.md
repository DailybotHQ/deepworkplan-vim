## Summary

<!-- What changes and why, in a few sentences. -->

## Linked issue

<!-- Closes #123, or "none" with a reason. -->

## Test evidence

<!-- Paste the result lines of the gates you ran (docs/TESTING_GUIDE.md). -->

- [ ] `bash scripts/check-public-hygiene.sh && bash tests/hygiene/run.sh`
- [ ] `find lua utilities -name '*.lua' -print0 | xargs -0 luac5.4 -p` and `bash -n` on touched scripts
- [ ] `bash tests/smoke/run.sh`
- [ ] `bash tests/installer/run.sh` (installer changes)
- [ ] Go mapping contracts (keymap changes; CI runs them)

## Checklist

- [ ] No secrets, tokens, private hostnames, personal paths or other private context
- [ ] Conventional Commit messages; one concern per PR
- [ ] Tests updated in the same change (keymaps → `tests/contract.go`, `install.sh` → `addon/surface.json` sha256)
- [ ] Docs updated (`README.md`, `docs/`, `CHANGELOG.md` under `[Unreleased]`)
- [ ] License (GPL-3.0) and `CREDITS.md` untouched
- [ ] Release PR only: CHANGELOG section and `addon/surface.json` name the new tag; otherwise merge with `[skip release]`
