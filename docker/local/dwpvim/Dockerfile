# Base pinned by dated tag AND digest (the digest wins; the tag documents it).
FROM debian:trixie-20261005-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f
LABEL org.opencontainers.image.title="deepworkplan-vim"
LABEL org.opencontainers.image.description="Contributor image for DeepWorkPlan Vim — Neovim config for humans and agents."
LABEL org.opencontainers.image.licenses="GPL-3.0"

# Every tool below is pinned by version; release artifacts are verified by
# sha256 (vendor-published where the vendor publishes one, otherwise the
# value recorded when the pin was taken — see docker/local/README.md
# "Pinned tools"). No vendor install script is piped to a shell.
#
# Coding CLIs are opt-in. Only the exact string "true" installs.
# herdr stays unconditional — it is the mesh runtime.
ARG INSTALL_CLAUDE_CLI=false
ARG INSTALL_CURSOR_CLI=false
ARG INSTALL_CODEX_CLI=false
ARG INSTALL_PI_CLI=false
ARG INSTALL_OPENCODE_CLI=false
ARG INSTALL_CLINE_CLI=false
ARG INSTALL_GROK_CLI=false

# One apt layer. lua/rg/fd for the installer; node for the config's kit
# (markdown-preview, bracey) and pnpm; fontconfig so the baked font is
# indexed (fc-cache); black + python3-neovim mirror installer.lua's own
# apt-get mapping (extras: black; core: python3-neovim); gcc/make compile
# treesitter parsers during the baked plugin sync. Do not apt-install
# neovim: nvim is the 0.12.5 tarball in /home/dev/.local. Do not bake SSH
# host keys. Zenity is deliberately absent (GUI dep, headless image).
RUN apt-get update -y && \
    apt-get install --no-install-recommends -y \
      less git curl gnupg ca-certificates openssh-client openssh-server \
      sudo nano python3 lua5.4 ripgrep fd-find adduser \
      nodejs npm fontconfig black python3-neovim gcc make && \
    mkdir -p /var/run/sshd /etc/ssh/sshd_config.d && \
    rm -f /etc/ssh/ssh_host_* && \
    printf '%s\n' \
      'PasswordAuthentication no' \
      'PubkeyAuthentication yes' \
      'PermitRootLogin no' \
      'UsePAM yes' \
      'AllowTcpForwarding yes' \
      'AllowStreamLocalForwarding yes' \
      > /etc/ssh/sshd_config.d/herdr.conf && \
    ln -sf "$(command -v fdfind)" /usr/local/bin/fd && \
    ln -sf "$(command -v lua5.4)" /usr/local/bin/lua && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

# gh: sha256 values from the release's gh_<v>_checksums.txt.
ARG GH_VERSION=2.83.2
ARG GH_SHA256_AMD64=ca6e7641214fbd0e21429cec4b64a7ba626fd946d8f9d6d191467545b092015e
ARG GH_SHA256_ARM64=b1a0c0a0fcf18524e36996caddc92a062355ed014defc836203fe20fba75a38e
RUN GH_ARCH="$(dpkg --print-architecture)" \
    && case "$GH_ARCH" in \
         amd64) GH_SHA256="$GH_SHA256_AMD64" ;; \
         arm64) GH_SHA256="$GH_SHA256_ARM64" ;; \
         *) echo "unsupported arch for gh: $GH_ARCH" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz" -o /tmp/gh.tar.gz \
    && echo "${GH_SHA256}  /tmp/gh.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/gh.tar.gz -C /tmp \
    && install -m 0755 "/tmp/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh" /usr/local/bin/gh \
    && rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VERSION}_linux_${GH_ARCH}" \
    && gh --version

RUN adduser --disabled-password --gecos "" --uid 1000 dev \
    && echo 'dev ALL=(root) NOPASSWD:ALL' > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

ENV PATH="/home/dev/.local/bin:/home/dev/.grok/bin:${PATH}"
# Pinned CLIs stay pinned: Claude Code's background self-update is off.
ENV DISABLE_AUTOUPDATER=1
ENV EDITOR=nvim
ENV VISUAL=nvim
ENV GIT_EDITOR=nvim
# pnpm lives under the user prefix, same path utilities/installation
# (installer.lua pnpm_home) resolves to. pnpm 10+ refuses `pnpm add -g`
# unless PNPM_HOME/bin is on PATH (installer.lua pnpm_env).
ENV PNPM_HOME="/home/dev/.local/share/pnpm"
ENV PATH="${PNPM_HOME}/bin:${PATH}"

