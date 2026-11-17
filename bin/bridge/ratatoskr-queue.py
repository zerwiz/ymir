#!/usr/bin/env python3
"""ratatoskr-queue.py — ONE queue for the whole house: inbox → claimed → done.

WHY (plan 303 §5, §12.3 step 3): the house had four mailboxes in four formats — Sága's
wake queue, the hall's task board, the a2abridge inbox, and Ratatoskr's tasks — so no
agent knew where to look and a message that landed in the wrong one reached nobody.
There is one format now, the hall's own: **one Markdown file per task, and the claim is a
rename**.

    inbox/accept-…md     written by the sender
    claimed/accept-…md   renamed by the receiver — the rename IS the claim, and it is
                         atomic, so two receivers cannot both win one task
    done/accept-…md      carries the reply, so the record of the whole exchange is the
                         same file the whole way through

A task is **handed** when it is in `inbox/`. It is **delivered** only when its receiver
replies (RULES/49, 56), and the reply is what moves the file to `done/`. A green that only
shows a delivered file is not a pass, so nothing here ever claims delivery on its own.

The file:

    ---
    id: 1794849200-a1b2c3
    from: heimdall/w6R:p1
    to: heimdall/w6T:p1
    created: 2026-11-16T16:20:00Z
    state: sent
    claimed_by:
    claimed_at:
    answered_at:
    ---
    the text of the task

    ## reply
    the text of the answer

Queue root: `$YMIR_HOME/state/ratatoskr` (overridable with `RATATOSKR_QUEUE`). It is
private state, so it lives in the home and never in the tree.

Usage:
    ratatoskr-queue.py send <target> <text…>      → prints the task id
    ratatoskr-queue.py inbox [--for T] [--json]   → the tasks waiting
    ratatoskr-queue.py claim <id> [--by T]        → renames inbox → claimed
    ratatoskr-queue.py answer <id> <text…>        → claim (if still on the shelf) and reply, in one
    ratatoskr-queue.py reply <id> <text…>         → appends the reply, moves to done
    ratatoskr-queue.py show <id>                  → the whole file
    ratatoskr-queue.py count                      → one line per shelf

Exit: 0 done · 1 nothing to do / not found · 2 usage. A claim that loses the race exits
1 and says which shelf the file is on, so a receiver can read the truth rather than guess.
"""
import json
import os
import random
import re
import string
import subprocess
import sys
import time

VERSION = "1.0.0"
SHELVES = ("inbox", "claimed", "done")


def queue_root():
    env = os.environ.get("RATATOSKR_QUEUE")
    if env:
        return env
    home = os.environ.get("YMIR_HOME") or ""
    if not home:
        # One resolver, never a guessed path (Rule 07): the home answers, or we cannot work.
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        lib = os.path.join(root, "bin", "vault", "hoard-lib.sh")
        if os.path.exists(lib):
            try:
                p = subprocess.run(["bash", "-c", ". %s >/dev/null 2>&1 && ymir_home_root _h >/dev/null 2>&1 && printf '%%s' \"$_h\"" % lib],
                                   capture_output=True, text=True, timeout=20)
                home = (p.stdout or "").strip()
            except (OSError, subprocess.TimeoutExpired):
                home = ""
    if not home:
        sys.stderr.write("ratatoskr-queue: the home is unresolved — set YMIR_HOME or RATATOSKR_QUEUE\n")
        sys.exit(2)
    return os.path.join(home, "state", "ratatoskr")


def shelves(root):
    for s in SHELVES:
        os.makedirs(os.path.join(root, s), exist_ok=True)
    return root


def now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def new_id():
    stamp = int(time.time())
    tail = "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(6))
    return "%d-%s" % (stamp, tail)


HEADER = ("id", "from", "to", "created", "state", "claimed_by", "claimed_at", "answered_at")


def dump(meta, body, reply=""):
    lines = ["---"]
    for k in HEADER:
        lines.append("%s: %s" % (k, meta.get(k) or ""))
    lines += ["---", body.rstrip("\n"), ""]
    if reply:
        lines += ["## reply", reply.rstrip("\n"), ""]
    return "\n".join(lines)


