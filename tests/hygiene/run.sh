#!/usr/bin/env bash
# Self-test for scripts/check-public-hygiene.sh — host-runnable (bash + git
# + grep; no network). Each case builds a throwaway git repo in a temp dir,
# plants files, stages them and runs the real script against it. Planted
# names and secret-shaped values are assembled from pieces at runtime so
# this file never matches the rules it tests.
set -u
cd "$(dirname "$0")/../.." || exit 1
SCRIPT="$PWD/scripts/check-public-hygiene.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
ok() { # cond-exit-status message
	if [ "$1" -eq 0 ]; then pass=$((pass + 1)); else
		fail=$((fail + 1))
		echo "FAIL: $2"
	fi
}

n=0
fresh() { # -> sets r to a new empty repo (no subshell: n must persist)
	n=$((n + 1))
	r="$WORK/r$n"
	mkdir -p "$r"
	git -C "$r" init -q
}

run() { # repo -> sets OUT, RC
	OUT="$(bash "$SCRIPT" "$1" 2>&1)"
	RC=$?
}

stage() { git -C "$1" add -A; }

# Pieces (never written whole in this file).
U="Us""ers"
ORG="Daily""Bot-Inc"
REPO="dailybot""-core"
TOOL="db""dev"
MESH="[daily""bot-mesh]"
DOM="daily""bot.com"
AWS="AK""IA""ABCDEFGHIJKLMNOP"
GHT="gh""p_""abcdefghijklmnopqrstuvwxyz0123456789"
LLM="s""k-""planted0123456789abcdefghij"
SLK="xo""xb-""1234567890-abcdef"
GOO="AI""za""SyA0123456789abcdefghijklmnopqrstuv"
PK="-----BEGIN RSA PRI""VATE KEY-----"
ASG="api_key = \"Zq8""xW4rT9mP2kL7nB3v\""
XAI="xa""i-""Q7wE9rT2yU4iO6pA8sD0fG1h"
NPM="np""m_""abcdefghijklmnopqrstuvwxyz0123456789"
GLP="gl""pat-""abcdefghij0123456789"
STR="sk""_live_""abcdefghij0123456789"
HFT="h""f_""abcdefghijklmnopqrstuvwxyz0123456"
JWT="ey""JhbGciOiJIUzI1NiJ9.ey""JzdWIiOiIxMjM0NTY3ODkwIn0"
BEA="Authorization: Bea""rer abcdefghij0123456789xyz"
PGP="-----BEGIN PGP PRI""VATE KEY BLOCK-----"
UNQ="XAI_API_""KEY=Zq8xW4rT9mP2kL7nB3vC5"

# 1. A clean repo passes.
fresh
echo "plain text" >"$r/a.md"
stage "$r"
run "$r"
ok $((RC != 0)) "clean repo passes (rc=$RC: $OUT)"

