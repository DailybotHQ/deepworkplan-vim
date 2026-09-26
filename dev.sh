#!/usr/bin/env bash
# Public local-dev launcher for deepworkplan-vim.
# Supports Herdr mesh list/ask. Optional thin docker helpers. No private host kit required.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${ROOT}/docker/local/docker-compose.yaml"
COMPOSE_DIR="${ROOT}/docker/local"
HERDR_MESH_STAMP="[herdr-mesh]"
HERDR_WORKSPACE_PEERS_REL="config.d/herdr-workspace-peers"

die() { printf '%s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
dev.sh — local-dev helpers for deepworkplan-vim (public OSS).

  bash dev.sh agents                 list live Herdr machines and agents
  bash dev.sh ask <#> "Prompt..."    send a prompt with reply grant
  bash dev.sh ask <machine-id> <pane> "Prompt..."
  bash dev.sh up                     start compose service (detached)
  bash dev.sh down                   stop compose service
  bash dev.sh shell                  shell as remoteUser (dev) in /workspace
  bash dev.sh build                  build image (cache on)
  bash dev.sh rebuild                rebuild image and recreate
  bash dev.sh help                   this text

Selective coding CLIs (build args, default false):
  INSTALL_CLAUDE_CLI INSTALL_CURSOR_CLI INSTALL_CODEX_CLI
  INSTALL_PI_CLI INSTALL_OPENCODE_CLI INSTALL_CLINE_CLI INSTALL_GROK_CLI

  docker compose -f docker/local/docker-compose.yaml build \
    --build-arg INSTALL_CLAUDE_CLI=true --build-arg INSTALL_CODEX_CLI=true

Herdr SSH host port defaults to 127.0.0.1:22035 (override HERDR_SSH_HOST_PORT).
Default editor is Neovim 0.12.5. The repo is mounted as ~/.config/nvim.
USAGE
}

ensure_env_from_examples() {
  local f target
  [ -d "$COMPOSE_DIR" ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    target="${f%.example}"
    if [ ! -f "$target" ]; then
      if ! (umask 077 && : > "$target"); then
        die "could not create $target"
      fi
      cat "$f" > "$target"
      printf 'created %s from %s (0600)\n' "${target#"$ROOT"/}" "${f#"$ROOT"/}"
    fi
  done < <(find "$COMPOSE_DIR" -type f -name '.env*.example' 2>/dev/null | sort)
}

compose() {
  ensure_env_from_examples
  local env_file="${COMPOSE_DIR}/dwpvim/.env"
  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
  fi
  docker compose -f "$COMPOSE_FILE" "$@"
}

herdr_peer_sources() {
  local f
  for f in \
    "${HOME}/.ssh_host/config.d/herdr-peers" \
    "${HOME}/.ssh/config.d/herdr-peers" \
    "${HOME}/.ssh_host/config.d/dailybot-peers" \
    "${HOME}/.ssh/${HERDR_WORKSPACE_PEERS_REL}" \
    "${HOME}/.ssh/config.d/herdr-workspace-peers"
  do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
}

herdr_trust_peer_keys() {
  local known="${HOME}/.ssh/known_hosts"
  local sources=()
  local line
  while IFS= read -r line; do
    [ -n "$line" ] && sources+=("$line")
  done < <(herdr_peer_sources)
  [ "${#sources[@]}" -gt 0 ] || return 0
  mkdir -p "$(dirname "$known")"
  touch "$known"
  awk '
    /^Host / { host=$2; port="" }
    /^[[:space:]]*Port / && host != "" { port=$2 }
    host != "" && port != "" {
      printf "%s %s\n", host, port
      host=""; port=""
    }
  ' "${sources[@]}" | while read -r peer_host peer_port; do
    case "${peer_port}" in
      ''|*[!0-9]*) continue ;;
      2202[2-9]|2203[0-9]|22[4-9][0-9][0-9]) ;;
      *) continue ;;
    esac
    if ssh-keygen -F "[host.docker.internal]:${peer_port}" -f "$known" 2>/dev/null \
      | grep -q 'ssh-ed25519'; then
      continue
    fi
    if ! ssh-keyscan -T 4 -t ed25519 -p "${peer_port}" host.docker.internal 2>/dev/null \
      | grep -v '^#' >>"$known"; then
      ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
        -o HostKeyAlgorithms=ssh-ed25519 -o ConnectTimeout=4 \
        -o PreferredAuthentications=publickey -p "${peer_port}" \
        host.docker.internal true >/dev/null 2>&1 || true
    fi
  done
  return 0
}

