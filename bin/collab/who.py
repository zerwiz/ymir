#!/usr/bin/env python3
"""who.py — the roll: who was invited into the house's collaboration surfaces, and are they using them?

Reads the DECLARED register (`$YMIR_HOME/hodd/data/collaboration.yaml`) and measures the machine against
it, then prints one row per person. Nothing is written; nothing is guessed. A surface that cannot be read
is reported as `unread`, never as zero.

    collab.sh who                 the roll, as TOON
    collab.sh who --json          the merged measurement, as JSON
    collab.sh who --from FILE     measure nothing: merge a captured JSON (the test path)
    collab.sh who --strict        exit 1 when any declared account is absent from its surface

Surfaces, measured over ssh on the register's `host`:
  gate       Authelia — users, the authentication log, and whether any second factor is enrolled
  plane      the Gimlé Board — accounts, last sign-in, workspace membership
  affine     Gimlé Documents — accounts, when created and verified
  forge      Forgejo — accounts, last sign-in, admin flag, public keys
  shell      the server — which accounts have a login shell, and when they last signed in
"""
import argparse
import datetime
import json
import os
import subprocess
import sys

import yaml

REMOTE = r'''
import json, os, sqlite3, subprocess, datetime

def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)

out = {"measured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")}

# The house's own addresses, so a sign-in from inside the house is never mistaken for a counterpart.
ips = set()
r = run(["curl", "-sS", "-m", "6", "https://ifconfig.me"])
if r.returncode == 0 and r.stdout.strip():
    ips.add(r.stdout.strip())
out["house_ips"] = sorted(ips)

# ---- the gate (Authelia) -------------------------------------------------------------------
gate = {"users": [], "emails": {}, "logins": {}, "totp": 0, "webauthn": 0, "state": "unread"}
r = run(["docker", "exec", "gimle-gate", "cat", "/config/users_database.yml"])
if r.returncode == 0 and r.stdout.strip():
    gate["state"] = "ok"
    current = None
    for line in r.stdout.splitlines():
        s = line.rstrip()
        if s.startswith("  ") and s.endswith(":") and not s.startswith("   "):
            name = s.strip().rstrip(":")
            if name and " " not in name:
                gate["users"].append(name)
                current = name
        elif current and s.strip().startswith("email:"):
            gate["emails"][current] = s.split("email:", 1)[1].strip()
db = os.path.join(os.path.expanduser("~"), "gimle", "gate", "config", "db.sqlite3")
if os.path.exists(db):
    try:
        con = sqlite3.connect("file:%s?mode=ro" % db, uri=True)
        cur = con.cursor()
        rows = list(cur.execute(
            "select username, min(time), max(time), count(*) from authentication_logs "
            "where successful=1 and username <> '' group by username"))
        for user, first, last, count in rows:
            ips_seen = sorted({row[0] for row in con.execute(
                "select remote_ip from authentication_logs where username=? and successful=1", (user,))})
            gate["logins"][user] = {"ok": count, "first": first[:19], "last": last[:19], "ips": ips_seen}
        gate["totp"] = cur.execute("select count(*) from totp_configurations").fetchone()[0]
        gate["webauthn"] = cur.execute("select count(*) from webauthn_users").fetchone()[0]
        gate["state"] = "ok"
    except Exception as exc:
        gate["state"] = "unread: %s" % exc
out["gate"] = gate

# ---- the Board (Plane) ---------------------------------------------------------------------
plane = {"users": [], "members": [], "state": "unread"}
env = run(["docker", "inspect", "plane-selfhost-plane-db-1", "--format",
           "{{range .Config.Env}}{{println .}}{{end}}"])
pw = ""
for line in env.stdout.splitlines():
    if line.startswith("POSTGRES_PASSWORD="):
        pw = line.split("=", 1)[1]
if pw:
    q = lambda sql: run(["docker", "exec", "-e", "PGPASSWORD=" + pw, "plane-selfhost-plane-db-1",
                         "psql", "-U", "plane", "-d", "plane", "-tAc", sql])
    r = q("select email, coalesce(last_login_time::text,''), is_active from users")
    if r.returncode == 0:
        plane["state"] = "ok"
        for row in r.stdout.strip().splitlines():
            if row.count("|") >= 2:
                email, last, active = row.split("|")[:3]
                plane["users"].append({"email": email, "last_login": last, "active": active == "t"})
    r = q("select w.name, u.email from workspace_members m join users u on u.id=m.member_id "
          "join workspaces w on w.id=m.workspace_id")
    if r.returncode == 0:
        for row in r.stdout.strip().splitlines():
            if "|" in row:
                ws, email = row.split("|", 1)
                plane["members"].append({"workspace": ws, "email": email})
out["plane"] = plane

# ---- Documents (AFFiNE) --------------------------------------------------------------------
affine = {"users": [], "state": "unread"}
r = run(["docker", "exec", "affine_postgres", "psql", "-U", "affine", "-d", "affine", "-tAc",
         "select email, created_at::date, coalesce(email_verified::text,''), disabled from users"])
if r.returncode == 0:
    affine["state"] = "ok"
    for row in r.stdout.strip().splitlines():
        parts = row.split("|")
        if len(parts) >= 4:
            affine["users"].append({"email": parts[0], "created": parts[1],
                                    "verified": parts[2][:10], "disabled": parts[3] == "t"})
out["affine"] = affine

# ---- Code (Forgejo) ------------------------------------------------------------------------
forge = {"users": [], "state": "unread"}
try:
    with open(os.path.expanduser("~/.config/forgejo/db-password")) as handle:
        fpw = handle.read().strip()
    dsn = "postgresql://forgejo:%s@127.0.0.1:5432/forgejo" % fpw
    r = run(["psql", dsn, "-tAc",
             "select name, email, to_timestamp(created_unix)::date, "
             "to_timestamp(nullif(last_login_unix,0))::date, is_admin, is_active from \"user\""])
    if r.returncode == 0:
        forge["state"] = "ok"
        for row in r.stdout.strip().splitlines():
            parts = row.split("|")
            if len(parts) >= 6:
                forge["users"].append({"name": parts[0], "email": parts[1], "created": parts[2],
                                       "last_login": parts[3], "admin": parts[4] == "t",
                                       "active": parts[5] == "t"})
    r = run(["psql", dsn, "-tAc",
             "select u.name, count(k.id) from \"user\" u left join public_key k on k.owner_id=u.id "
             "group by u.name"])
    if r.returncode == 0:
        keys = {}
        for row in r.stdout.strip().splitlines():
            if "|" in row:
                name, count = row.split("|", 1)
                keys[name] = int(count or 0)
        for user in forge["users"]:
            user["keys"] = keys.get(user["name"], 0)
except Exception as exc:
    forge["state"] = "unread: %s" % exc
out["forge"] = forge

# ---- the shell -----------------------------------------------------------------------------
shell = {"accounts": [], "state": "ok"}
try:
    with open("/etc/passwd") as handle:
        for line in handle:
            parts = line.strip().split(":")
            if len(parts) >= 7 and parts[6] not in ("/sbin/nologin", "/usr/sbin/nologin", "/bin/false") \
                    and not parts[0].startswith("nixbld"):
                shell["accounts"].append({"user": parts[0], "home": parts[5]})
    r = run(["lastlog"])
    last = {}
    if r.returncode == 0:
        for line in r.stdout.splitlines()[1:]:
            cols = line.split()
            if cols:
                last[cols[0]] = "never" if "Never logged in" in line else " ".join(cols[-4:])
    for account in shell["accounts"]:
        account["last_login"] = last.get(account["user"], "unknown")
except Exception as exc:
    shell["state"] = "unread: %s" % exc
out["shell"] = shell

print(json.dumps(out))
'''


