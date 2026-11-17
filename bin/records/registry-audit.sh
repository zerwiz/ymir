#!/usr/bin/env bash
# registry-audit.sh — does the registry answer for every service, and does every row tell the truth?
#
# The rule (RULES/the-hosted-services-registry.md) says a service running but unnamed is a FAULT, and plan 312 adds the
# two checks that make a row worth reading:
#
#   a port is owned once     two rows naming one port is a fault, and a listening door owned by nobody is a fault
#   a path exists            a row whose `script` or `dir` does not exist is a fault — that single check would have
#                            caught the share door the day its symlink's target was deleted
#
# Every finding names the registry file, the row and the field. A count is never the answer.
#
#   registry-audit.sh                human report; exit 1 on any finding
#   registry-audit.sh --answer <id>  ONE service in one read: what raises it, what runs, what port it owns, where it
#                                    lives, which runbook, and whether a stop is an incident
#   registry-audit.sh --list         every row's id and one-line name
#   registry-audit.sh --quiet        one line
#
# The shape a row is judged against is `config/services.schema.json` (the registry declares it in its own `schema:`
# header). A field the schema requires and a row does not carry is a finding, never a pass.
#
# The machine's own boundaries are honoured: `script`, `dir` and the sockets are measured only on the machine a row
# names, because a path on another host cannot be stat'd from here and a guess is worse than a named skip.
set -uo pipefail
# The home is resolved, never assumed (RULES/07): the one resolver is bin/vault/hoard-lib.sh.
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT="$(cd "$_DIR" && while [ ! -d "$PWD/RULES" ] || [ ! -d "$PWD/bin" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOME:-}" ] && [ -r "$_ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$_ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
  if command -v ymir_home_root >/dev/null 2>&1; then _h=""; ymir_home_root _h; [ -n "$_h" ] && export YMIR_HOME="$_h"; fi
fi
[ -n "${YMIR_HOME:-}" ] || { printf '%s: the home could not be resolved (bin/vault/hoard-lib.sh, RULES/07)\n' "$(basename "$0")" >&2; exit 2; }
HOME_DIR="${YMIR_HOME}"
REG="${YMIR_SERVICES_REGISTRY:-$HOME_DIR/hodd/identity/services.yaml}"
SCHEMA="$_ROOT/config/services.schema.json"
[ -f "$REG" ] || { printf 'registry-audit: no registry at %s\n' "$REG" >&2; exit 2; }
[ -f "$SCHEMA" ] || { printf 'registry-audit: no row shape at %s — the registry cannot be judged (plan 312)\n' "$SCHEMA" >&2; exit 2; }

mode=report; answer_id=""
case "${1:-}" in
  --quiet) mode=quiet ;;
  --list) mode=list ;;
  --answer) mode=answer; answer_id="${2:-}"; [ -n "$answer_id" ] || { printf 'registry-audit: --answer needs a row id\n' >&2; exit 2; } ;;
  "") ;;
  -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'registry-audit: unknown argument: %s (try --help)\n' "$1" >&2; exit 2 ;;
esac

exec python3 - "$mode" "$answer_id" "$REG" "$SCHEMA" "$HOME_DIR" "$_ROOT" <<'PY'
import json, os, subprocess, sys, socket, datetime

mode, answer_id, reg_path, schema_path, home_dir, repo_root = sys.argv[1:7]
try:
    import yaml
except Exception as exc:  # noqa: BLE001
    sys.stderr.write("registry-audit: python yaml is required to read the registry (%s)\n" % exc)
    sys.exit(2)

doc = yaml.safe_load(open(reg_path)) or {}
schema = json.load(open(schema_path))
services = doc.get("services") or []
row_shape = schema["$defs"]["service"]
required = row_shape["required"]
raise_branches = [b.get("required", []) for b in row_shape.get("anyOf", [])]
criticalities = row_shape["properties"]["criticality"]["enum"]
SIZE = __import__("re").compile(r"^[0-9]+(\.[0-9]+)?(Ki|Mi|Gi|Ti)?$")

local_host = socket.gethostname().split(".")[0]
findings = []   # (kind, row, message)
skips = []      # (checks, why)


def as_list(v):
    if v is None:
        return []
    if isinstance(v, (list, tuple)):
        return list(v)
    return [v]


