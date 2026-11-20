#!/usr/bin/env bash
# who.sh — the address book, and the one question that blocks everything: has this person an email?
#
#   who.sh list                 every collaborator, with or without an address
#   who.sh missing              only those WITHOUT one — the list that stops an invitation
#   who.sh set-email <id> <a@b> give a person an address (written to the vault registry)
#   who.sh email <id>           print one address (exit 1 if there is none)
#
# Measured 2026-10-22: three of four collaborators had NO address in the registry, so no invitation and
# no mail could be sent — the capability was ready and the book was empty.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'who: the hoard is unresolved\n' >&2; exit 2; }
REG="$HOME_R/hodd/identity/collaborators.yaml"
CMD="${1:-list}"; shift || true
REG_Q="$REG" WHO_CMD="$CMD" WHO_ARG="${1:-}" WHO_EMAIL="${2:-}" python3 - <<'PY'
import os, sys, yaml, datetime

reg = os.environ["REG_Q"]
cmd = os.environ["WHO_CMD"]
arg = os.environ["WHO_ARG"]
mail = os.environ["WHO_EMAIL"]

def load():
    with open(reg) as fh:
        return yaml.safe_load(fh) or {}

def rows(d):
    return d.get("collaborators") or d.get("people") or []

def addr(r):
    e = r.get("emails") or r.get("email") or ""
    if isinstance(e, list):
        e = e[0] if e else ""
    return str(e).strip()

if cmd == "list":
    d = load(); rs = rows(d)
    print("who[{n}]{id,name,email,org}:")
    print(f"who{len(rs)}")
    for r in rs:
        print(f'  "{r.get("id","")}","{r.get("name","")}","{addr(r) or "—"}","{r.get("org","") or ""}"')
elif cmd == "missing":
    rs = [r for r in rows(load()) if not addr(r)]
    print("who[{n}]{id,name,needs}:")
    print(f"who{len(rs)}")
    for r in rs:
        print(f'  "{r.get("id","")}","{r.get("name","")}","an email address"')
elif cmd == "email":
    needle = (arg or "").strip().lower()
    for r in rows(load()):
        pid = str(r.get("id", "")).lower()
        first = str(r.get("name", "")).split(" ")[0].lower()
        # "craig" must find craig-martin: a person is not asked to type a slug
        if pid == needle or str(r.get("name", "")).lower() == needle \
           or pid.startswith(needle) or first == needle:
            a = addr(r)
            if a:
                print(a); sys.exit(0)
            print(f"who: {arg} has no email — set one with: who.sh set-email {arg} <address>", file=sys.stderr)
            sys.exit(1)
    print(f"who: no such person: {arg}", file=sys.stderr); sys.exit(1)
elif cmd == "set-email":
    if not arg or not mail or "@" not in mail:
        print("who: usage: who.sh set-email <id> <address>", file=sys.stderr); sys.exit(2)
    d = load(); hit = False
    for r in rows(d):
        if r.get("id") == arg:
            r["emails"] = [mail]; r["email_updated"] = datetime.date.today().isoformat()
            hit = True
    if not hit:
        print(f"who: no such person: {arg}", file=sys.stderr); sys.exit(3)
    with open(reg, "w") as fh:
        yaml.safe_dump(d, fh, sort_keys=False, allow_unicode=True)
    print(f'who[1]{{id,email}}: "{arg}","{mail}"')
else:
    print("who: list | missing | set-email <id> <address> | email <id>", file=sys.stderr); sys.exit(2)
PY
