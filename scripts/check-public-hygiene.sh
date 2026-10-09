#!/usr/bin/env bash
# Public-hygiene check — this repository is public, so tracked files must
# not carry private context or secrets (DeepWorkPlan ecosystem standard A3,
# S3). Offline: bash + git + grep only.
#
# Scans every tracked regular file except the vendored, pinned skill copies
# under .agents/skills/ and the allowlist itself (symlinks and binary files
# are skipped) and fails on:
#   personal-path    /Users/<name>, /home/<name>, C:\Users\<name>
#   private-org      the private GitHub organization name
#   private-repo     names of private repositories
#   internal-name    internal tooling and mesh names
#   private-email    @dailybot.com addresses other than the public aliases
#   secret-*         credential-shaped strings (values are never printed)
#
# Exceptions live in .public-hygiene-allow, one per line:
#   <path-glob> | <literal the hit line contains> | <reason>
# Every entry needs a reason and must match at least one hit (stale entries
# fail). An entry covering a secret-* hit must name an obviously fake value:
# the hit line has to contain "fake", "test", "planted" or "example".
#
# Names below are written with one bracketed character (d[b]dev) so this
# file never matches its own rules and is scanned like any other file.
#
# Usage: scripts/check-public-hygiene.sh [repo-root]
# Exit: 0 clean, 1 findings, 2 usage or allowlist error.
set -euo pipefail

root="${1:-$(git rev-parse --show-toplevel)}"
cd "$root"
allow_file=".public-hygiene-allow"

# Word boundary that also treats "-" as part of a name.
b_l='(^|[^A-Za-z0-9_-])'
b_r='([^A-Za-z0-9_-]|$)'

# id|case(i/s)|ERE
rules=(
	"personal-path|s|(^|[^A-Za-z0-9_.~$}])/(U[s]ers|h[o]me)/[A-Za-z0-9._-]+"
	"personal-path|i|[A-Za-z]:\\\\U[s]ers\\\\[A-Za-z0-9._-]+"
	"private-org|i|${b_l}d[a]ilybot-inc${b_r}"
	"private-repo|i|${b_l}(d[a]ilybot-core|coding-agent-host-k[i]t|d[a]ilybot-private-skills|api-servi[c]es|chatbot-functi[o]ns|discord-gatew[a]y|msteams-app-manifest[o]|labs-proj[e]cts)${b_r}"
	"internal-name|i|${b_l}(d[b]dev|d[a]ilybot-dev|d[a]ilybot-peers|d[a]ilybot-workspaces)${b_r}"
	"internal-name|i|d[a]ilybot-ws-|\\[d[a]ilybot-mesh\\]"
	"private-email|i|[A-Za-z0-9._%+-]+@d[a]ilybot\\.com"
	"secret-aws|s|(A[K]IA|A[S]IA)[0-9A-Z]{16}"
	"secret-github|s|gh[pousr]_[A-Za-z0-9]{36}|g[i]thub_pat_[A-Za-z0-9_]{22,}"
	"secret-llm|s|s[k]-[A-Za-z0-9_-]{20,}"
	"secret-slack|s|x[o]x[abprs]-[A-Za-z0-9-]{10,}|hooks\\.s[l]ack\\.com/services/T[A-Z0-9]+"
	"secret-google|s|A[I]za[0-9A-Za-z_-]{35}"
	"secret-private-key|s|-----B[E]GIN ([A-Z0-9]+ )*PRIVATE KEY-----"
	"secret-assignment|i|(api[_-]?key|secret|token|passw(or)?d|credentials?)[A-Za-z0-9_-]*[\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"'[:space:]]{16,}[\"']"
)
public_aliases='^(security|support|ops|conduct)@'