def ports_of(row):
    out = []
    for p in as_list(row.get("ports")) + as_list(row.get("port")):
        try:
            out.append(int(p))
        except (TypeError, ValueError):
            out.append(p)
    return out


def row_ids_for_host(host):
    return [s.get("id", "?") for s in services if str(s.get("host", "")) == host]


def probe_path(value):
    """('ok' | 'missing' | 'broken-link' | 'relative', resolved) — a symlink into a gone tree is its own finding."""
    raw = str(value)
    path = os.path.expanduser(raw)
    if not path.startswith("/"):
        return ("relative", raw)
    if os.path.islink(path) and not os.path.exists(path):
        try:
            return ("broken-link", os.readlink(path))
        except OSError:
            return ("broken-link", path)
    if os.path.exists(path):
        return ("ok", path)
    return ("missing", path)


# ---------------------------------------------------------------- the registry's own header
header = doc.get("schema")
if not isinstance(header, dict):
    findings.append((
        "header", "(registry)",
        "%s does not declare its row shape — the header must carry `schema: {version, shape, checked_by, row}` "
        "so the next hand writes rows that fit (plan 312)" % reg_path))
else:
    for field in ("version", "shape", "checked_by", "row"):
        if header.get(field) in (None, "", []):
            findings.append(("header", "(registry)", "the `schema:` header has no `%s`" % field))
    if header.get("shape") and not os.path.exists(os.path.join(repo_root, str(header["shape"]))):
        findings.append((
            "header", "(registry)",
            "the header points at `%s`, which does not exist in %s" % (header["shape"], repo_root)))

# ---------------------------------------------------------------- the shape of every row
for row in services:
    sid = row.get("id") or "(no id)"
    for field in required:
        if field == "ports":
            # a list — even an empty one — is a declaration that the row owns no port; absence is not
            present = ("ports" in row and row.get("ports") is not None) or row.get("port") not in (None, "")
        else:
            present = row.get(field) not in (None, "", [])
        if not present:
            findings.append((
                "shape", sid,
                "no `%s` — a row must say it (schema %s, required: %s)"
                % (field, os.path.basename(schema_path), ", ".join(required))))
    if not any(all(row.get(f) not in (None, "", []) for f in branch) for branch in raise_branches):
        findings.append((
            "shape", sid,
            "nothing says how this service is raised AND what file runs — give `unit` + `script`, or `compose`"))
    if row.get("ports") not in (None, []) and row.get("port") not in (None, ""):
        findings.append(("shape", sid, "carries BOTH `ports` and `port` — two spellings of one fact is two truths"))
    c = row.get("criticality")
    if c not in (None, "") and c not in criticalities:
        findings.append(("shape", sid, "`criticality: %s` is not one of %s" % (c, " · ".join(criticalities))))
    budget = row.get("budget")
    if isinstance(budget, dict):
        if budget.get("memory_ceiling_mb") in (None, ""):
            findings.append(("shape", sid, "`budget` carries no `memory_ceiling_mb` — a budget with no ceiling sums to nothing"))
        elif not isinstance(budget.get("memory_ceiling_mb"), (int, float)):
            findings.append(("shape", sid, "`budget.memory_ceiling_mb` is not a number: %s" % budget.get("memory_ceiling_mb")))
    elif budget not in (None, ""):
        if not SIZE.match(str(budget)):
            findings.append(("shape", sid, "`budget: %s` is neither a systemd size (96Mi) nor a measured block" % budget))

# ---------------------------------------------------------------- a port is owned once
owners = {}
for row in services:
    sid = row.get("id") or "(no id)"
    seen = set()
    for port in ports_of(row):
        if isinstance(port, int):
            if port in seen:
                findings.append(("port-twice", sid, "names port %d twice inside its own row" % port))
            seen.add(port)
            owners.setdefault(port, []).append(sid)
        else:
            findings.append(("port-twice", sid, "`%s` is not a port number" % port))
for port in sorted(owners):
    rows = owners[port]
    if len(rows) > 1:
        findings.append((
            "port-twice", ", ".join(rows),
            "port %d is owned by %d rows: %s — one door, one row" % (port, len(rows), ", ".join(rows))))