herdr_sync_workspace_peers() {
  local src=""
  local candidate
  for candidate in \
    "${HOME}/.ssh_host/config.d/herdr-workspaces" \
    "${HOME}/.ssh_host/config.d/dailybot-workspaces"
  do
    if [ -f "$candidate" ]; then src="$candidate"; break; fi
  done
  local dest="${HOME}/.ssh/${HERDR_WORKSPACE_PEERS_REL}"
  local ssh_config="${HOME}/.ssh/config"
  local include_line="Include ~/.ssh/${HERDR_WORKSPACE_PEERS_REL}"
  [ -n "$src" ] || return 0
  mkdir -p "$(dirname "$dest")"
  local tmp
  tmp="$(mktemp "${dest}.XXXXXX")"
  awk '
    function flush() {
      if (host != "" && port != "" && user != "") {
        printf "Host %s\n  HostName host.docker.internal\n  Port %s\n  User %s\n  StrictHostKeyChecking accept-new\n\n", host, port, user
      }
      host=""; port=""; user=""
    }
    BEGIN { print "# Generated from host workspace peers. Do not edit.\n" }
    /^Host / { flush(); if ($2 ~ /^[A-Za-z0-9._-]+$/ && NF == 2) host=$2; next }
    /^[[:space:]]*Port / { if ($2 ~ /^22[4-9][0-9][0-9]$/) port=$2; next }
    /^[[:space:]]*User / { if ($2 ~ /^[a-z_][a-z0-9_-]*$/) user=$2; next }
    END { flush() }
  ' "$src" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$dest"
  touch "$ssh_config"
  if ! grep -qxF "$include_line" "$ssh_config"; then
    tmp="$(mktemp "${ssh_config}.XXXXXX")"
    printf '%s\n' "$include_line" | cat - "$ssh_config" > "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$ssh_config"
  fi
}

herdr_prepare_mesh() {
  local refresh="${HOME}/.local/bin/herdr-refresh-catalog"
  local src="${HOME}/.herdr_client_host/endpoints.json"
  if [ -x "$refresh" ]; then
    if [ -f "$src" ]; then
      "$refresh" || die "could not refresh the Herdr catalog from the host mount"
    fi
  elif [ -f "$src" ]; then
    die "catalog mount is present but ${refresh} is missing; restart this container once so the entrypoint installs it"
  fi
  herdr_sync_workspace_peers
  herdr_trust_peer_keys
}