# 2. Every rule fires on its planted value.
check_rule() { # rule-id content
	fresh
	printf '%s\n' "$2" >"$r/f.txt"
	stage "$r"
	run "$r"
	[ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "\[$1\]"
	ok $? "rule $1 fires (rc=$RC: $OUT)"
}
check_rule personal-path "see /$U/alice/projects"
check_rule personal-path "see /ho""me/alice/projects"
check_rule personal-path "C:\\$U\\bob\\x"
check_rule private-org "github.com/$ORG/x"
check_rule private-repo "clone $REPO here"
check_rule internal-name "run $TOOL up"
check_rule internal-name "stamp $MESH"
check_rule private-email "mail jane@$DOM"
check_rule secret-aws "key $AWS"
check_rule secret-github "token $GHT"
check_rule secret-llm "key $LLM"
check_rule secret-slack "slack $SLK"
check_rule secret-google "g $GOO"
check_rule secret-private-key "$PK"
check_rule secret-assignment "$ASG"
check_rule secret-llm "key $XAI"
check_rule secret-vendor "npm $NPM"
check_rule secret-vendor "gitlab $GLP"
check_rule secret-vendor "stripe $STR"
check_rule secret-vendor "hf $HFT"
check_rule secret-jwt "jwt $JWT"
check_rule secret-bearer "$BEA"
check_rule secret-private-key "$PGP"
check_rule secret-assignment "$UNQ"

# 3. Public aliases, generic words and lookalikes do not fire.
fresh
printf '%s\n' "security@$DOM" "support@$DOM, ops@$DOM, conduct@$DOM" \
	"the ~/.config path" "\$HOME/x" "https://example.com/home/page" \
	"${TOOL}x is another word" "my-api-services-client" \
	"see task-execution-protocol-version-six-details" "token: \${{ github.token }}" >"$r/ok.md"
stage "$r"
run "$r"
ok $((RC != 0)) "aliases and lookalikes pass (rc=$RC: $OUT)"

# 4. Secret values never reach the output.
fresh
printf '%s\n' "$AWS" "$GHT" "$LLM" "$SLK" "$GOO" "$ASG" "$XAI" "$JWT" >"$r/s.txt"
stage "$r"
run "$r"
leaked=0
for v in "$AWS" "$GHT" "$LLM" "$SLK" "$GOO" "Zq8xW4rT9mP2kL7nB3v" "$XAI" "$JWT"; do
	printf '%s' "$OUT" | grep -qF "$v" && leaked=1
done
ok $((RC != 1 || leaked)) "secret hits are reported redacted (rc=$RC leaked=$leaked)"

# 5. An allow entry suppresses only its path + literal.
fresh
mkdir -p "$r/docker"
echo "volume /ho""me/dev/.cache" >"$r/docker/c.yml"
echo "volume /ho""me/dev/.cache" >"$r/other.yml"
echo "docker/* | /ho""me/dev | container user" >"$r/.public-hygiene-allow"
stage "$r"
run "$r"
[ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "^other.yml:" && ! printf '%s' "$OUT" | grep -q "^docker/"
ok $? "allow entry is scoped to its glob (rc=$RC: $OUT)"

# 6. A stale entry fails (exit 2).
fresh
echo "plain" >"$r/a.md"
echo "a.md | never-present-literal | reason" >"$r/.public-hygiene-allow"
stage "$r"
run "$r"
[ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q "stale entry"
ok $? "stale allow entry fails (rc=$RC: $OUT)"

# 7. An entry without a reason fails (exit 2).
fresh
echo "plain" >"$r/a.md"
echo "a.md | plain |" >"$r/.public-hygiene-allow"
stage "$r"
run "$r"
[ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q "malformed"
ok $? "reasonless allow entry fails (rc=$RC: $OUT)"

# 8. A secret allow needs the matched VALUE to be obviously fake: a marker
#    elsewhere on the line ("latest") is not enough.
FAKEAWS="AK""IA""FAKEFAKEFAKEFAKE"
fresh
echo "real $AWS # latest" >"$r/k.txt"
echo "fixture $FAKEAWS" >"$r/fixture.txt"
printf '%s\n' "k.txt | real | looks real" "fixture.txt | fixture | planted fixture" >"$r/.public-hygiene-allow"
stage "$r"
run "$r"
[ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "^k.txt:.*secret-aws" && ! printf '%s' "$OUT" | grep -q "^fixture.txt:"
ok $? "secret allow needs a fake value (rc=$RC: $OUT)"

# 8b. The allowlist itself is vetted: whole-repo globs, short literals, a
#     real-looking secret literal and a private name as literal all fail.
for entry in "* | /ho""me/dev | broad" "a.md | ab | short" "a.md | $AWS | secret" "a.md | $TOOL here | private"; do
	fresh
	echo "plain" >"$r/a.md"
	printf '%s\n' "$entry" >"$r/.public-hygiene-allow"
	stage "$r"
	run "$r"
	[ "$RC" -eq 2 ] && ! printf '%s' "$OUT" | grep -qF "$AWS"
	ok $? "allowlist entry rejected: ${entry%%|*}| … (rc=$RC: ${OUT//$AWS/<redacted>})"
done

# 8c. A grep failure (unreadable file) fails closed, never OK.
fresh
echo "plain" >"$r/a.md"
stage "$r"
chmod 000 "$r/a.md"
run "$r"
chmod 644 "$r/a.md"
if [ "$(id -u)" -eq 0 ]; then RC=2; fi # root reads 000 files: nothing to prove
ok $((RC != 2)) "unreadable file fails closed (rc=$RC: $OUT)"

# 9. Symlinks, vendored skills and untracked files are not scanned.
fresh
mkdir -p "$r/.agents/skills/x"
echo "run $TOOL" >"$r/.agents/skills/x/SKILL.md"
echo "run $TOOL" >"$WORK/outside.txt"
ln -s "$WORK/outside.txt" "$r/link.txt"
stage "$r"
echo "run $TOOL" >"$r/untracked.txt"
run "$r"
ok $((RC != 0)) "symlinks, .agents/skills and untracked files are skipped (rc=$RC: $OUT)"

if [ "$fail" -gt 0 ]; then
	echo "HYGIENE SELF-TEST: $fail FAILED of $((pass + fail)) assertions"
	exit 1
fi
echo "HYGIENE SELF-TEST: $pass assertions OK"