# ---------------------------------------------------------------- a path exists (on the machine the row names)
checked_paths = 0
pathless_hosts = set()
for row in services:
    sid = row.get("id") or "(no id)"
    host = str(row.get("host") or "")
    if host != local_host:
        pathless_hosts.add(host or "(no host)")
        continue
    for field in ("script", "dir"):
        for value in as_list(row.get(field)):
            verdict, resolved = probe_path(value)
            checked_paths += 1
            if verdict == "ok":
                continue
            if verdict == "relative":
                findings.append((
                    "path", sid,
                    "`%s: %s` is not an absolute path — a row names the file it runs, not a name to go hunting for"
                    % (field, value)))
            elif verdict == "broken-link":
                findings.append((
                    "path", sid,
                    "`%s: %s` is a symlink into a tree that is GONE (→ %s)" % (field, value, resolved)))
            else:
                findings.append(("path", sid, "`%s: %s` does not exist" % (field, value)))
if checked_paths == 0:
    skips.append((
        "a path exists",
        "no row names this machine (%s), so no `script` or `dir` here can be stat'd — the rows name %s. Run this "
        "door on the machine a row names, or write the row for this one."
        % (local_host, ", ".join(sorted(h for h in pathless_hosts if h)) or "no host")))

# ---------------------------------------------------------------- a listening door is named
def listening_doors():
    try:
        out = subprocess.run(["ss", "-tlnH"], capture_output=True, text=True, timeout=20).stdout
    except Exception:  # noqa: BLE001
        return None
    doors = []
    for line in out.splitlines():
        fields = line.split()
        if len(fields) < 4:
            continue
        addr, _, port = fields[3].rpartition(":")
        try:
            port = int(port)
        except ValueError:
            continue
        loop = addr.startswith("127.") or addr in ("::1", "[::1]", "localhost")
        doors.append((addr, port, loop))
    return doors

local_rows = row_ids_for_host(local_host)
if not local_rows:
    skips.append((
        "a listening door is named",
        "no row in the registry names this machine (%s), so every socket here belongs to the desk, not the registry"
        % local_host))
else:
    doors = listening_doors()
    if doors is None:
        skips.append(("a listening door is named", "`ss` is not available on this machine"))
    else:
        named = set()
        for row in services:
            if str(row.get("host") or "") == local_host:
                named.update(p for p in ports_of(row) if isinstance(p, int))
        for addr, port, loop in doors:
            if loop or port in named:
                continue
            findings.append((
                "socket", "%s:%d" % (addr, port),
                "a listening door (%s:%d) that no row names — write the row, or close the door" % (addr, port)))

# ---------------------------------------------------------------- every running container is named
if not local_rows and doc.get("host") != local_host:
    skips.append((
        "every container is named",
        "`docker ps` here describes %s; the registry describes %s — judged where the containers are"
        % (local_host, doc.get("host") or "another host")))
else:
    try:
        running = sorted({n for n in subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}"], capture_output=True, text=True, timeout=30
        ).stdout.split() if n})
    except Exception:  # noqa: BLE001
        running = []
        skips.append(("every container is named", "no docker on this machine — nothing containerised to compare"))
    named_containers = {str(c) for s in services for c in as_list(s.get("containers"))}
    for name in running:
        if name not in named_containers:
            findings.append(("container", name, "running but named by no row — each is a fault: write its row, or stop it"))

# ---------------------------------------------------------------- the answer
def row_line(row, field):
    vals = as_list(row.get(field))
    return ", ".join(str(v) for v in vals) if vals else "—"


