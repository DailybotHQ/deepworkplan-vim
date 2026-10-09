#!/bin/bash

# Setup Claude CLI persistence with symlinks for a given user
setup_claude_persistence_for_user() {
    USER_HOME="$1"
    CLAUDE_DATA_DIR="${USER_HOME}/.claude_data"
    CLAUDE_JSON="${USER_HOME}/.claude.json"
    CLAUDE_DIR="${USER_HOME}/.claude"
    CLAUDE_JSON_BACKUP="${USER_HOME}/.claude.json.backup"

    mkdir -p "${CLAUDE_DATA_DIR}"

    if [ ! -L "${CLAUDE_JSON}" ]; then
        if [ -f "${CLAUDE_JSON}" ]; then
            if [ ! -f "${CLAUDE_DATA_DIR}/claude.json" ]; then
                cp "${CLAUDE_JSON}" "${CLAUDE_DATA_DIR}/claude.json"
                echo "  → Copied .claude.json to persistent volume"
            else
                echo "  → Preserving existing .claude.json from persistent volume"
            fi
            rm "${CLAUDE_JSON}"
        fi
        touch "${CLAUDE_DATA_DIR}/claude.json"
        ln -sf "${CLAUDE_DATA_DIR}/claude.json" "${CLAUDE_JSON}"
        echo "  → Created symlink for .claude.json"
    fi

    if [ ! -L "${CLAUDE_DIR}" ]; then
        if [ -d "${CLAUDE_DIR}" ]; then
            if [ ! -d "${CLAUDE_DATA_DIR}/claude_dir" ] || [ -z "$(ls -A "${CLAUDE_DATA_DIR}/claude_dir" 2>/dev/null)" ]; then
                cp -r "${CLAUDE_DIR}" "${CLAUDE_DATA_DIR}/claude_dir"
            fi
            rm -rf "${CLAUDE_DIR}"
        else
            mkdir -p "${CLAUDE_DATA_DIR}/claude_dir"
        fi
        ln -sf "${CLAUDE_DATA_DIR}/claude_dir" "${CLAUDE_DIR}"
    fi

    if [ -f "${CLAUDE_JSON_BACKUP}" ] && [ ! -L "${CLAUDE_JSON_BACKUP}" ]; then
        if [ ! -f "${CLAUDE_DATA_DIR}/claude.json.backup" ]; then
            cp "${CLAUDE_JSON_BACKUP}" "${CLAUDE_DATA_DIR}/claude.json.backup"
        fi
        rm "${CLAUDE_JSON_BACKUP}"
        ln -sf "${CLAUDE_DATA_DIR}/claude.json.backup" "${CLAUDE_JSON_BACKUP}"
    fi

    CLAUDE_CONFIG_DIR="${USER_HOME}/.config/claude-code"
    mkdir -p "${USER_HOME}/.config"
    if [ ! -L "${CLAUDE_CONFIG_DIR}" ]; then
        if [ -d "${CLAUDE_CONFIG_DIR}" ]; then
            if [ ! -d "${CLAUDE_DATA_DIR}/config_claude_code" ] || [ -z "$(ls -A "${CLAUDE_DATA_DIR}/config_claude_code" 2>/dev/null)" ]; then
                cp -r "${CLAUDE_CONFIG_DIR}" "${CLAUDE_DATA_DIR}/config_claude_code"
            fi
            rm -rf "${CLAUDE_CONFIG_DIR}"
        else
            mkdir -p "${CLAUDE_DATA_DIR}/config_claude_code"
        fi
        ln -sf "${CLAUDE_DATA_DIR}/config_claude_code" "${CLAUDE_CONFIG_DIR}"
    fi

    echo "Claude CLI persistence setup complete for ${USER_HOME}"
}

setup_claude_persistence_for_user "/home/dev"
chown -R dev:dev /home/dev/.claude_data /home/dev/.claude.json /home/dev/.claude /home/dev/.config/claude-code 2>/dev/null || true