def register_path():
    """The register lives in the hoard; the hoard is resolved by its one door, never guessed."""
    home = os.environ.get("YMIR_HOME", "")
    if not home:
        door = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "bin", "vault", "hodd.sh")
        try:
            home = subprocess.run(["bash", door, "path"], capture_output=True, text=True, check=True).stdout.strip()
        except Exception:
            home = ""
    if not home:
        sys.exit("collab: no hoard — set YMIR_HOME or make bin/vault/hodd.sh path answer")
    return os.path.join(home, "hodd", "data", "collaboration.yaml")


def measure(host):
    try:
        done = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, "python3", "-"],
                              input=REMOTE, capture_output=True, text=True, timeout=180)
    except Exception as exc:
        return {"state": "unable", "reason": str(exc)}
    if done.returncode != 0:
        reason = (done.stderr or "").strip().splitlines()
        return {"state": "unable", "reason": reason[-1] if reason else "ssh exited %d" % done.returncode}
    try:
        measured = json.loads(done.stdout)
    except Exception as exc:
        return {"state": "unable", "reason": "unreadable answer: %s" % exc}
    measured["state"] = "ok"
    return measured


def classify(ip, house_ips):
    if ip in ("127.0.0.1", "::1"):
        return "loopback"
    if ip in house_ips:
        return "house"
    return "remote"