def load(path):
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return None
    meta, body, reply = {}, "", ""
    lines = text.splitlines()
    if lines and lines[0].strip() == "---":
        end = None
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                end = i
                break
        if end is not None:
            for line in lines[1:end]:
                if ":" in line:
                    k, v = line.split(":", 1)
                    meta[k.strip()] = v.strip()
            lines = lines[end + 1:]
    body_lines, reply_lines, in_reply = [], [], False
    for line in lines:
        if line.strip() == "## reply":
            in_reply = True
            continue
        (reply_lines if in_reply else body_lines).append(line)
    body = "\n".join(body_lines).strip("\n")
    return {"meta": meta, "body": body, "reply": "\n".join(reply_lines).strip("\n"), "path": path}


def find(root, task_id):
    """The task by exact id or id prefix, on any shelf. One answer, whichever shelf holds it."""
    for shelf in SHELVES:
        d = os.path.join(root, shelf)
        try:
            names = sorted(os.listdir(d))
        except OSError:
            continue
        for name in names:
            if not name.endswith(".md"):
                continue
            if name[: -3] == task_id or name[: -3].startswith(task_id):
                return shelf, os.path.join(d, name)
    return "", ""


def here():
    """The sender's own address, proved where the machine can prove it.

    A `herdr pane` from the environment is only a HINT (a child inherits its parent's id),
    so it is reported as the pane it claims and the target string carries the machine —
    never a silently wrong identity.
    """
    pane = (os.environ.get("HERDR_PANE_ID") or "").strip()
    machine = (os.environ.get("YMIR_MACHINE") or "").strip() or (subprocess.run(
        ["hostname"], capture_output=True, text=True).stdout.strip() or "?")
    return "%s/%s" % (machine, pane) if pane else machine


def cmd_send(root, target, text):
    if not target:
        sys.stderr.write("usage: ratatoskr send <target> <text…>\n")
        return 2
    if not text.strip():
        sys.stderr.write("ratatoskr-queue: a task with no text is not a task\n")
        return 2
    task_id = new_id()
    meta = {"id": task_id, "from": here(), "to": target, "created": now(), "state": "sent"}
    with open(os.path.join(root, "inbox", task_id + ".md"), "w", encoding="utf-8") as fh:
        fh.write(dump(meta, text))
    print(task_id)
    return 0


def cmd_claim(root, task_id, by):
    shelf, path = find(root, task_id)
    if not path:
        sys.stderr.write("ratatoskr-queue: no task %s on any shelf\n" % task_id)
        return 1
    if shelf != "inbox":
        sys.stderr.write("ratatoskr-queue: task %s is already on %s\n" % (task_id, shelf))
        return 1
    dest = os.path.join(root, "claimed", os.path.basename(path))
    try:
        # THE CLAIM IS THE RENAME. os.rename is atomic within a filesystem, so exactly one
        # receiver can win a task; the loser gets ENOENT and reads the truth from the shelf.
        os.rename(path, dest)
    except OSError as exc:
        sys.stderr.write("ratatoskr-queue: could not claim %s (%s)\n" % (task_id, exc))
        return 1
    task = load(dest)
    meta = task["meta"]
    meta["state"] = "claimed"
    meta["claimed_by"] = by or here()
    meta["claimed_at"] = now()
    with open(dest, "w", encoding="utf-8") as fh:
        fh.write(dump(meta, task["body"], task["reply"]))
    print(dest)
    return 0


def cmd_reply(root, task_id, text):
    shelf, path = find(root, task_id)
    if not path:
        sys.stderr.write("ratatoskr-queue: no task %s on any shelf\n" % task_id)
        return 1
    if not text.strip():
        sys.stderr.write("ratatoskr-queue: an empty reply is not an answer\n")
        return 2
    task = load(path)
    meta = task["meta"]
    meta["answered_at"] = now()
    meta["state"] = "done"
    meta.setdefault("claimed_by", meta.get("claimed_by") or here())
    meta.setdefault("claimed_at", meta.get("claimed_at") or now())
    dest = os.path.join(root, "done", os.path.basename(path))
    with open(dest, "w", encoding="utf-8") as fh:
        fh.write(dump(meta, task["body"], text))
    if os.path.abspath(dest) != os.path.abspath(path):
        try:
            os.unlink(path)
        except OSError:
            pass
    print(dest)
    return 0


