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
#   pipe-to-shell    a download run by a shell, in code or prose — the common
#                    forms: piped into (ba|z|da|k)sh (path-qualified, via
#                    sudo/env, after intermediate pipes), a shell reading
#                    `<(<download>)`, `sh -c` or `eval` of `$(<download>)`,
#                    and a PowerShell download piped into iex.
#                    Installers are taught as download -> verify -> run
#                    (supply-chain rules E005/W012).
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
	'pipe-to-shell|i|(c[u]rl|w[g]et)[^|]*([|][^|]*)*[|][[:space:]]*([A-Za-z_]+=[^[:space:]]*[[:space:]]+)*(sudo([[:space:]]+-[A-Za-z]+)*[[:space:]]+)?((/[^[:space:]|]*/)?env[[:space:]]+[^|]*)?(/[^[:space:]|]*/)?(ba|z|da|k)?sh([^A-Za-z0-9_]|$)'
	'pipe-to-shell|i|(source|[.]|(ba|z|da|k)?sh)[[:space:]]+<[(][[:space:]]*(c[u]rl|w[g]et)'
	'pipe-to-shell|i|(-c|eval)[[:space:]]+["'"'"']?[$][(][[:space:]]*(c[u]rl|w[g]et)'
	"pipe-to-shell|i|(i[w]r|i[r]m|invoke-webrequest|invoke-restmethod)[^|]*[|][[:space:]]*(i[e]x|invoke-expression)"
	"secret-aws|s|(A[K]IA|A[S]IA)[0-9A-Z]{16}"
	"secret-github|s|gh[pousr]_[A-Za-z0-9]{36}|g[i]thub_pat_[A-Za-z0-9_]{22,}"
	"secret-llm|s|(^|[^A-Za-z0-9_-])(s[k]-[A-Za-z0-9_-]{20,}|x[a]i-[A-Za-z0-9]{20,})"
	"secret-vendor|s|n[p]m_[A-Za-z0-9]{36}|g[l]pat-[A-Za-z0-9_-]{20,}|[sr]k_l[i]ve_[A-Za-z0-9]{20,}|h[f]_[A-Za-z0-9]{30,}"
	"secret-slack|s|x[o]x[abeprs]-[A-Za-z0-9-]{10,}|hooks\\.s[l]ack\\.com/services/T[A-Z0-9]+"
	"secret-google|s|A[I]za[0-9A-Za-z_-]{35}"
	"secret-jwt|s|e[y]J[A-Za-z0-9_-]{10,}\\.e[y]J[A-Za-z0-9_-]{10,}"
	"secret-bearer|i|b[e]arer[[:space:]]+[A-Za-z0-9._~+/-]{20,}"
	"secret-private-key|s|-----B[E]GIN ([A-Z0-9]+ )*PRIVATE KEY( BLOCK)?-----"
	"secret-assignment|i|(api[_-]?key|secret|token|passw(or)?d|credentials?)[A-Za-z0-9_-]*[\"']?[[:space:]]*[:=][[:space:]]*[\"']([^\"'[:space:]$]|[$][^{A-Za-z_\"'[:space:]])[^\"'[:space:]]{15,}[\"']"
	"secret-assignment|i|(api[_-]?key|secret|token|passw(or)?d|credentials?)[A-Za-z0-9_-]*[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_./+-]{20,}"
)
public_aliases='^(security|support|ops|conduct)@'
fake_marker='fake|test|planted|example'

rule_grep() { # mode -> grep flags (extended regex, binary files skipped)
	if [ "$1" = i ]; then printf '%s' -iIE; else printf '%s' -IE; fi
}

# --- allowlist ---------------------------------------------------------------
allow_globs=()
allow_lits=()
allow_used=()
bad_entry() {
	echo "$allow_file:$1: $2" >&2
	exit 2
}
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
			bad_entry "$n" "malformed entry (need: path-glob | literal | reason)"
		fi
		case "$glob" in '*' | '**' | '*/*' | '**/*') bad_entry "$n" "glob '$glob' covers the whole repository — name the file or directory" ;; esac
		[ "${#lit}" -ge 4 ] || bad_entry "$n" "literal '$lit' is shorter than 4 characters — too broad"
		# The allowlist is published too: a literal may not itself be private
		# context, and a secret-shaped literal must be obviously fake.
		for entry in "${rules[@]}"; do
			id="${entry%%|*}"
			r="${entry#*|}"
			if printf '%s\n' "$lit" | grep -q "$(rule_grep "${r%%|*}")" -- "${r#*|}"; then
				case "$id" in
				secret-*) printf '%s' "$lit" | grep -qiE "$fake_marker" ||
					bad_entry "$n" "[$id] the literal is secret-shaped and not obviously fake (value redacted)" ;;
				private-email) printf '%s\n' "$lit" | grep -oiE "${r#*|}" | grep -qviE "$public_aliases" &&
					bad_entry "$n" "[$id] the literal is itself a private address" ;;
				personal-path) ;;
				*) bad_entry "$n" "[$id] the literal is itself private context" ;;
				esac
			fi
		done
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

allowed() { # rule mode regex file text -> 0 when an entry covers it (marks it used)
	local i v
	for i in "${!allow_globs[@]}"; do
		# shellcheck disable=SC2053 # glob match is intended
		if [[ "$4" == ${allow_globs[$i]} ]] && [[ "$5" == *"${allow_lits[$i]}"* ]]; then
			case "$1" in
			secret-*)
				# Every matched value itself (not merely the line) must be
				# obviously fake.
				while IFS= read -r v; do
					if ! printf '%s' "$v" | grep -qiE "$fake_marker"; then
						echo "$4: [$1] allow entry for '$4' covers a value that is not obviously fake (value redacted)" >&2
						return 1
					fi
				done < <(printf '%s\n' "$5" | grep -o "$(rule_grep "$2")" -- "$3")
				;;
			esac
			allow_used[i]=1
			return 0
		fi
	done
	return 1
}

errlog="$(mktemp)"
trap 'rm -f "$errlog"' EXIT
if [ "${#files[@]}" -gt 0 ]; then
	for entry in "${rules[@]}"; do
		id="${entry%%|*}"
		rest="${entry#*|}"
		mode="${rest%%|*}"
		re="${rest#*|}"
		flags="$(rule_grep "$mode")"
		# File names come back NUL-separated (safe for ":" or newlines in a
		# name); lines are then read per file, so nothing parses a path.
		while IFS= read -r -d '' file; do
			while IFS= read -r hit; do
				lineno="${hit%%:*}"
				text="${hit#*:}"
				if [ "$id" = private-email ]; then
					printf '%s\n' "$text" | grep -oiE "$re" | grep -qviE "$public_aliases" || continue
				fi
				allowed "$id" "$mode" "$re" "$file" "$text" && continue
				report "$id" "$file" "$lineno" "$text"
			done < <(grep -n "$flags" -- "$re" "$file" 2>>"$errlog")
		done < <(printf '%s\0' "${files[@]}" | xargs -0 grep -l --null "$flags" -- "$re" 2>>"$errlog" || true)
	done
fi
if [ -s "$errlog" ]; then
	# grep could not read a file or rejected a pattern: never report OK.
	cat "$errlog" >&2
	echo "public-hygiene: grep failed — the result is not trustworthy" >&2
	exit 2
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