def surface_states(person, measured):
    """One short line per surface, and the list of activity events with an address class."""
    accounts = person.get("accounts") or {}
    gate = measured.get("gate") or {}
    plane = measured.get("plane") or {}
    affine = measured.get("affine") or {}
    forge = measured.get("forge") or {}
    shell = measured.get("shell") or {}
    house_ips = measured.get("house_ips") or []
    cells, events = {}, []

    name = accounts.get("gate")
    if not name:
        cells["gate"] = "—"
    elif gate.get("state") != "ok":
        cells["gate"] = "unread"
    elif name not in gate.get("users", []):
        cells["gate"] = "absent"
    else:
        login = (gate.get("logins") or {}).get(name)
        if not login:
            cells["gate"] = "no sign-in"
        else:
            classes = sorted({classify(ip, house_ips) for ip in login.get("ips", [])})
            cells["gate"] = "%s (%s)" % (login["last"][:10], "+".join(classes))
            events.append({"surface": "gate", "when": login["last"][:10], "class": "+".join(classes)})

    email = accounts.get("plane")
    if not email:
        cells["plane"] = "—"
    elif plane.get("state") != "ok":
        cells["plane"] = "unread"
    else:
        match = next((u for u in plane.get("users", []) if u["email"] == email), None)
        if not match:
            cells["plane"] = "absent"
        elif not match.get("last_login"):
            cells["plane"] = "never"
        else:
            cells["plane"] = match["last_login"][:10]
            events.append({"surface": "plane", "when": match["last_login"][:10], "class": "unknown"})

    email = accounts.get("affine")
    if not email:
        cells["documents"] = "—"
    elif affine.get("state") != "ok":
        cells["documents"] = "unread"
    else:
        match = next((u for u in affine.get("users", []) if u["email"] == email), None)
        cells["documents"] = "created %s" % match["created"] if match else "absent"

    name = accounts.get("forge")
    if not name:
        cells["forge"] = "—"
    elif forge.get("state") != "ok":
        cells["forge"] = "unread"
    else:
        match = next((u for u in forge.get("users", []) if u["name"] == name), None)
        if not match:
            cells["forge"] = "absent"
        else:
            cells["forge"] = match["last_login"] or "never"
            if match.get("last_login"):
                events.append({"surface": "forge", "when": match["last_login"], "class": "unknown"})
            if not match.get("active"):
                cells["forge"] += " (inactive)"

    name = accounts.get("shell")
    if not name:
        cells["shell"] = "—"
    elif shell.get("state") != "ok":
        cells["shell"] = "unread"
    else:
        match = next((u for u in shell.get("accounts", []) if u["user"] == name), None)
        if not match:
            cells["shell"] = "absent"
        else:
            cells["shell"] = "never" if match["last_login"] == "never" else match["last_login"]
            if match["last_login"] != "never":
                events.append({"surface": "shell", "when": match["last_login"], "class": "unknown"})

    verdict = "unentered"
    if events:
        verdict = "entered"
    if any(cell == "absent" for cell in cells.values()):
        verdict = "drift"
    # A person whose only surface is one this door cannot measure is not "unentered": they
    # collaborate somewhere we do not read, and saying otherwise would be a false absence.
    measured = {"gate", "plane", "affine", "forge", "shell"}
    elsewhere = sorted(key for key in (person.get("accounts") or {}) if key not in measured)
    if verdict == "unentered" and elsewhere:
        verdict = "elsewhere (%s)" % ", ".join(elsewhere)

    last_seen = max((event["when"] for event in events), default="—")
    return cells, events, last_seen, verdict