cmd_agents() {
  command -v herdr >/dev/null 2>&1 || die "herdr is not on PATH (run inside the dev container, or install herdr)"
  command -v python3 >/dev/null 2>&1 || die "python3 is required to read the catalog"
  herdr_prepare_mesh
  python3 - <<'PY'
import json, os, subprocess, sys

def machines():
    try:
        raw = subprocess.run(
            ["herdr", "machine", "list", "--json"],
            capture_output=True, text=True, timeout=12,
        )
    except subprocess.TimeoutExpired:
        sys.stderr.write("herdr machine list timed out\n")
        sys.exit(1)
    if raw.returncode != 0:
        sys.stderr.write(raw.stderr or "herdr machine list failed\n")
        sys.exit(raw.returncode or 1)
    try:
        data = json.loads(raw.stdout or "[]")
    except json.JSONDecodeError:
        sys.stderr.write("herdr machine list did not return JSON\n")
        sys.exit(1)
    if not isinstance(data, list):
        sys.stderr.write("herdr machine list JSON was not a list\n")
        sys.exit(1)
    return [m for m in data if isinstance(m, dict)]

def agents_for(machine_id):
    try:
        raw = subprocess.run(
            ["herdr", "--machine", machine_id, "agent", "list"],
            capture_output=True, text=True, timeout=12,
        )
    except subprocess.TimeoutExpired:
        return None, ["timed out"]
    if raw.returncode != 0 or not raw.stdout.strip():
        return None, (raw.stderr or "no answer").strip().splitlines()[-1:] or ["no answer"]
    try:
        payload = json.loads(raw.stdout)
    except json.JSONDecodeError:
        return None, ["agent list was not JSON"]
    result = payload.get("result") if isinstance(payload, dict) else None
    found = result.get("agents") if isinstance(result, dict) else None
    if not isinstance(found, list):
        return None, ["agent list had no agents array"]
    return found, None

def current_pane():
    try:
        raw = subprocess.run(
            ["herdr", "pane", "current"],
            capture_output=True, text=True, timeout=8,
        )
    except subprocess.TimeoutExpired:
        return "", ""
    if raw.returncode != 0 or not raw.stdout.strip():
        return "", ""
    try:
        pane = ((json.loads(raw.stdout).get("result") or {}).get("pane") or {})
    except json.JSONDecodeError:
        return "", ""
    return str(pane.get("pane_id") or ""), str(pane.get("terminal_id") or "")

self_pane, self_terminal = current_pane()
self_machine = ""

rows = []
for machine in machines():
    if not machine.get("enabled"):
        continue
    label = str(machine.get("label") or "").replace("\t", " ")
    mid = str(machine.get("id") or "")
    if not mid:
        continue
    found, err = agents_for(mid)
    if err is not None:
        rows.append((label, mid, "-", "-", "unreachable", "", ""))
        continue
    if not found:
        rows.append((label, mid, "-", "-", "no agents", "", ""))
        continue
    for agent in found:
        if not isinstance(agent, dict):
            continue
        pane_id = str(agent.get("pane_id") or "-")
        terminal_id = str(agent.get("terminal_id") or "")
        if (
            not self_machine
            and self_pane
            and pane_id == self_pane
            and (not self_terminal or terminal_id == self_terminal)
        ):
            self_machine = mid
        rows.append((
            label,
            mid,
            str(agent.get("agent") or "-"),
            pane_id,
            str(agent.get("agent_status") or "-"),
            str(agent.get("terminal_title_stripped") or "").replace("\n", " "),
            terminal_id,
        ))

def clean(label):
    text = label.strip()
    if len(text) > 3 and text[0].isdigit() and " - " in text[:6]:
        text = text.split(" - ", 1)[1]
    return text

def paint(code, text):
    if not sys.stdout.isatty() or os.environ.get("NO_COLOR"):
        return text
    return "\033[%sm%s\033[0m" % (code, text)

state_color = {
    "idle": "32",
    "running": "33",
    "no agents": "90",
    "unreachable": "31",
}

print("")
print("  #  MACHINE            ID        AGENT           PANE     STATE         TITLE")
print("  -- ------------------ --------- --------------- -------- ------------- ------------------------------")
n = 0
example = None
for label, mid, agent, pane, state, title, _tid in rows:
    you = ""
    if self_pane and pane == self_pane and mid == self_machine:
        you = " <- you"
    num = "-"
    if pane and pane != "-":
        n += 1
        num = str(n)
        if example is None:
            example = (num, mid, pane)
    state_txt = paint(state_color.get(state, "0"), state)
    if sys.stdout.isatty() and not os.environ.get("NO_COLOR"):
        line = "  %-2s %-18s %-9s %-15s %-8s %s %s%s" % (
            num,
            clean(label)[:18],
            mid[:9],
            agent[:15],
            pane[:8],
            state_txt + (" " * max(0, 13 - len(state))),
            (title[:30] + you),
            "",
        )
    else:
        line = "  %-2s %-18s %-9s %-15s %-8s %-13s %s%s" % (
            num,
            clean(label)[:18],
            mid[:9],
            agent[:15],
            pane[:8],
            state,
            (title[:30] + you),
            "",
        )
    print(line)

if self_pane:
    print("")
    print("  you are on pane %s" % self_pane)
print("")
print("  bash dev.sh ask <#> \"Prompt...\"")
print("  bash dev.sh ask <machine id> <pane> \"Prompt...\"")
if example:
    print("  bash dev.sh ask %s \"Prompt...\"" % example[0])
print("")
PY
}