def describe(row):
    sid = row.get("id") or "(no id)"
    host = str(row.get("host") or "?")
    here = host == local_host
    print("%s — %s" % (sid, row.get("name") or "(no name)"))
    print("  host       %s%s" % (host, "" if here else "  (not this machine: its paths are not measured here)"))
    raise_by = []
    for u in as_list(row.get("unit")):
        raise_by.append("unit %s" % u)
    if row.get("compose"):
        raise_by.append("compose %s" % row["compose"])
    print("  raises     %s" % (", ".join(raise_by) or "NOTHING SAYS — no unit, no compose"))
    for field in ("script", "dir"):
        vals = as_list(row.get(field))
        if not vals:
            print("  %-10s — (the row does not say)" % ("runs" if field == "script" else field))
            continue
        for v in vals:
            if here:
                verdict, resolved = probe_path(v)
                state = "exists" if verdict == "ok" else (
                    "a SYMLINK INTO A GONE TREE (→ %s)" % resolved if verdict == "broken-link" else
                    "MISSING" if verdict == "missing" else "not absolute")
            else:
                state = "not measured here"
            print("  %-10s %s  (%s)" % ("runs" if field == "script" else field, v, state))
    ports = ports_of(row)
    print("  port       %s" % (", ".join(str(p) for p in ports) if ports else "— (owns none)"))
    runbook = str(row.get("runbook") or "")
    if not runbook:
        print("  runbook    — (the row does not say which page to open when it is down)")
    else:
        for page in [p.strip() for p in runbook.split("·") if p.strip()]:
            if page.startswith("/"):
                state = "exists" if os.path.exists(page) else "MISSING"
            else:
                found = os.path.exists(os.path.join(home_dir, page)) or os.path.exists(os.path.join(repo_root, page))
                state = "exists" if found else "MISSING"
            print("  runbook    %s  (%s)" % (page, state))
    crit = row.get("criticality")
    verdict = {
        "always": "a stop is an INCIDENT",
        "wanted": "a stop is a regression — it should be running or being finished",
        "dormant": "a stop is no incident — it serves nothing, and only the row says why",
    }.get(crit, "UNSET — nobody has said whether a stop is an incident")
    print("  stop       %s  (criticality: %s)" % (verdict, crit or "unset"))
    b = row.get("budget")
    if isinstance(b, dict):
        print("  budget     %s MiB ceiling (measured %s MiB) — %s"
              % (b.get("memory_ceiling_mb"), b.get("measured_mb", "?"), b.get("residency") or "residency not said"))
    else:
        print("  budget     %s" % (b or "— (the row does not say; the host's total cannot be summed)"))
    for field in ("public_url", "tunnel", "used_by", "status"):
        if row.get(field):
            print("  %-10s %s" % (field, row_line(row, field)))


if mode == "answer":
    match = [s for s in services if str(s.get("id")) == answer_id]
    if not match:
        near = ", ".join(str(s.get("id")) for s in services)
        sys.stderr.write("registry-audit: no row with id '%s' in %s\n  ids: %s\n" % (answer_id, reg_path, near))
        sys.exit(2)
    describe(match[0])
    sys.exit(0)

if mode == "list":
    for row in services:
        print("%-22s %s" % (row.get("id"), (row.get("name") or "").split(" — ")[0]))
    sys.exit(0)

stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
if mode == "quiet":
    kinds = {}
    for kind, _row, _msg in findings:
        kinds[kind] = kinds.get(kind, 0) + 1
    parts = ["%d %s" % (n, k) for k, n in sorted(kinds.items())] or ["no finding"]
    print("registry-audit: %d row(s) · %s · %d skip(s)" % (len(services), " · ".join(parts), len(skips)))
    sys.exit(1 if findings else 0)

print("REGISTRY AUDIT — %s" % stamp)
print("registry   %s" % reg_path)
print("shape      %s%s" % (schema_path, "  (declared by the registry's own header)" if isinstance(header, dict) else ""))
print("rows       %d · this machine %s" % (len(services), local_host))
print("")
groups = [
    ("port-twice", "A PORT IS OWNED ONCE", "two rows on one port, or a port that is not a number"),
    ("path", "A PATH EXISTS", "a row whose `script` or `dir` is gone is a row that cannot be run"),
    ("socket", "A LISTENING DOOR IS NAMED", "a socket this machine answers on that no row claims"),
    ("shape", "A ROW FITS THE SHAPE", "fields the schema requires that this row does not carry"),
    ("header", "THE REGISTRY DECLARES ITS SHAPE", "the `schema:` header the next hand writes rows from"),
    ("container", "EVERY CONTAINER IS NAMED", "a container running on this machine that no row names"),
]
for kind, title, why in groups:
    mine = [f for f in findings if f[0] == kind]
    print("== %s — %s" % (title, why))
    if not mine:
        print("   none")
    else:
        for _k, row, msg in mine:
            print("   %-22s %s" % (row, msg))
    print("")
for checks, why in skips:
    print("== SKIPPED — %s" % checks)
    print("   %s" % why)
    print("")
print("RESULT   %s" % ("RED — %d finding(s), each named above" % len(findings) if findings else "green"))
sys.exit(1 if findings else 0)
PY