RUN printf '%s\n' \
    'for d in "$HOME/.local/bin" "$HOME/.grok/bin"; do' \
    '  case ":${PATH}:" in' \
    '    *":${d}:"*) ;;' \
    '    *) [ -d "$d" ] && PATH="${d}:${PATH}" ;;' \
    '  esac' \
    'done' \
    'export PATH' \
    > /etc/profile.d/00-local-bin-first.sh \
    && chmod 0644 /etc/profile.d/00-local-bin-first.sh

USER dev
RUN git config --global init.defaultBranch main \
    && git config --global pull.rebase false \
    && git config --global safe.directory '*' \
    && git config --global core.editor nvim
USER root

RUN echo 'source /workspace/docker/custom_commands.sh' >> /home/dev/.bashrc

RUN mkdir -p /home/dev/.claude_data /home/dev/.codex_data /home/dev/.cursor_data /home/dev/.gh_data \
    /home/dev/.chelper_data /home/dev/.cline /home/dev/.opencode_data /home/dev/.pi_data \
    /home/dev/.herdr_data /home/dev/.grok_data /home/dev/.ssh /workspace \
    && chown -R dev:dev /home/dev /workspace

# --- Coding CLIs (opt-in) and Herdr ---------------------------------------
# Native binaries come from each vendor's versioned release URL and are
# checked against a pinned sha256. npm-distributed CLIs are installed from
# the registry at an exact version (npm verifies the package integrity hash)
# into the user prefix ~/.local, so their entry points land in ~/.local/bin.
# Bump a pin by editing its ARGs together (version + every sha256).
USER dev

# Claude Code: native binary. sha256 from the release manifest
# (downloads.claude.ai/claude-code-releases/<v>/manifest.json). Debian's
# Node 20 is below the npm package's engines floor (>= 22), so the native
# build is the supported route. The auto-updater is disabled at runtime
# (ENV DISABLE_AUTOUPDATER below) so the pinned version stays pinned.
ARG CLAUDE_CODE_VERSION=2.1.286
ARG CLAUDE_CODE_SHA256_X64=fe503f65c6289d59c23e5b21ae44f03583f997dd33a2cbfc75ab4f96fb8fc73f
ARG CLAUDE_CODE_SHA256_ARM64=0292fa22ac2fd43e16be9d0e511ddd8347280d6e0ebaca744ef5b27e05d8d0f8
RUN if [ "$INSTALL_CLAUDE_CLI" = "true" ]; then \
      set -eu; \
      case "$(dpkg --print-architecture)" in \
        amd64) plat=linux-x64; sum="$CLAUDE_CODE_SHA256_X64" ;; \
        arm64) plat=linux-arm64; sum="$CLAUDE_CODE_SHA256_ARM64" ;; \
        *) echo "unsupported arch for claude" >&2; exit 1 ;; \
      esac; \
      tmp="$(mktemp)"; \
      curl -fsSL "https://downloads.claude.ai/claude-code-releases/${CLAUDE_CODE_VERSION}/${plat}/claude" -o "$tmp"; \
      echo "${sum}  ${tmp}" | sha256sum -c -; \
      mkdir -p /home/dev/.local/bin; \
      install -m 0755 "$tmp" /home/dev/.local/bin/claude; \
      rm -f "$tmp"; \
      rm -rf /home/dev/.claude /home/dev/.claude.json; \
    else echo "INSTALL_CLAUDE_CLI is not true; skipping claude"; fi

# Cursor CLI: versioned package tarball (the URL the vendor script pins
# internally). The vendor publishes no checksum; the sha256 values were
# recorded when this pin was taken (trust on first use, see README).
ARG CURSOR_CLI_VERSION=2026.10.01-e373342
ARG CURSOR_CLI_SHA256_X64=a79726c6e644520e993970be4c45775a6889802b67abe461a677a53219ae28e8
ARG CURSOR_CLI_SHA256_ARM64=785c5f6bf2a60eb1121e27ed8c14f5ee07ed1b5b6692324f2d9a997238245eb5
RUN if [ "$INSTALL_CURSOR_CLI" = "true" ]; then \
      set -eu; \
      case "$(dpkg --print-architecture)" in \
        amd64) arch=x64; sum="$CURSOR_CLI_SHA256_X64" ;; \
        arm64) arch=arm64; sum="$CURSOR_CLI_SHA256_ARM64" ;; \
        *) echo "unsupported arch for cursor" >&2; exit 1 ;; \
      esac; \
      tmp="$(mktemp)"; \
      curl -fsSL "https://downloads.cursor.com/lab/${CURSOR_CLI_VERSION}/linux/${arch}/agent-cli-package.tar.gz" -o "$tmp"; \
      echo "${sum}  ${tmp}" | sha256sum -c -; \
      dir="/home/dev/.local/share/cursor-agent/versions/${CURSOR_CLI_VERSION}"; \
      mkdir -p "$dir" /home/dev/.local/bin; \
      tar --strip-components=1 -xzf "$tmp" -C "$dir"; \
      rm -f "$tmp"; \
      ln -sfn "$dir/cursor-agent" /home/dev/.local/bin/cursor-agent; \
      ln -sfn "$dir/cursor-agent" /home/dev/.local/bin/agent; \
    else echo "INSTALL_CURSOR_CLI is not true; skipping cursor"; fi

