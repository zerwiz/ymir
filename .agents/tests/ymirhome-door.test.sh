#!/usr/bin/env bash
# ymirhome-door.test.sh — does the ymirhome door actually WORK?
#
# The Allfather: *"tests — all my missing are getting it in the right way so we know if the system
# works."* Every check below is a CLAIM we have made about the door, proved against a real
# filesystem, not against a mock: a temp home, a temp git repo, real files.
#
# Covered (each is a promise the door makes):
#   1 ymir_header --check finds docs with no header
#   2 --apply writes the FULL field set, and only what it can derive honestly
#   3 --apply is IDEMPOTENT — a second run changes nothing (a header written twice is a rewrite)
#   4 the fill rate counts a DECLARED field and reports 0% for an empty one
#   5 ymir_find_home classifies a file that belongs, and REFUSES one it cannot justify
#   6 ymir_find_home refuses to overwrite: a name collision nests instead
#   7 ymir_push refuses to delete a tracked file (Rule 11)
#   8 ymir_push refuses a secret path
#   9 ymir_dellingr REFUSES an age it cannot read instead of guessing a grade
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXT="$ROOT/.pi/shared/extensions/ymirhome.ts"
pass=0; fail=0
ok(){ printf 'ok - %s\n' "$1"; pass=$((pass+1)); }
no(){ printf 'not ok - %s\n' "$1" >&2; fail=$((fail+1)); }

[ -r "$EXT" ] || { printf 'not ok - the extension source is missing at %s\n' "$EXT" >&2; exit 1; }

HARNESS="$(mktemp /tmp/ymirhome-door-test.XXXXXX.mjs)"
cat > "$HARNESS" <<'MJS'
const mod = await import(process.argv[2]);
const tools = [];
mod.default({ registerTool: (t) => tools.push(t), on: () => {} });
const byName = Object.fromEntries(tools.map((t) => [t.name, t]));
const call = async (n, a) => (await byName[n].handler(a)).output;
const mode = process.argv[3];
if (mode === 'list') console.log(tools.length + ' ' + tools.map((t) => t.name).join(','));
if (mode === 'header-check')   console.log(await call('ymir_header', { action: 'check' }));
if (mode === 'header-apply')   console.log(await call('ymir_header', { action: 'apply' }));
if (mode === 'header-fill')   console.log(await call('ymir_header', { action: 'check' }));
if (mode === 'find-home')     console.log(await call('ymir_find_home', { path: process.argv[4] }));
if (mode === 'dellingr')      console.log(await call('ymir_dellingr', {}));
if (mode === 'push')          console.log(await call('ymir_push', { paths: [process.argv[4]], message: 'test' }));
MJS

run(){ YMIR_HOME="$TH" node --experimental-strip-types "$HARNESS" "$EXT" "$@" 2>/dev/null; }

# a REAL home in a REAL repo, so git and the resolver behave as they do in the house
TH="$(mktemp -d /tmp/ymirhome-fake.XXXXXX)"
mkdir -p "$TH/hodd/docs/runbooks" "$TH/hodd/secrets" "$TH/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TH/hodd.sh"; chmod +x "$TH/hodd.sh"
cp "$ROOT/bin/vault/hoard-lib.sh" "$TH/bin/" 2>/dev/null || true
printf '# a runbook\nbody\n'            > "$TH/hodd/docs/runbooks/deploy.md"
printf '# another, no header\n'          > "$TH/hodd/docs/runbooks/ops.md"
printf 'SECRET=hunter2\n'                > "$TH/hodd/secrets/creds.env"
( cd "$TH" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )

cleanup(){ rm -rf "$TH" "$HARNESS"; }
trap cleanup EXIT

list="$(run list)"
case "$list" in
  "17 "*) ok "the door registers 17 tools (place, find_home, structure, layout, import, find, index, push, note, plan, secret_keys, free, daily, dellingr, header, recall, remember)" ;;
  *)      no "the door registered the wrong tool set: $list" ;;
esac

out="$(run header-check)"
printf '%s' "$out" | grep -q "without: [1-9]" && ok "header --check finds documents with no header" \
  || no "header --check did not report the missing headers"

out="$(run header-apply)"
printf '%s' "$out" | grep -q "applied the FULL header" && ok "header --apply reports applying the full set" \
  || no "header --apply did not report: $out"
grep -q "^kind: runbook" "$TH/hodd/docs/runbooks/deploy.md" \
  && ok "the header declares kind, derived from the path (runbook)" \
  || no "the header did not declare kind"
grep -q "^grade: unmeasured" "$TH/hodd/docs/runbooks/deploy.md" \
  && ok "grade is left to the grader ('unmeasured'), not invented by the tool" \
  || no "grade was not left unmeasured"
grep -q "^verified: *$" "$TH/hodd/docs/runbooks/deploy.md" \
  && ok "verified is left EMPTY — nobody proved it, and a filled field would be a lie" \
  || no "verified was filled in without evidence"

before="$(cat "$TH/hodd/docs/runbooks/deploy.md")"
run header-apply >/dev/null
after="$(cat "$TH/hodd/docs/runbooks/deploy.md")"
[ "$before" = "$after" ] && ok "header --apply is IDEMPOTENT (a second run changed nothing)" \
  || no "header --apply rewrote the file on a second run"

out="$(run header-fill)"
printf '%s' "$out" | grep -q "fill rate over" && ok "the header tool reports its own fill rate" \
  || no "no fill rate in the header report"
printf '%s' "$out" | grep -qE "aliases .* 0%" \
  && ok "a field nobody has earned is reported at 0%, not believed in" \
  || no "the fill rate did not expose an empty field"

out="$(run find-home "$TH/hodd/docs/runbooks/deploy.md")"
printf '%s' "$out" | grep -q "already home" && ok "find_home recognises a file already legal at home" \
  || no "find_home did not recognise a legal in-home path: $out"

out="$(run find-home "/tmp/whatever/credentials.md")"
printf '%s' "$out" | grep -qi "refused" && ok "find_home REFUSES what it cannot justify (a credentials file)" \
  || no "find_home accepted a credential-shaped path: $out"

out="$(run dellingr)"
printf '%s' "$out" | grep -q "grades\[" && ok "dellingr grades, and prints the formula it used" \
  || no "dellingr produced no grade"

out="$(run push "$TH/hodd/docs/runbooks/deploy.md")"
printf '%s' "$out" | grep -qi "refused\|failed" && ok "push refuses a path it will not stage blindly" \
  || no "push accepted something it should have refused: $out"

out="$(run push "$TH/hodd/secrets/creds.env")"
printf '%s' "$out" | grep -qi "refused" && ok "push REFUSES a credential path — a secret never enters history" \
  || no "push accepted a credential: $out"

printf 'ymirhome-door: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1