cmd_ask() {
  local from_machine="" from_pane=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --from)
        [ $# -ge 3 ] || die "ask --from needs <machine-id> <pane>"
        from_machine="$2"
        from_pane="$3"
        shift 3
        ;;
      --)
        shift
        break
        ;;
      -*)
        die "unknown ask flag '$1'"
        ;;
      *)
        break
        ;;
    esac
  done
  local machine="" pane="" number=""
  if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    number="$1"
    shift
  else
    [ $# -ge 3 ] || die "ask needs <#> \"prompt\", or <machine-id> <pane> \"prompt\""
    machine="$1"
    pane="$2"
    shift 2
  fi
  [ $# -ge 1 ] || die "ask needs a prompt"
  local text="$*"
  [ -n "$text" ] || die "ask needs a prompt"
  herdr_prepare_mesh
  if [ -n "$number" ]; then
    local resolved
    resolved="$(HERDR_ASK_NUMBER="$number" python3 - <<'PY'
import json, os, subprocess, sys
want = int(os.environ["HERDR_ASK_NUMBER"])
raw = subprocess.run(["herdr", "machine", "list", "--json"], capture_output=True, text=True, timeout=12)
if raw.returncode != 0:
    sys.stderr.write(raw.stderr or "herdr machine list failed\n")
    sys.exit(1)
machines = json.loads(raw.stdout or "[]")
n = 0
for machine in machines if isinstance(machines, list) else []:
    if not isinstance(machine, dict) or not machine.get("enabled") or not machine.get("id"):
        continue
    listed = subprocess.run(["herdr", "--machine", str(machine["id"]), "agent", "list"], capture_output=True, text=True, timeout=12)
    if listed.returncode != 0 or not listed.stdout.strip():
        continue
    try:
        payload = json.loads(listed.stdout)
    except json.JSONDecodeError:
        continue
    agents = ((payload.get("result") or {}).get("agents") if isinstance(payload, dict) else None) or []
    if not isinstance(agents, list):
        continue
    for agent in agents:
        if not isinstance(agent, dict) or not agent.get("pane_id"):
            continue
        n += 1
        if n == want:
            print("%s %s" % (machine["id"], agent["pane_id"]))
            sys.exit(0)
sys.stderr.write("no agent #%s in the current list; run: bash dev.sh agents\n" % want)
sys.exit(1)
PY
)" || die "could not resolve agent #$number"
    machine="${resolved%% *}"
    pane="${resolved##* }"
  fi
  case "$machine" in
    ""|*[!0-9a-fA-F]*) die "machine id must be the hex id from: bash dev.sh agents" ;;
  esac
  case "$pane" in
    w*:p*) ;;
    *) die "pane must look like w5:p2 (the PANE column from: bash dev.sh agents)" ;;
  esac
  case "$from_pane" in
    ""|w*:p*) ;;
    *) die "--from pane must look like w5:p2" ;;
  esac
  case "$from_machine" in
    ""|*[!0-9a-fA-F]*)
      [ -z "$from_machine" ] || die "--from machine id must be hex"
      ;;
  esac

  command -v herdr >/dev/null 2>&1 || die "herdr is not on PATH"
  command -v python3 >/dev/null 2>&1 || die "python3 is required"

  HERDR_ASK_MACHINE="$machine" \
  HERDR_ASK_PANE="$pane" \
  HERDR_ASK_TEXT="$text" \
  HERDR_ASK_FROM_MACHINE="$from_machine" \
  HERDR_ASK_FROM_PANE="$from_pane" \
  HERDR_MESH_STAMP="$HERDR_MESH_STAMP" \
  python3 - <<'PY'
import json, os, subprocess, sys

machine = os.environ["HERDR_ASK_MACHINE"]
pane = os.environ["HERDR_ASK_PANE"]
text = os.environ["HERDR_ASK_TEXT"]
from_machine = os.environ.get("HERDR_ASK_FROM_MACHINE") or ""
from_pane = os.environ.get("HERDR_ASK_FROM_PANE") or ""
stamp_tag = os.environ.get("HERDR_MESH_STAMP") or "[herdr-mesh]"

def run(args, timeout):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        sys.stderr.write("herdr timed out: %s\n" % " ".join(args[:4]))
        sys.exit(1)

def pane_here(pane_id):
    raw = run(["herdr", "pane", "get", pane_id], 8)
    if raw.returncode != 0:
        return False
    try:
        payload = json.loads(raw.stdout or "{}")
    except json.JSONDecodeError:
        return False
    found = ((payload.get("result") or {}).get("pane") or {}).get("pane_id")
    return found == pane_id

