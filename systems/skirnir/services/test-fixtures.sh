#!/usr/bin/env bash
# test-fixtures.sh — the operator's own words, handed to a TEST so the test needs none of them.
#
#   test-fixtures.sh names     every private name his home registers: a full name, an address' local
#                              part, a handle — one per line (for "no private name rode along")
#   test-fixtures.sh contact   one person his digest holds a contact fact about (for the tier gate)
#   test-fixtures.sh subject   a subject his digest holds TWO or more approved claims about (for the
#                              tie test: two facts about one subject must still answer)
#
# WHY THIS DOOR EXISTS (plan 288 §1, RULES/04): Skírnir's walls and smokes assert things ABOUT private
# data — that a stranger cannot hear a contact, that no client's name rides along, that a subject with
# two facts still answers. A test in a PUBLIC repository cannot carry those names, so it asks the
# operator's home and asserts against whatever answers. One reader per fixture, so two tests can never
# disagree about who is private.
#
# An empty answer is a CLEAN SKIP that the test prints (Rule 25): a home that registers nobody has
# nothing to leak, and saying so beats a silent pass that stood in for a name nobody wrote down.
#
# Exit: 0 ok (even with an empty answer) · 2 the hoard is unresolved · 3 a name this door does not know
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'test-fixtures: the hoard is unresolved — nothing to compare against\n' >&2; exit 2; }

WHAT="${1:-names}"
case "$WHAT" in names|contact|subject) ;; *) printf 'test-fixtures: unknown fixture %s\n' "$WHAT" >&2; exit 3 ;; esac

exec python3 - "$ROOT" "$HOME_R" "$WHAT" <<'PY'
import json, os, re, sys

root, home, what = sys.argv[1], sys.argv[2], sys.argv[3]
digest = os.path.join(home, "hodd", "state", "assistant", "digest.jsonl")

if what == "names":
    # the SAME reader the people-guard uses, so the ward and the test cannot disagree
    sys.path.insert(0, os.path.join(root, "bin", "gates", "guards"))
    try:
        import ndalib
        names = ndalib.load_people(home, {}) or {}
    except Exception:
        names = {}
    for name in sorted(str(n).strip() for n in names):
        if len(name) >= 3:
            print(name)
    raise SystemExit(0)

facts = []
try:
    with open(digest, encoding="utf-8") as fh:
        facts = [json.loads(line) for line in fh if line.strip()]
except OSError:
    facts = []

if what == "contact":
    # a person the house holds a CONTACT fact about, and whose name appears in NO claim a stranger may
    # hear — otherwise the fixture would test the operator's own classification instead of the gate
    heard = " ".join(str(f.get("claim") or "") for f in facts
                     if str(f.get("class") or "") in ("public", "logistics", "role")).lower()
    for fact in facts:
        if str(fact.get("class") or "") != "contacts":
            continue
        claim = str(fact.get("claim") or "").strip()
        m = re.match(r"([A-Z][\w'’-]+(?:\s+[A-Z][\w'’-]+)*)\s+is\b", claim)
        if m and m.group(1).lower() not in heard:
            print(m.group(1))
            break
    raise SystemExit(0)

# a subject TWO approved claims are about, out of the classes a stranger may hear
counts: dict[str, int] = {}
for fact in facts:
    if str(fact.get("class") or "") not in ("public", "logistics", "role"):
        continue
    claim = str(fact.get("claim") or "").strip()
    m = re.match(r"([A-Za-z0-9][A-Za-z0-9-]{3,})\s+is\b", claim)
    if m:
        counts[m.group(1)] = counts.get(m.group(1), 0) + 1
best = sorted((n, s) for s, n in counts.items() if n >= 2)
if best:
    print(best[0][1])
PY