setup_codex_persistence_for_user() {
    USER_HOME="$1"
    CODEX_DATA_DIR="${USER_HOME}/.codex_data"
    CODEX_DIR="${USER_HOME}/.codex"

    mkdir -p "${CODEX_DATA_DIR}"

    if [ ! -L "${CODEX_DIR}" ]; then
        if [ -d "${CODEX_DIR}" ]; then
            if [ ! -d "${CODEX_DATA_DIR}/codex_dir" ] || [ -z "$(ls -A "${CODEX_DATA_DIR}/codex_dir" 2>/dev/null)" ]; then
                cp -r "${CODEX_DIR}" "${CODEX_DATA_DIR}/codex_dir"
            fi
            rm -rf "${CODEX_DIR}"
        else
            mkdir -p "${CODEX_DATA_DIR}/codex_dir"
        fi
        ln -sf "${CODEX_DATA_DIR}/codex_dir" "${CODEX_DIR}"
    fi
}

setup_codex_persistence_for_user "/home/dev"
chown -R dev:dev /home/dev/.codex_data /home/dev/.codex 2>/dev/null || true

setup_cursor_persistence_for_user() {
    USER_HOME="$1"
    CURSOR_DATA_DIR="${USER_HOME}/.cursor_data"
    CURSOR_DIR="${USER_HOME}/.cursor"
    CURSOR_CONFIG_DIR="${USER_HOME}/.config/cursor"

    mkdir -p "${CURSOR_DATA_DIR}"

    if [ ! -L "${CURSOR_DIR}" ]; then
        if [ -d "${CURSOR_DIR}" ]; then
            if [ ! -d "${CURSOR_DATA_DIR}/cursor_dir" ] || [ -z "$(ls -A "${CURSOR_DATA_DIR}/cursor_dir" 2>/dev/null)" ]; then
                echo "  → First run: copying fresh Cursor CLI to persistent volume"
                cp -r "${CURSOR_DIR}" "${CURSOR_DATA_DIR}/cursor_dir"
            else
                echo "  → Preserving existing Cursor CLI data from persistent volume"
            fi
            rm -rf "${CURSOR_DIR}"
        else
            mkdir -p "${CURSOR_DATA_DIR}/cursor_dir"
        fi
        ln -sf "${CURSOR_DATA_DIR}/cursor_dir" "${CURSOR_DIR}"
    fi

    mkdir -p "${USER_HOME}/.config"
    if [ ! -L "${CURSOR_CONFIG_DIR}" ]; then
        if [ -d "${CURSOR_CONFIG_DIR}" ]; then
            if [ ! -d "${CURSOR_DATA_DIR}/config_cursor" ] || [ -z "$(ls -A "${CURSOR_DATA_DIR}/config_cursor" 2>/dev/null)" ]; then
                echo "  → First run: copying fresh Cursor config to persistent volume"
                cp -r "${CURSOR_CONFIG_DIR}" "${CURSOR_DATA_DIR}/config_cursor"
            else
                echo "  → Preserving existing Cursor config from persistent volume"
            fi
            rm -rf "${CURSOR_CONFIG_DIR}"
        else
            mkdir -p "${CURSOR_DATA_DIR}/config_cursor"
        fi
        ln -sf "${CURSOR_DATA_DIR}/config_cursor" "${CURSOR_CONFIG_DIR}"
    fi
}

setup_cursor_persistence_for_user "/home/dev"
chown -R dev:dev /home/dev/.cursor_data /home/dev/.cursor /home/dev/.config 2>/dev/null || true