def gaps(measured, people):
    found = []
    gate = measured.get("gate") or {}
    if gate.get("state") == "ok" and not gate.get("totp") and not gate.get("webauthn"):
        found.append(("no second factor anywhere", "totp 0 · webauthn 0"))
    forge = measured.get("forge") or {}
    if forge.get("state") == "ok":
        with_keys = [u for u in forge.get("users", []) if u.get("keys")]
        if not with_keys:
            found.append(("no public key on the forge", "%d account(s), 0 keys" % len(forge.get("users", []))))
    for person in people:
        accounts = person.get("accounts") or {}
        gate_user = accounts.get("gate")
        if gate_user and gate.get("state") == "ok" and not (gate.get("emails") or {}).get(gate_user):
            found.append(("%s has no email on file" % person.get("name"), "the gate account carries none"))
    if measured.get("state") == "unable":
        found.append(("the surfaces could not be read", measured.get("reason", "")))
    return found


def main():
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--register", default=register_path())
    parser.add_argument("--from", dest="captured")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    if not os.path.isfile(args.register):
        sys.exit("collab: no register at %s — declare the people there, never in code" % args.register)
    with open(args.register, encoding="utf-8") as handle:
        register = yaml.safe_load(handle)

    if args.captured:
        with open(args.captured, encoding="utf-8") as handle:
            measured = json.load(handle)
        measured.setdefault("state", "ok")
    else:
        measured = measure(register.get("host") or "zerwizserver")

    people = register.get("people") or []
    rows = []
    for person in people:
        cells, events, last_seen, verdict = surface_states(person, measured)
        rows.append({"person": person.get("name"), "rung": person.get("rung"), "cells": cells,
                     "last_seen": last_seen, "verdict": verdict, "events": events,
                     "owed": person.get("owed") or [], "note": person.get("note")})

    if args.json:
        print(json.dumps({"measured": measured, "rows": rows, "gaps": gaps(measured, people)},
                         indent=2, default=str))
        return 0

    print("collab[%d]{person,rung,gate,board,documents,forge,shell,last_seen,verdict}:" % len(rows))
    for row in rows:
        print('  "%s","%s","%s","%s","%s","%s","%s","%s","%s"' % (
            row["person"], row["rung"] or "—",
            row["cells"]["gate"], row["cells"]["plane"], row["cells"]["documents"],
            row["cells"]["forge"], row["cells"]["shell"], row["last_seen"], row["verdict"]))

    found = gaps(measured, people)
    if found:
        print("gaps[%d]{gap,evidence}:" % len(found))
        for gap, evidence in found:
            print('  "%s","%s"' % (gap, evidence))

    remote = [row["person"] for row in rows
              if any(event["class"] == "remote" for event in row["events"])]
    print("summary[4]{field,value}:")
    print('  "host","%s"' % (register.get("host") or "?"))
    print('  "surfaces","%s"' % ("read" if measured.get("state") == "ok" else "unable — " + str(measured.get("reason", ""))))
    print('  "remote_sign_ins","%s"' % (", ".join(remote) if remote else "none recorded"))
    print('  "entered","%d of %d declared person(s)"' % (sum(1 for row in rows if row["verdict"] == "entered"), len(rows)))

    if args.strict and any(row["verdict"] == "drift" for row in rows):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