def normalize(addr):
    """An address is `machine/pane` or `herdr:pane` or a bare pane; compare what it names.

    A relay asks `--for w1:p2` because that is all a pane id is on its own machine; the
    task may say `herdr:w1:p2` or `host-a/w1:p2`. The three name one pane, so they match.
    """
    a = (addr or "").strip()
    for prefix in ("herdr:", "hermes:"):
        if a.startswith(prefix):
            a = a[len(prefix):]
    return a


def same_target(to, want):
    a, b = normalize(to), normalize(want)
    if not b:
        return True
    if a == b:
        return True
    return a.split("/")[-1] == b.split("/")[-1] and ("/" in a or "/" in b)


def cmd_inbox(root, want, as_json):
    rows = []
    for shelf in SHELVES:
        d = os.path.join(root, shelf)
        try:
            names = sorted(os.listdir(d))
        except OSError:
            continue
        for name in names:
            if not name.endswith(".md"):
                continue
            task = load(os.path.join(d, name))
            if task is None:
                continue
            meta = task["meta"]
            if want and not same_target(meta.get("to") or "", want):
                continue
            rows.append({"shelf": shelf, "id": meta.get("id") or name[:-3],
                         "from": meta.get("from") or "", "to": meta.get("to") or "",
                         "state": meta.get("state") or "", "created": meta.get("created") or "",
                         "body": task["body"][:200], "reply": task["reply"][:200]})
    rows.sort(key=lambda r: r["created"])
    if as_json:
        print(json.dumps(rows, indent=2))
        return 0
    print("queue[%d]{shelf,id,from,to,state,created}:" % len(rows))
    for r in rows:
        print('  "%s","%s","%s","%s","%s","%s"' % (
            r["shelf"], r["id"], r["from"].replace('"', "'"),
            r["to"].replace('"', "'"), r["state"], r["created"]))
    return 0 if rows else 1


def cmd_show(root, task_id):
    shelf, path = find(root, task_id)
    if not path:
        sys.stderr.write("ratatoskr-queue: no task %s on any shelf\n" % task_id)
        return 1
    sys.stdout.write(open(path, encoding="utf-8").read())
    return 0


def cmd_count(root):
    parts = []
    for shelf in SHELVES:
        try:
            parts.append("%s=%d" % (shelf, len([n for n in os.listdir(os.path.join(root, shelf))
                                                if n.endswith(".md")])))
        except OSError:
            parts.append("%s=0" % shelf)
    print(" ".join(parts))
    return 0


def flag(argv, name, default=""):
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        sys.stderr.write(__doc__)
        return 0 if argv else 2
    action, rest = argv[0], argv[1:]
    rest = [a for a in rest if a not in ("--json",)]
    root = shelves(queue_root())

    if action == "send":
        if not rest:
            sys.stderr.write("usage: ratatoskr send <target> <text…>\n")
            return 2
        return cmd_send(root, rest[0], " ".join(rest[1:]))
    if action == "claim":
        if not rest:
            sys.stderr.write("usage: ratatoskr claim <id> [--by TARGET]\n")
            return 2
        return cmd_claim(root, rest[0], flag(rest, "--by", ""))
    if action == "reply":
        if len(rest) < 2:
            sys.stderr.write("usage: ratatoskr reply <id> <text…>\n")
            return 2
        return cmd_reply(root, rest[0], " ".join(rest[1:]))
    if action == "answer":
        # ONE command for the receiver: claim it if it is still on the shelf, then reply.
        # Two commands is one too many for an agent woken mid-work, and a claim that is
        # already ours must not fail the answer.
        if len(rest) < 2:
            sys.stderr.write("usage: ratatoskr answer <id> <text…>\n")
            return 2
        task_id, text = rest[0], " ".join(rest[1:])
        shelf, _path = find(root, task_id)
        if shelf == "inbox":
            cmd_claim(root, task_id, "")
        return cmd_reply(root, task_id, text)
    if action in ("inbox", "list"):
        return cmd_inbox(root, flag(rest, "--for", ""), "--json" in argv)
    if action == "show":
        return cmd_show(root, rest[0]) if rest else 2
    if action == "count":
        return cmd_count(root)
    sys.stderr.write("ratatoskr-queue: unknown action %s\n" % action)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