setup_gh_persistence_for_user() {
    USER_HOME="$1"
    GH_DATA_DIR="${USER_HOME}/.gh_data"
    GH_CONFIG_DIR="${USER_HOME}/.config/gh"

    mkdir -p "${GH_DATA_DIR}"

    if [ ! -L "${GH_CONFIG_DIR}" ]; then
        mkdir -p "${USER_HOME}/.config"

        if [ -d "${GH_CONFIG_DIR}" ]; then
            if [ ! -d "${GH_DATA_DIR}/gh_dir" ] || [ -z "$(ls -A "${GH_DATA_DIR}/gh_dir" 2>/dev/null)" ]; then
                cp -r "${GH_CONFIG_DIR}" "${GH_DATA_DIR}/gh_dir"
            fi
            rm -rf "${GH_CONFIG_DIR}"
        else
            mkdir -p "${GH_DATA_DIR}/gh_dir"
        fi
        ln -sf "${GH_DATA_DIR}/gh_dir" "${GH_CONFIG_DIR}"
    fi
}

setup_gh_persistence_for_user "/home/dev"
chown -R dev:dev /home/dev/.gh_data /home/dev/.config 2>/dev/null || true

setup_agent_directory_persistence_for_user() {
    DATA_DIR="$1"
    TARGET_DIR="$2"
    mkdir -p "${DATA_DIR}"
    if [ ! -L "${TARGET_DIR}" ]; then
        if [ -d "${TARGET_DIR}" ] && [ -z "$(ls -A "${DATA_DIR}" 2>/dev/null)" ]; then
            cp -a "${TARGET_DIR}/." "${DATA_DIR}/"
        fi
        rm -rf "${TARGET_DIR}"
        mkdir -p "$(dirname "${TARGET_DIR}")"
        ln -s "${DATA_DIR}" "${TARGET_DIR}"
    fi
}

setup_agent_directory_persistence_for_user "/home/dev/.chelper_data/chelper" "/home/dev/.chelper"
setup_agent_directory_persistence_for_user "/home/dev/.opencode_data/config" "/home/dev/.config/opencode"
setup_agent_directory_persistence_for_user "/home/dev/.opencode_data/share" "/home/dev/.local/share/opencode"
setup_agent_directory_persistence_for_user "/home/dev/.pi_data/pi" "/home/dev/.pi"
setup_agent_directory_persistence_for_user "/home/dev/.herdr_data/herdr" "/home/dev/.config/herdr"
setup_agent_directory_persistence_for_user "/home/dev/.grok_data/grok" "/home/dev/.grok"
chown -R dev:dev /home/dev/.chelper_data /home/dev/.cline /home/dev/.opencode_data /home/dev/.pi_data /home/dev/.herdr_data /home/dev/.grok_data 2>/dev/null || true

# Existing herdr_data volumes may predate allow_nested. Patch after the symlink.
ensure_herdr_allow_nested() {
    local cfg="/home/dev/.config/herdr/config.toml"
    mkdir -p "$(dirname "${cfg}")"
    python3 - "${cfg}" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text() if path.exists() else ""
if re.search(r"(?m)^allow_nested\s*=\s*true\s*$", text):
    sys.exit(0)
if re.search(r"(?m)^allow_nested\s*=", text):
    text = re.sub(r"(?m)^allow_nested\s*=\s*\S+", "allow_nested = true", text, count=1)
elif re.search(r"(?m)^\[experimental\]\s*$", text):
    text = re.sub(
        r"(?m)^\[experimental\]\s*$",
        "[experimental]\nallow_nested = true",
        text,
        count=1,
    )
else:
    if text and not text.endswith("\n"):
        text += "\n"
    text += "\n[experimental]\nallow_nested = true\n"
path.write_text(text)
PY
    if [ $? -ne 0 ]; then
        echo "Could not patch herdr allow_nested" >&2
    fi
    chown dev:dev "${cfg}" 2>/dev/null || true
}

ensure_herdr_allow_nested