# Grok CLI: versioned binary from the vendor's artifact URL. No published
# checksum; recorded on first use like Cursor. Only `grok` is linked — the
# vendor script also links an `agent` alias, which would shadow Cursor's.
ARG GROK_CLI_VERSION=1.0.50
ARG GROK_CLI_SHA256_X86_64=c80de0155706ff2d995623887b102f2d0abd2c62b2643dea3a0cebaf7dd724d5
ARG GROK_CLI_SHA256_AARCH64=947eea63e52393e00778d651d22e0dad22d30e9ee5b2af7944efc3fd4438ecc0
RUN if [ "$INSTALL_GROK_CLI" = "true" ]; then \
      set -eu; \
      case "$(dpkg --print-architecture)" in \
        amd64) arch=x86_64; sum="$GROK_CLI_SHA256_X86_64" ;; \
        arm64) arch=aarch64; sum="$GROK_CLI_SHA256_AARCH64" ;; \
        *) echo "unsupported arch for grok" >&2; exit 1 ;; \
      esac; \
      tmp="$(mktemp)"; \
      curl -fsSL "https://x.ai/cli/grok-${GROK_CLI_VERSION}-linux-${arch}" -o "$tmp"; \
      echo "${sum}  ${tmp}" | sha256sum -c -; \
      mkdir -p /home/dev/.grok/bin; \
      install -m 0755 "$tmp" /home/dev/.grok/bin/grok; \
      rm -f "$tmp"; \
    else echo "INSTALL_GROK_CLI is not true; skipping grok"; fi

# npm-distributed CLIs, exact versions ($pkgs is split into words on purpose).
ARG CODEX_CLI_VERSION=0.162.0
ARG OPENCODE_CLI_VERSION=1.18.35
ARG PI_CLI_VERSION=0.73.1
ARG CLINE_CLI_VERSION=3.0.70
RUN set -eu; \
    pkgs=""; \
    if [ "$INSTALL_CODEX_CLI" = "true" ]; then pkgs="$pkgs @openai/codex@${CODEX_CLI_VERSION}"; fi; \
    if [ "$INSTALL_OPENCODE_CLI" = "true" ]; then pkgs="$pkgs opencode-ai@${OPENCODE_CLI_VERSION}"; fi; \
    if [ "$INSTALL_PI_CLI" = "true" ]; then pkgs="$pkgs @mariozechner/pi-coding-agent@${PI_CLI_VERSION}"; fi; \
    if [ "$INSTALL_CLINE_CLI" = "true" ]; then pkgs="$pkgs cline@${CLINE_CLI_VERSION}"; fi; \
    if [ -n "$pkgs" ]; then \
      npm install -g --prefix /home/dev/.local $pkgs; \
    else echo "no npm-distributed coding CLI requested; skipping"; fi

# Herdr (always): GitHub release binary, sha256 from herdr.dev/latest.json
# for this version.
ARG HERDR_VERSION=0.9.3
ARG HERDR_SHA256_X86_64=18a8dc65f1c2fa485884344356dea1cfd911c6f06cf46fa78e193f4087f4dba7
ARG HERDR_SHA256_AARCH64=4de7aa3e25678812e92960de64f7c2aaa1bca1f0f80a3c5e559837e231e1f5c0
RUN set -eu; \
    case "$(dpkg --print-architecture)" in \
      amd64) arch=x86_64; sum="$HERDR_SHA256_X86_64" ;; \
      arm64) arch=aarch64; sum="$HERDR_SHA256_AARCH64" ;; \
      *) echo "unsupported arch for herdr" >&2; exit 1 ;; \
    esac; \
    tmp="$(mktemp)"; \
    curl -fsSL "https://github.com/herdrdev/herdr/releases/download/v${HERDR_VERSION}/herdr-linux-${arch}" -o "$tmp"; \
    echo "${sum}  ${tmp}" | sha256sum -c -; \
    mkdir -p /home/dev/.local/bin; \
    install -m 0755 "$tmp" /home/dev/.local/bin/herdr; \
    rm -f "$tmp"
USER root
RUN ln -sfn /home/dev/.local/bin/herdr /usr/local/bin/herdr \
    && if [ "$INSTALL_CURSOR_CLI" = "true" ]; then \
         ln -sfn /home/dev/.local/bin/agent /usr/local/bin/agent; \
       fi
