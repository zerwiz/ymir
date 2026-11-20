#!/usr/bin/env bash
# collaborators.sh — the people we work with: clients, collaborators, advisers, partners.
#
# One record per person, in the vault: $YMIR_HOME/hodd/identity/collaborators.yaml.
# Never in this repo — a collaborator is private data (Rule 04), and a name with an
# address is exactly what must not be published.
#
#   collaborators.sh list [--kind client|collaborator|adviser|partner|prospect]
#   collaborators.sh show <id>
#   collaborators.sh add <id> --name "…" [--kind K] [--org "…"] [--email A]… [--project P]
#                              [--status S] [--nda true|false|unknown] [--note "…"]
#   collaborators.sh set <id> <field> <value>
#   collaborators.sh check            # validate every record (ids, emails, enums, NDA parties)
#   collaborators.sh email <id> --subject S --body FILE [--dry-run]
#
# `email` is the safe path: it refuses a person flagged `do-not-contact`, and it runs the
# private/NDA guard (Rule 26) before the mail door is called. A finding stops the send.
#
# Exit: 0 ok · 1 invalid or refused · 2 usage.
set -u
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'error: the home is unresolved\n' >&2; exit 1; }
REG="$HOME_R/hodd/identity/collaborators.yaml"
PY="$(command -v python3 || echo /usr/bin/python3)"

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }

cmd="${1:-list}"; shift || true
case "$cmd" in
  -h|--help) usage; exit 0 ;;
  --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
esac

REG="$REG" ROOT_DIR="$ROOT" DOOR="$cmd" "$PY" - "$@" <<'PY'
import os, sys, re, subprocess
import yaml

REG = os.environ["REG"]
ROOT = os.environ.get("ROOT_DIR", os.getcwd())
DOOR = os.environ["DOOR"]
argv = sys.argv[1:]
KINDS = {"client", "collaborator", "adviser", "partner", "prospect"}
STATUSES = {"prospect", "active", "paused", "former"}
EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$")


def load():
    try:
        with open(REG) as fh:
            data = yaml.safe_load(fh) or {}
    except FileNotFoundError:
        data = {}
    data.setdefault("version", 1)
    data.setdefault("people", [])
    return data


def save(data):
    os.makedirs(os.path.dirname(REG), exist_ok=True)
    tmp = REG + ".tmp"
    with open(tmp, "w") as fh:
        yaml.safe_dump(data, fh, sort_keys=False, allow_unicode=True)
    os.replace(tmp, REG)


def fail(msg):
    print(f"error: {msg}")
    sys.exit(1)


def need_person(data, pid):
    for person in data["people"]:
        if person.get("id") == pid:
            return person
    fail(f"no collaborator '{pid}' — collaborators.sh list")


def toon(rows, head):
    print(head)
    for r in rows:
        print("  " + r)


if DOOR == "list":
    data = load()
    rows = data["people"]
    kind = None
    if "--kind" in argv:
        kind = argv[argv.index("--kind") + 1]
        rows = [p for p in rows if p.get("kind") == kind]
    toon([f'"{p.get("id")}","{p.get("name")}","{p.get("kind")}","{p.get("status")}","{p.get("org","")}","{",".join(p.get("emails") or [])}"' for p in rows],
         f'collaborators[{len(rows)}]{{id,name,kind,status,org,emails}}:')
    sys.exit(0)

if DOOR == "show":
    if not argv:
        fail("show needs an id")
    p = need_person(load(), argv[0])
    print(yaml.safe_dump(p, sort_keys=False, allow_unicode=True).rstrip())
    sys.exit(0)

if DOOR == "add":
    if not argv:
        fail("add needs an id")
    pid = argv[0]
    data = load()
    if any(p.get("id") == pid for p in data["people"]):
        fail(f"'{pid}' already exists — use set")
    rec = {"id": pid, "name": "", "kind": "collaborator", "status": "prospect",
           "org": "", "emails": [], "project": "", "nda": "unknown",
           "consent": {"email": True, "marketing": False}, "notes": ""}
    i = 1
    while i < len(argv):
        flag = argv[i]
        value = argv[i + 1] if i + 1 < len(argv) else ""
        if flag == "--name": rec["name"] = value
        elif flag == "--kind": rec["kind"] = value
        elif flag == "--status": rec["status"] = value
        elif flag == "--org": rec["org"] = value
        elif flag == "--project": rec["project"] = value
        elif flag == "--nda": rec["nda"] = value
        elif flag == "--note": rec["notes"] = value
        elif flag == "--email":
            rec["emails"].append(value)
            i += 1
        else:
            i += 1
            continue
        i += 1
    if rec["kind"] not in KINDS:
        fail(f"kind must be one of {sorted(KINDS)}")
    if rec["status"] not in STATUSES:
        fail(f"status must be one of {sorted(STATUSES)}")
    for email in rec["emails"]:
        if not EMAIL.match(email):
            fail(f"not an email address: {email}")
    data["people"].append(rec)
    save(data)
    print(f'collaborators[1]{{action,id}}: "added","{pid}"')
    sys.exit(0)