def enabled_ids():
    raw = run(["herdr", "machine", "list", "--json"], 12)
    if raw.returncode != 0:
        sys.stderr.write(raw.stderr or "herdr machine list failed\n")
        sys.exit(raw.returncode or 1)
    try:
        data = json.loads(raw.stdout or "[]")
    except json.JSONDecodeError:
        sys.stderr.write("herdr machine list did not return JSON\n")
        sys.exit(1)
    ids = []
    for item in data if isinstance(data, list) else []:
        if isinstance(item, dict) and item.get("enabled") and item.get("id"):
            ids.append(str(item["id"]))
    return ids

if not from_machine or not from_pane:
    current = run(["herdr", "pane", "current"], 8)
    if current.returncode != 0:
        sys.stderr.write("could not read the current pane; pass --from <machine-id> <pane>\n")
        sys.exit(1)
    try:
        from_pane = str(((json.loads(current.stdout).get("result") or {}).get("pane") or {}).get("pane_id") or "")
    except json.JSONDecodeError:
        from_pane = ""
    if not from_pane:
        sys.stderr.write("this session has no pane id; pass --from <machine-id> <pane>\n")
        sys.exit(1)
    for candidate in enabled_ids():
        probe = run(["herdr", "--machine", candidate, "pane", "get", from_pane], 8)
        if probe.returncode != 0:
            continue
        try:
            found = ((json.loads(probe.stdout or "{}").get("result") or {}).get("pane") or {}).get("pane_id")
        except json.JSONDecodeError:
            continue
        if found == from_pane:
            from_machine = candidate
            break
    if not from_machine:
        sys.stderr.write(
            "this session is not on a reachable Herdr machine, so a reply cannot come back here.\n"
            "Run ask from inside a container, or pass --from <machine-id> <pane>\n"
            "of a pane that bash dev.sh agents lists.\n"
        )
        sys.exit(1)

if from_machine == machine and from_pane == pane:
    sys.stderr.write("refusing to ask a pane to reply to itself\n")
    sys.exit(1)

if not pane_here(pane) and machine not in enabled_ids():
    sys.stderr.write("machine %s is not an enabled Herdr machine\n" % machine)
    sys.exit(1)

if stamp_tag in text:
    stamp = (
        "%s This is the reply. Do not answer it.\n"
        "The conversation stops here."
    ) % stamp_tag
else:
    stamp = (
        "%s You are authorized to reply to this message. You must reply now.\n"
        "Send the reply yourself with the command below. Do not ask a person for permission.\n"
        "Do not draft the answer and wait. Do not stop after writing it in this pane.\n"
        "You already have permission to run that command. Nobody else needs to approve it.\n"
        "Keep the %s stamp in the command, so your answer is marked as a reply and the conversation stops.\n"
        "Reply with: bash dev.sh ask %s %s \"%s your answer\"\n"
        "Or: herdr --machine %s agent prompt %s \"%s your answer\""
    ) % (
        stamp_tag, stamp_tag,
        from_machine, from_pane, stamp_tag,
        from_machine, from_pane, stamp_tag,
    )
body = text.rstrip() + "\n\n" + stamp

sent = run(["herdr", "--machine", machine, "agent", "prompt", pane, body], 20)
sys.stdout.write(sent.stdout or "")
sys.stderr.write(sent.stderr or "")
if sent.returncode != 0:
    sys.exit(sent.returncode)
print("asked %s %s" % (machine, pane))
print("reply address: bash dev.sh ask %s %s \"...\"" % (from_machine, from_pane))
PY
}

cmd_up() { compose up -d "$@"; }
cmd_down() { compose down "$@"; }
cmd_shell() {
  compose exec -u dev dwpvim bash -l
}
cmd_build() { compose build "$@"; }
cmd_rebuild() {
  compose build "$@"
  compose up -d --force-recreate "$@"
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "$cmd" in
    agents) cmd_agents "$@" ;;
    ask) cmd_ask "$@" ;;
    up) cmd_up "$@" ;;
    down) cmd_down "$@" ;;
    shell) cmd_shell "$@" ;;
    build) cmd_build "$@" ;;
    rebuild) cmd_rebuild "$@" ;;
    help|-h|--help) usage ;;
    *) die "unknown command: $cmd (try: bash dev.sh help)" ;;
  esac
}

main "$@"
