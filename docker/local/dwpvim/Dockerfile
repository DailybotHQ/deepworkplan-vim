FROM debian:trixie-slim
LABEL maintainer="developers@dailybot.com"
LABEL org.opencontainers.image.title="deepworkplan-vim"
LABEL org.opencontainers.image.description="Dev image for DeepWorkPlan Vim — Neovim config for humans and agents."
LABEL org.opencontainers.image.source="https://github.com/DailybotHQ/deepworkplan-vim"

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
      nodejs fontconfig black python3-neovim gcc make && \
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

ARG GH_VERSION=2.83.2
RUN GH_ARCH="$(dpkg --print-architecture)" \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz" -o /tmp/gh.tar.gz \
    && tar -xzf /tmp/gh.tar.gz -C /tmp \
    && install -m 0755 "/tmp/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh" /usr/local/bin/gh \
    && rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VERSION}_linux_${GH_ARCH}" \
    && gh --version

RUN adduser --disabled-password --gecos "" --uid 1000 dev \
    && echo 'dev ALL=(root) NOPASSWD:ALL' > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev

ENV PATH="/home/dev/.local/bin:/home/dev/.cursor/bin:/home/dev/.opencode/bin:/home/dev/.grok/bin:${PATH}"
ENV EDITOR=nvim
ENV VISUAL=nvim
ENV GIT_EDITOR=nvim
# pnpm lives under the user prefix, same path utilities/installation
# (installer.lua pnpm_home) resolves to. pnpm 10+ refuses `pnpm add -g`
# unless PNPM_HOME/bin is on PATH (installer.lua pnpm_env).
ENV PNPM_HOME="/home/dev/.local/share/pnpm"
ENV PATH="${PNPM_HOME}/bin:${PATH}"

RUN printf '%s\n' \
    'for d in "$HOME/.local/bin" "$HOME/.cursor/bin" "$HOME/.opencode/bin" "$HOME/.grok/bin"; do' \
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

USER dev
ARG INSTALL_CLAUDE_CLI=false
RUN if [ "$INSTALL_CLAUDE_CLI" = "true" ]; then \
      curl -fsSL https://claude.ai/install.sh | bash \
      && rm -rf /home/dev/.claude /home/dev/.claude.json; \
    else echo "INSTALL_CLAUDE_CLI is not true; skipping claude"; fi
USER root

USER dev
ARG INSTALL_CURSOR_CLI=false
RUN if [ "$INSTALL_CURSOR_CLI" = "true" ]; then \
      curl -fsSL https://cursor.com/install | bash; \
    else echo "INSTALL_CURSOR_CLI is not true; skipping cursor"; fi
USER root
ARG INSTALL_CURSOR_CLI=false
RUN if [ "$INSTALL_CURSOR_CLI" = "true" ]; then \
      ln -sf /home/dev/.cursor/bin/agent /usr/local/bin/agent; \
    else echo "INSTALL_CURSOR_CLI is not true; skipping agent symlink"; fi

USER dev
ARG INSTALL_OPENCODE_CLI=false
ARG INSTALL_GROK_CLI=false
RUN if [ "$INSTALL_OPENCODE_CLI" = "true" ]; then \
      curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path; \
    else echo "INSTALL_OPENCODE_CLI is not true; skipping opencode"; fi
RUN if [ "$INSTALL_GROK_CLI" = "true" ]; then \
      curl -fsSL https://x.ai/cli/install.sh | bash; \
    else echo "INSTALL_GROK_CLI is not true; skipping grok"; fi
RUN curl -fsSL https://herdr.dev/install.sh | sh
USER root
RUN ln -sfn /home/dev/.local/bin/herdr /usr/local/bin/herdr
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
ARG NVIM_VERSION=0.12.5
RUN set -eu; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) nvim_arch=linux-x86_64 ;; \
      arm64) nvim_arch=linux-arm64 ;; \
      *) echo "unsupported arch for neovim tarball: $arch" >&2; exit 1 ;; \
    esac; \
    tmp="$(mktemp)"; \
    curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-${nvim_arch}.tar.gz" -o "$tmp"; \
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
# repo-relative: the compose build context is the repository root.
COPY init.lua delete.lua CheatSheet.md /opt/dwpvim-config/
COPY lua/ /opt/dwpvim-config/lua/
COPY snippets/ /opt/dwpvim-config/snippets/
COPY dicts/ /opt/dwpvim-config/dicts/
COPY utilities/installation/ /opt/dwpvim-config/utilities/installation/

USER dev
# pnpm via the official installer, then biome — the same commands
# installer.lua's ensure_pnpm / ensure_formatters run on a host (the
# PNPM_HOME/bin PATH entry comes from the ENV above). The font goes to
# ~/.local/share/fonts + fc-cache, where installer.lua install_font puts it.
RUN set -eu; \
    curl -fsSL https://get.pnpm.io/install.sh | env SHELL=/bin/bash sh -; \
    pnpm add -g @biomejs/biome; \
    mkdir -p "$HOME/.local/share/fonts"; \
    install -m 0644 /opt/dwpvim-config/utilities/installation/iosevka_nerd_font.ttf \
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