# Default Herdr panes to the workspace folder. Rewrite [terminal] in place.
ensure_herdr_terminal_defaults() {
    HERDR_CONFIG="/home/dev/.config/herdr/config.toml"
    HERDR_CWD="$(pwd)"
    mkdir -p "$(dirname "${HERDR_CONFIG}")"
    [ -f "${HERDR_CONFIG}" ] || : > "${HERDR_CONFIG}"
    sed -i 's/^shell_mode = "non_login"$/shell_mode = "login"/' "${HERDR_CONFIG}"
    awk -v cwd="${HERDR_CWD}" '
    function keyname(l,  k) { k = l; sub(/[[:space:]]*=.*/, "", k); gsub(/[[:space:]]/, "", k); return k }
    function emit(l) {
        if (l == "") { if (any) pend++; return }
        while (pend > 0) { print ""; pend-- }
        print l; any = 1
    }
    function table(  i) {
        emit("[terminal]")
        if (!("new_cwd" in seen))    emit(sprintf("new_cwd = \"%s\"", cwd))
        if (!("shell_mode" in seen)) emit("shell_mode = \"login\"")
        for (i = 1; i <= n; i++) emit(order[i])
        emit("")
    }
    FNR == NR {
        if ($0 ~ /^\[terminal\]/) { insec = 1; next }
        if ($0 ~ /^\[/)            { insec = 0 }
        if (insec && $0 ~ /^[[:space:]]*[A-Za-z_]+[[:space:]]*=/) {
            k = keyname($0); if (!(k in seen)) { seen[k] = 1; order[++n] = $0 }
        }
        next
    }
    {
        if ($0 ~ /^\[terminal\]/) {
            skip = 1
            if (!done) { table(); done = 1 }
            next
        }
        if ($0 ~ /^\[/) { skip = 0 }
        if (skip) next
        emit($0)
    }
    END { if (!done) { emit(""); table() } }
' "${HERDR_CONFIG}" "${HERDR_CONFIG}" > "${HERDR_CONFIG}.tmp" && mv "${HERDR_CONFIG}.tmp" "${HERDR_CONFIG}"
}
ensure_herdr_terminal_defaults

chown -R dev:dev "/home/dev/.herdr_data" 2>/dev/null || true

# Re-export container env for login/non-login shells (Herdr SSH starts clean).
write_container_env_profile() {
    python3 - "$1" "$2" <<'PY'
import os, pwd, shlex, sys

home, user = sys.argv[1], sys.argv[2]
SKIP = {"PATH", "HOME", "HOSTNAME", "PWD", "OLDPWD", "SHLVL", "SHELL",
        "USER", "LOGNAME", "TERM", "_"}
MARK = "# >>> container env >>>"
SOURCE = (
    '\n%s\n[ -f "$HOME/.container-env.sh" ] && . "$HOME/.container-env.sh"\n'
    '# <<< container env <<<\n' % MARK
)

env_path = os.path.join(home, ".container-env.sh")
lines = ["# Generated by the entrypoint from the container's own environment.",
         "# Do not edit: rewritten on every container start.", ""]
for k, v in sorted(os.environ.items()):
    if k in SKIP or not k or k[0].isdigit() or not k.replace("_", "").isalnum():
        continue
    lines.append("export %s=%s" % (k, shlex.quote(v)))
tmp = env_path + ".tmp"
try:
    os.unlink(tmp)
except FileNotFoundError:
    pass
fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
with os.fdopen(fd, "w") as f:
    f.write("\n".join(lines) + "\n")
os.replace(tmp, env_path)

rcs = []
rc = None
for cand in (".bash_profile", ".bash_login", ".profile"):
    p = os.path.join(home, cand)
    if os.path.exists(p):
        rc = p
        break
if rc is None:
    rc = os.path.join(home, ".profile")
    open(rc, "a").close()
rcs.append(rc)
bashrc = os.path.join(home, ".bashrc")
if os.path.exists(bashrc):
    rcs.append(bashrc)
for path in rcs:
    if MARK not in open(path).read():
        with open(path, "a") as f:
            f.write(SOURCE)

if os.geteuid() == 0:
    try:
        pw = pwd.getpwnam(user)
        for p in [env_path, *rcs]:
            os.chown(p, pw.pw_uid, pw.pw_gid)
    except KeyError:
        pass
PY
}
write_container_env_profile "/home/dev" "dev"

setup_ssh_keys_for_user() {
    USER_HOME="$1"
    SSH_HOST_DIR="${USER_HOME}/.ssh_host"
    SSH_DIR="${USER_HOME}/.ssh"

    if [ -d "${SSH_HOST_DIR}" ]; then
        mkdir -p "${SSH_DIR}"

        KEYS_EXIST=false
        if [ -f "${SSH_DIR}/id_rsa" ] || [ -f "${SSH_DIR}/id_ed25519" ] || [ -f "${SSH_DIR}/id_ecdsa" ]; then
            KEYS_EXIST=true
        fi

        if [ "$KEYS_EXIST" = false ]; then
            echo "Setting up SSH keys from host for ${USER_HOME}..."

            for key_file in "${SSH_HOST_DIR}"/id_*; do
                if [ -f "$key_file" ]; then
                    key_name=$(basename "$key_file")
                    if [[ "$key_name" != *.pub ]]; then
                        cp "$key_file" "${SSH_DIR}/$key_name"
                        chmod 600 "${SSH_DIR}/$key_name"
                        echo "  ✓ Copied $key_name"
                    fi
                fi
            done

            cp "${SSH_HOST_DIR}"/*.pub "${SSH_DIR}/" 2>/dev/null || true

            if [ -f "${SSH_HOST_DIR}/config" ]; then
                cp "${SSH_HOST_DIR}/config" "${SSH_DIR}/config"
                chmod 600 "${SSH_DIR}/config"
                echo "  ✓ Copied SSH config"
            fi

            if [ -f "${SSH_HOST_DIR}/known_hosts" ]; then
                cp "${SSH_HOST_DIR}/known_hosts" "${SSH_DIR}/known_hosts"
                echo "  ✓ Copied known_hosts"
            fi

            echo "SSH keys setup completed for ${USER_HOME}"
        fi

        chmod 700 "${SSH_DIR}" 2>/dev/null || true
        chmod 600 "${SSH_DIR}"/id_* 2>/dev/null || true
        chmod 600 "${SSH_DIR}/config" 2>/dev/null || true
    fi
}

setup_ssh_keys_for_user "/home/dev"
chown -R dev:dev /home/dev/.ssh 2>/dev/null || true

# Herdr peer mesh: one neutral, optional include. When the host provides
# ~/.ssh/config.d/herdr-peers (mounted read-only as ~/.ssh_host), it is
# included; otherwise nothing is added.
install_herdr_peer_mesh() {
  local home="$1"
  local user="$2"
  local ssh_config="${home}/.ssh/config"
  local peers_file=""
  if [ -f "${home}/.ssh_host/config.d/herdr-peers" ]; then
    peers_file="${home}/.ssh_host/config.d/herdr-peers"
  fi
  local include_line=""
  if [ -n "${peers_file}" ]; then
    include_line='Include ~/.ssh_host/config.d/herdr-peers'
  fi
  local src="${home}/.herdr_client_host/endpoints.json"
  local dest_dir="${home}/.local/state/herdr/client"
  local dest="${dest_dir}/endpoints.json"

  if [ -z "${peers_file}" ]; then
    echo "herdr peers: no ~/.ssh/config.d/herdr-peers on the host; skip include"
  elif [ -f "${ssh_config}" ]; then
    if ! grep -qxF "${include_line}" "${ssh_config}"; then
      local tmp
      tmp="$(mktemp)"
      printf '%s\n' "${include_line}" | cat - "${ssh_config}" > "${tmp}"
      mv "${tmp}" "${ssh_config}"
      chown "${user}:${user}" "${ssh_config}" 2>/dev/null || true
      chmod 600 "${ssh_config}" 2>/dev/null || true
    fi
  else
    mkdir -p "${home}/.ssh"
    printf '%s\n' "${include_line}" > "${ssh_config}"
    chown -R "${user}:${user}" "${home}/.ssh" 2>/dev/null || true
    chmod 700 "${home}/.ssh" 2>/dev/null || true
    chmod 600 "${ssh_config}" 2>/dev/null || true
  fi

  mkdir -p "${home}/.local/bin"
  cat > "${home}/.local/bin/herdr-refresh-catalog" <<'EOF'
#!/bin/sh
src="${HOME}/.herdr_client_host/endpoints.json"
dest="${HOME}/.local/state/herdr/client/endpoints.json"
if [ ! -f "$src" ]; then
  echo "herdr peers: catalog missing at $src" >&2
  exit 1
fi
mkdir -p "$(dirname "$dest")"
if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
  exit 0
fi
if [ -f "$dest" ]; then
  cp -p "$dest" "${dest}.bak"
fi
cp -p "$src" "$dest"
chmod 600 "$dest" 2>/dev/null || true
EOF
  chown "${user}:${user}" "${home}/.local/bin/herdr-refresh-catalog"
  chmod 755 "${home}/.local/bin/herdr-refresh-catalog"
  if [ ! -f "${src}" ]; then
    echo "herdr peers: catalog missing at ${src}; skip copy"
  else
    mkdir -p "${dest_dir}"
    if [ -f "${dest}" ]; then
      cp -p "${dest}" "${dest}.bak"
    fi
    cp -p "${src}" "${dest}"
    chown -R "${user}:${user}" "${dest_dir}" 2>/dev/null || true
    chmod 600 "${dest}" 2>/dev/null || true
  fi

  # Trust ED25519 host keys for peer ports (Herdr requires ed25519).
  if [ -n "${peers_file}" ]; then
    local known="${home}/.ssh/known_hosts"
    touch "${known}"
    chown "${user}:${user}" "${known}" 2>/dev/null || true
    awk '
      /^Host / { host=$2; port="" }
      /^[[:space:]]*Port / && host != "" { port=$2 }
      host != "" && port != "" {
        printf "%s %s\n", host, port
        host=""; port=""
      }
    ' "${peers_file}" | while read -r peer_host peer_port; do
      case "${peer_port}" in
        ''|*[!0-9]*) continue ;;
        2202[2-9]|2203[0-9]|22[4-9][0-9][0-9]) ;;
        *) continue ;;
      esac
      if su -s /bin/bash "${user}" -c "ssh-keygen -F \"[host.docker.internal]:${peer_port}\" -f \"${known}\" 2>/dev/null | grep -q ssh-ed25519"; then
        continue
      fi
      su -s /bin/bash "${user}" -c "ssh-keyscan -T 4 -t ed25519 -p ${peer_port} host.docker.internal 2>/dev/null | grep -v '^#' >> \"${known}\"" \
        || su -s /bin/bash "${user}" -c "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o HostKeyAlgorithms=ssh-ed25519 -o ConnectTimeout=4 -o PreferredAuthentications=publickey -p ${peer_port} host.docker.internal true" >/dev/null 2>&1 \
        || true
    done
    chmod 600 "${known}" 2>/dev/null || true
  fi
}

install_herdr_peer_mesh "/home/dev" "dev"

if [ -f /workspace/dev.sh ]; then
  if [ "$(id -u)" = "0" ]; then
    ln -sfn /workspace/dev.sh /usr/local/bin/dev.sh
  else
    sudo ln -sfn /workspace/dev.sh /usr/local/bin/dev.sh
  fi
  chmod 755 /workspace/dev.sh 2>/dev/null || true
fi

# This image develops DeepWorkPlan Vim: the repo IS the Neovim config.
mkdir -p /home/dev/.config
# The image bakes the release config into ~/.config/nvim (the installer's
# standalone fallback); with /workspace mounted it is replaced by the link.
if [ -d /workspace ] && [ ! -L /home/dev/.config/nvim ]; then
  rm -rf /home/dev/.config/nvim 2>/dev/null || true
  ln -sfn /workspace /home/dev/.config/nvim
  chown -h dev:dev /home/dev/.config/nvim 2>/dev/null || true
fi

setup_sshd_authorized_keys_for_user() {
    USER_HOME="$1"
    SSH_HOST_DIR="${USER_HOME}/.ssh_host"
    SSH_DIR="${USER_HOME}/.ssh"

    if [ ! -d "${SSH_HOST_DIR}" ]; then
        echo "Host SSH directory not mounted; skipping sshd authorized_keys"
        return
    fi

    mkdir -p "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"
    : > "${SSH_DIR}/authorized_keys"
    for pub in "${SSH_HOST_DIR}"/*.pub; do
        if [ -f "${pub}" ]; then
            cat "${pub}" >> "${SSH_DIR}/authorized_keys"
        fi
    done
    chmod 600 "${SSH_DIR}/authorized_keys"
    chown -R dev:dev "${SSH_DIR}"
}

start_sshd() {
    mkdir -p /var/run/sshd

    if [ "$(id -u)" = "0" ]; then SSH_SUDO=""; else SSH_SUDO="sudo"; fi
    HOST_KEY_DIR="/home/dev/.herdr_data/ssh_host_keys"
    ${SSH_SUDO} mkdir -p "${HOST_KEY_DIR}"
    for key_type in rsa ecdsa ed25519; do
        if ! ${SSH_SUDO} test -f "${HOST_KEY_DIR}/ssh_host_${key_type}_key"; then
            echo "Generating a persistent SSH host key (${key_type})..."
            ${SSH_SUDO} ssh-keygen -q -t "${key_type}" -N '' -f "${HOST_KEY_DIR}/ssh_host_${key_type}_key"
        fi
    done
    ${SSH_SUDO} chown root:root "${HOST_KEY_DIR}" "${HOST_KEY_DIR}"/ssh_host_*
    ${SSH_SUDO} chmod 700 "${HOST_KEY_DIR}"
    ${SSH_SUDO} chmod 600 "${HOST_KEY_DIR}"/ssh_host_*_key
    ${SSH_SUDO} chmod 644 "${HOST_KEY_DIR}"/ssh_host_*_key.pub
    printf 'HostKey %s/ssh_host_rsa_key\nHostKey %s/ssh_host_ecdsa_key\nHostKey %s/ssh_host_ed25519_key\n' \
        "${HOST_KEY_DIR}" "${HOST_KEY_DIR}" "${HOST_KEY_DIR}" \
        | ${SSH_SUDO} tee /etc/ssh/sshd_config.d/00-persistent-host-keys.conf >/dev/null
    if /usr/sbin/sshd -t; then
        /usr/sbin/sshd
        echo "sshd started for Herdr remote access"
    else
        echo "sshd config invalid; not starting sshd" >&2
    fi
}

setup_sshd_authorized_keys_for_user "/home/dev"

setup_nodejs() {
    mkdir -p /home/dev/.local/share/pnpm
    chown -R dev:dev /home/dev/.local/share/pnpm 2>/dev/null || true
}

setup_git() {
    if [ -f "/home/dev/.gitconfig" ]; then
        echo "Git configuration found and mounted from host"
    else
        echo "Using default Git configuration from Dockerfile"
    fi

    if [ "$(id -u)" = "0" ]; then
        git config --system --get-all safe.directory 2>/dev/null | grep -qx '\*' \
            || git config --system --add safe.directory '*'
    else
        sudo git config --system --get-all safe.directory 2>/dev/null | grep -qx '\*' \
            || sudo git config --system --add safe.directory '*'
    fi
}

main() {
    echo "Starting container setup..."

    setup_nodejs
    setup_git

    echo "Container setup completed"

    start_sshd

    exec "$@"
}

main "$@"
