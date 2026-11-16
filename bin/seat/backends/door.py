#!/usr/bin/env python3
"""door.py — the six verbs, dispatched through the one resolver.

    list | get | read | prompt | wait | explain <target> …

`recover` is the seventh door and it belongs to Hermes alone: it prints the lost input BEFORE
it discards anything, because a person's turn is not a worker's to throw away (plan 303 §13.5
9d). It refuses unless `--yes` follows the printed input, so nothing is discarded unseen.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import resolve as R                    # noqa: E402
from base import WORD, word            # noqa: E402

USAGE = __doc__


def flag(argv, name, default=""):
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default


def cmd_list(argv):
    rows = R.all_rows()
    print("backend[%d]{target,harness,state,pane,name}:" % len(rows))
    for r in rows:
        state = word(r.get("state", 0), r.get("reason") or "")
        print('  "%s","%s","%s","%s","%s"' % (
            r.get("target") or "?", r.get("harness") or "?", state,
            r.get("pane") or "-", (r.get("name") or "?").replace('"', "'")))
    return 0


def cmd_get(argv):
    t = argv[0] if argv else ""
    if not t:
        return 64
    b, canon = R.backend_for(t)
    state, reason, _detail = b.get(canon)
    print(word(state, reason))
    return state


def cmd_read(argv):
    t = argv[0] if argv else ""
    b, canon = R.backend_for(t)
    print(b.read(canon, int(flag(argv, "--lines", "40") or 40)))
    return 0


def cmd_prompt(argv):
    if len(argv) < 2:
        return 64
    t, text = argv[0], " ".join(argv[1:])
    b, canon = R.backend_for(t)
    state, reason, _d = b.get(canon)
    if state != 0:
        sys.stderr.write("backend: refused — %s is %s\n" % (t, word(state, reason)))
        return state or 2
    verb = b.prompt(canon, text)
    if not verb:
        sys.stderr.write("backend: the wake was refused by %s\n" % b.name)
        return 2
    print(verb)
    return 0


def cmd_wait(argv):
    t = argv[0] if argv else ""
    b, canon = R.backend_for(t)
    until = tuple((flag(argv, "--until", "working") or "working").split(","))
    ok = b.wait(canon, until=until, timeout=int(flag(argv, "--timeout", "60") or 60))
    print("waited" if ok else "timed out")
    return 0 if ok else 1


def cmd_explain(argv):
    t = argv[0] if argv else ""
    b, canon = R.backend_for(t)
    reason, recovery, detail = b.explain(canon)
    state, why, _d = b.get(canon)
    print("backend[1]{target,state,reason,recovery,detail}:")
    print('  "%s","%s","%s","%s","%s"' % (
        t, word(state, why), reason.replace('"', "'"),
        recovery.replace('"', "'"), (detail or "").replace('"', "'")))
    return 0


def cmd_recover(argv):
    """Hermes only: show what the paused session was carrying, THEN discard it — if asked."""
    t = argv[0] if argv else ""
    if not t:
        return 64
    if not t.startswith("hermes:"):
        sys.stderr.write("backend: recover is a hermes door — a herdr pane has no lost turn\n")
        return 64
    import hermes as H
    b = H.Hermes()
    canon = R.resolve(t)[1]
    row = b.find(b.resolve(canon))
    if row is None:
        sys.stderr.write("backend: no such session\n")
        return 3
    state, reason, _d = b.get(row["id"])
    lost = b.lost_input(row["id"])
    print("recover[1]{session,state,lost}:")
    print('  "%s","%s","%s"' % (row["id"][:24], word(state, reason), (lost or "(nothing readable)").replace('"', "'")))
    if "--yes" not in argv:
        print("\nNothing was discarded. Re-run with --yes to acknowledge the lost turn:\n"
              "  bin/seat/backend.sh recover %s --yes" % t)
        return 0
    import subprocess
    rc = subprocess.run([H.hermes_bin(), "sessions", "discard", row["id"], "--yes"],
                        capture_output=True, text=True).returncode
    print("discarded" if rc == 0 else "discard refused (exit %d)" % rc)
    return 0 if rc == 0 else 1


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        sys.stderr.write(USAGE)
        return 0 if argv else 64
    action, rest = argv[0], argv[1:]
    table = {"list": cmd_list, "get": cmd_get, "read": cmd_read, "prompt": cmd_prompt,
             "wait": cmd_wait, "explain": cmd_explain, "recover": cmd_recover}
    fn = table.get(action)
    if fn is None:
        sys.stderr.write("backend: unknown verb %s\n" % action)
        return 64
    return fn(rest)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