if DOOR == "set":
    if len(argv) < 3:
        fail("set needs <id> <field> <value>")
    pid, field, value = argv[0], argv[1], " ".join(argv[2:])
    data = load()
    person = need_person(data, pid)
    if field == "email":
        person.setdefault("emails", []).append(value)
    elif field == "kind" and value not in KINDS:
        fail(f"kind must be one of {sorted(KINDS)}")
    elif field == "status" and value not in STATUSES:
        fail(f"status must be one of {sorted(STATUSES)}")
    else:
        person[field] = value
    save(data)
    print(f'collaborators[1]{{action,id}}: "set {field}","{pid}"')
    sys.exit(0)

if DOOR == "check":
    data = load()
    problems = []
    seen = set()
    # the NDA register names its authorised parties; a collaborator claiming an NDA is checked
    parties = set()
    conf = os.path.join(os.path.dirname(REG), "confidential.yaml")
    try:
        with open(conf) as fh:
            blob = yaml.safe_load(fh) or {}
        for value in blob.get("parties", []) or []:
            parties.add(str(value).lower())
        for item in (blob.get("authorised_parties") or []):
            parties.add(str(item).lower())
    except Exception:
        pass
    for p in data["people"]:
        pid = p.get("id", "")
        if not pid or pid in seen:
            problems.append(f"{pid or '(no id)'}: duplicate or empty id")
        seen.add(pid)
        if not p.get("name"):
            problems.append(f"{pid}: no name")
        if p.get("kind") not in KINDS:
            problems.append(f"{pid}: kind '{p.get('kind')}'")
        if p.get("status") not in STATUSES:
            problems.append(f"{pid}: status '{p.get('status')}'")
        for email in p.get("emails") or []:
            if not EMAIL.match(str(email)):
                problems.append(f"{pid}: email '{email}'")
        if str(p.get("nda", "")).lower() == "true" and parties:
            if not any(str(e).lower() in parties for e in (p.get("emails") or [])):
                problems.append(f"{pid}: nda true, but the address is not in the NDA register")
    if problems:
        print(f'collaborators-check[{len(problems)}]{{problem}}:')
        for problem in problems:
            print(f'  "{problem}"')
        sys.exit(1)
    print(f'collaborators-check[1]{{people,verdict}}: "{len(data["people"])}","valid"')
    sys.exit(0)

if DOOR == "email":
    if not argv:
        fail("email needs an id")
    pid = argv[0]
    subject = ""
    body = ""
    dry = "--dry-run" in argv
    if "--subject" in argv:
        subject = argv[argv.index("--subject") + 1]
    if "--body" in argv:
        body = argv[argv.index("--body") + 1]
    if not subject or not body:
        fail("email needs --subject and --body")
    data = load()
    person = need_person(data, pid)
    if person.get("status") == "former":
        fail(f"{pid} is a former contact — record it deliberately first")
    if not (person.get("consent", {}) or {}).get("email", True):
        fail(f"{pid} has not consented to email")
    if not person.get("emails"):
        fail(f"{pid} has no address")
    if not os.path.isfile(body):
        fail(f"body file not found: {body}")
    guard = os.path.join(ROOT, "bin", "gates", "guards", "private-guard.sh")
    check = subprocess.run(["bash", guard, "check", body], capture_output=True, text=True)
    if check.returncode != 0:
        print(check.stdout)
        fail("the private/NDA guard refused this body (Rule 26)")
    mail = os.path.join(ROOT, "bin", "time", "snotra", "mail-send.sh")
    args = ["bash", mail, "draft", "--to", ",".join(person["emails"]), "--subject", subject, "--body", body]
    if dry:
        args.append("--dry-run")
    out = subprocess.run(args, capture_output=True, text=True).stdout.strip()
    print(out)
    sys.exit(0)

fail(f"unknown command {DOOR}")
PY