# --- allowlist ---------------------------------------------------------------
allow_globs=()
allow_lits=()
allow_used=()
if [ -f "$allow_file" ]; then
	n=0
	while IFS= read -r line || [ -n "$line" ]; do
		n=$((n + 1))
		case "$line" in '' | '#'*) continue ;; esac
		glob="${line%%|*}"
		rest="${line#*|}"
		lit="${rest%%|*}"
		reason="${rest#*|}"
		# trim
		glob="$(printf '%s' "$glob" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		lit="$(printf '%s' "$lit" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		reason="$(printf '%s' "$reason" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		if [ "$rest" = "$line" ] || [ "$reason" = "$rest" ] || [ -z "$glob" ] || [ -z "$lit" ] || [ -z "$reason" ]; then
			echo "$allow_file:$n: malformed entry (need: path-glob | literal | reason)" >&2
			exit 2
		fi
		allow_globs+=("$glob")
		allow_lits+=("$lit")
		allow_used+=(0)
	done <"$allow_file"
fi

# --- file list -----------------------------------------------------------------
files=()
while IFS= read -r -d '' f; do
	case "$f" in .agents/skills/* | "$allow_file") continue ;; esac
	[ -f "$f" ] && [ ! -L "$f" ] || continue
	files+=("$f")
done < <(git ls-files -z)

findings=0
report() { # rule file lineno text
	findings=$((findings + 1))
	case "$1" in
	secret-*) echo "$2:$3: [$1] (value redacted)" ;;
	*) printf '%s:%s: [%s] %s\n' "$2" "$3" "$1" "$(printf '%s' "$4" | cut -c1-160)" ;;
	esac
}

allowed() { # rule file text -> 0 when an entry covers it (marks it used)
	local i
	for i in "${!allow_globs[@]}"; do
		# shellcheck disable=SC2053 # glob match is intended
		if [[ "$2" == ${allow_globs[$i]} ]] && [[ "$3" == *"${allow_lits[$i]}"* ]]; then
			case "$1" in
			secret-*)
				if ! printf '%s' "$3" | grep -qiE 'fake|test|planted|example'; then
					echo "$2: [$1] allow entry ${allow_globs[$i]} | ${allow_lits[$i]} covers a value that is not obviously fake" >&2
					return 1
				fi
				;;
			esac
			allow_used[i]=1
			return 0
		fi
	done
	return 1
}

if [ "${#files[@]}" -gt 0 ]; then
	for entry in "${rules[@]}"; do
		id="${entry%%|*}"
		rest="${entry#*|}"
		mode="${rest%%|*}"
		re="${rest#*|}"
		flags=(-nIE)
		[ "$mode" = i ] && flags=(-niIE)
		while IFS= read -r hit; do
			file="${hit%%:*}"
			rest_hit="${hit#*:}"
			lineno="${rest_hit%%:*}"
			text="${rest_hit#*:}"
			if [ "$id" = private-email ]; then
				bad=0
				while IFS= read -r addr; do
					printf '%s' "$addr" | grep -qiE "$public_aliases" || bad=1
				done < <(printf '%s\n' "$text" | grep -oiE "$re")
				[ "$bad" -eq 1 ] || continue
			fi
			allowed "$id" "$file" "$text" && continue
			report "$id" "$file" "$lineno" "$text"
		done < <(printf '%s\0' "${files[@]}" | xargs -0 grep "${flags[@]}" -- "$re" /dev/null 2>/dev/null || true)
	done
fi

stale=0
for i in "${!allow_globs[@]}"; do
	if [ "${allow_used[$i]}" -eq 0 ]; then
		echo "$allow_file: stale entry (matches nothing): ${allow_globs[$i]} | ${allow_lits[$i]}" >&2
		stale=1
	fi
done

if [ "$findings" -gt 0 ]; then
	echo "public-hygiene: $findings finding(s) in ${#files[@]} files — fix them, or allow a deliberate one in $allow_file with a reason" >&2
	exit 1
fi
if [ "$stale" -ne 0 ]; then
	exit 2
fi
echo "public-hygiene: OK (${#files[@]} tracked files, ${#allow_globs[@]} allow entries)"