USER dev
RUN mkdir -p /home/dev/.config/herdr && \
    if [ ! -f /home/dev/.config/herdr/config.toml ]; then \
      printf '%s\n' \
        '[experimental]' \
        'allow_nested = true' \
        > /home/dev/.config/herdr/config.toml; \
    fi

# Neovim tarball only. The repo is mounted at /workspace and linked to
# ~/.config/nvim at start — this image develops DeepWorkPlan Vim itself.
# sha256 values are the release assets' published digests.
ARG NVIM_VERSION=0.12.5
ARG NVIM_SHA256_X86_64=bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875
ARG NVIM_SHA256_ARM64=1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725
RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) nvim_arch=linux-x86_64; sum="$NVIM_SHA256_X86_64" ;; \
      arm64) nvim_arch=linux-arm64; sum="$NVIM_SHA256_ARM64" ;; \
      *) echo "unsupported arch for neovim tarball: $arch" >&2; exit 1 ;; \
    esac; \
    tmp="$(mktemp)"; \
    curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-${nvim_arch}.tar.gz" -o "$tmp"; \
    echo "${sum}  ${tmp}" | sha256sum -c -; \
    mkdir -p /home/dev/.local; \
    tar -xzf "$tmp" -C /home/dev/.local --strip-components=1; \
    rm -f "$tmp"; \
    test -x /home/dev/.local/bin/nvim
USER root
RUN ln -sfn /home/dev/.local/bin/nvim /usr/local/bin/nvim

# --- Baked editor surface ----------------------------------------------------
# The image ships a first-launch-ready editor: plugins, pnpm + biome, and the
# Iosevka Nerd Font are installed at build time, so `bash dev.sh shell` lands
# in a working nvim with no first-launch install. The config itself is NOT
# baked — at start the entrypoint symlinks ~/.config/nvim to /workspace (this
# repo IS the config). install.sh is the HOST installer and stays out of the
# image; the steps below mirror utilities/installation/installer.lua so the
# baked result matches what a host install produces.

# Build-time config copy (bootstrap input; removed again below). Paths are
# repo-relative: the compose build context is the repository root. Neovim
# resolves its config as $XDG_CONFIG_HOME/nvim, so the tree must sit one
# level inside the XDG root used for the headless bake below — copying to
# /opt/dwpvim-config/ directly would leave init.lua where Neovim never
# looks and the mason.nvim assert could never pass.
COPY init.lua delete.lua CheatSheet.md /opt/dwpvim-config/nvim/
COPY lua/ /opt/dwpvim-config/nvim/lua/
COPY snippets/ /opt/dwpvim-config/nvim/snippets/
COPY dicts/ /opt/dwpvim-config/nvim/dicts/
COPY utilities/installation/ /opt/dwpvim-config/nvim/utilities/installation/

USER dev
ARG PNPM_VERSION=10.34.6
ARG BIOME_VERSION=2.5.15
# pnpm from the npm registry (exact version), then biome (exact) — the same
# tools installer.lua's ensure_pnpm / ensure_formatters land on a host, at
# the same PNPM_HOME (the /bin PATH entry comes from the ENV above). The
# registry route replaces piping the official install script to a shell: npm
# verifies the package integrity hash before extracting, which this repo's
# review rules require for executed downloads in image builds. The font
# goes to ~/.local/share/fonts + fc-cache, where installer.lua install_font
# puts it.
RUN set -eu; \
    npm install -g --prefix "$PNPM_HOME" "pnpm@${PNPM_VERSION}"; \
    pnpm add -g "@biomejs/biome@${BIOME_VERSION}"; \
    mkdir -p "$HOME/.local/share/fonts"; \
    install -m 0644 /opt/dwpvim-config/nvim/utilities/installation/iosevka_nerd_font.ttf \
      "$HOME/.local/share/fonts/iosevka_nerd_font.ttf"; \
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null

# One headless bootstrap in one cache-able layer: plugins.lua's VimEnter
# autocmd syncs the pckr plugins and self-exits when the sync completes (the
# headless branch reserved for the install.sh bootstrap). XDG_CONFIG_HOME is
# set for this RUN only — at runtime the entrypoint links ~/.config/nvim to
# /workspace, and a persistent override would shadow that link. Success is
# the same check install.sh uses: mason.nvim present under pckr's opt pack.
RUN set -eu; \
    XDG_CONFIG_HOME=/opt/dwpvim-config timeout 900 nvim --headless; \
    test -d "$HOME/.local/share/nvim/site/pack/pckr/opt/mason.nvim"

USER root
# The bootstrap config copy was scaffolding; the runtime config is /workspace.
RUN rm -rf /opt/dwpvim-config

COPY docker/local/dwpvim/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
