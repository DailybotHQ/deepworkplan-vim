# Security policy

## Supported versions

| Version | Supported |
|---|---|
| v0.4.x (latest release) | yes |
| < v0.4.0 | no — upgrade to the latest release |

Fixes ship in a new release; pin by tag and upgrade.

## Reporting a vulnerability

**Do not open a public issue, discussion or pull request for a
vulnerability.** Report it privately:

- **GitHub private vulnerability reporting** (preferred):
  [Report a vulnerability](https://github.com/DailybotHQ/deepworkplan-vim/security/advisories/new)
- or email **security@dailybot.com**.

Include the affected version or commit, the impact, and steps to reproduce.

## What to expect

| Step | Target |
|---|---|
| Acknowledgement | within 3 business days |
| Initial assessment (severity, affected versions) | within 10 business days |
| Fix released — critical / high | within 30 days of confirmation |
| Fix released — medium / low | next planned release |

We keep you informed during the fix, credit you in the advisory unless you
prefer otherwise, and publish a GitHub Security Advisory once a fixed
release is available.

## Scope

In scope: the installer (`install.sh`, `install.lua`, `delete.lua`,
`utilities/installation/`), the editor configuration (`lua/`), the
contributor container (`docker/`, `dev.sh`; SSH surface and Herdr mesh), and
the CI and release workflows. Out of scope: vulnerabilities in Neovim, its
plugins or third-party tools themselves — report those upstream.

How these surfaces are kept safe is documented in
[docs/SECURITY.md](docs/SECURITY.md).
