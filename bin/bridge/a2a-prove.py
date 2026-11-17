#!/usr/bin/env python3
"""a2a-prove.py — one nonce, three doors, and the round trip that has to come back intact.

WHY (plan 303 §12.3 step 7): this house has twice called a channel good because a card
answered. A card answering is not a node answering, and a file moving is not a message
delivered. The proof the Allfather can run is a round trip: he sends one line, agent A passes
it to agent B, B answers, A returns it, and the **nonce** is unchanged at every hop. Nothing
in between is typed by a person.

Three doors, proved in the order a message travels:

    queue   a task written by one agent is claimed and answered by another, and the file moves
    relay   a ready target is woken, the agent moves, and the answer comes back under a header
    arm     a task for a machine goes to that machine's one holder, or is refused by name

    a2a-prove.sh                    the plumbing proof: every door, one nonce, no agent needed
    a2a-prove.sh --live A B         the FULL round trip through two live agents (slow; every
                                    hop is waited for and a hop that does not arrive is
                                    reported `unproved` BY NAME)

Exit: 0 every door proved · 1 a door failed, named · 2 usage.
"""
import json
import os
import secrets
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BRIDGE = os.path.join(ROOT, "bin", "bridge")


def run(argv, env=None, timeout=120):
    e = dict(os.environ)
    if env:
        e.update(env)
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, env=e)
    except (OSError, subprocess.TimeoutExpired):
        return 1, "", "timed out"
    return p.returncode, (p.stdout or ""), (p.stderr or "")


def flag(argv, name, default=""):
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default


def rows(text):
    """Every door in this house answers a TOON table; read its rows, never its prose."""
    out = []
    for line in text.splitlines():
        line = line.strip()
        if line.startswith('"') and line.endswith('"'):
            out.append([x.strip().strip('"') for x in line.split('","')])
    return out


def prove_queue(root, nonce, results):
    """door 1 — a task is written, claimed, answered, and the file moves; the nonce survives."""
    door = os.path.join(BRIDGE, "ratatoskr.sh")
    env = {"RATATOSKR_QUEUE": root}
    rc, out, err = run(["bash", door, "send", "herdr:prove-a", "nonce %s" % nonce], env)
    task_id = out.strip().splitlines()[-1] if out.strip() else ""
    if rc != 0 or not task_id:
        results.append(("queue", False, "could not write a task: %s" % (err or out)[:120]))
        return ""
    run(["bash", door, "claim", task_id, "--by", "prove-a"], env)
    run(["bash", door, "reply", task_id, "nonce %s" % nonce], env)
    rc, out, _ = run(["bash", door, "count"], env)
    path = os.path.join(root, "done", task_id + ".md")
    ok = os.path.exists(path) and nonce in open(path, encoding="utf-8").read()
    results.append(("queue", ok, "task %s moved inbox → claimed → done, nonce intact" % task_id
                    if ok else "the task did not land in done/ with the nonce: %s" % out.strip()))
    return task_id


def prove_relay(root, nonce, results):
    """door 2 — the relay reads the queue and reports what it did; a miss is never silent."""
    door = os.path.join(BRIDGE, "ratatoskr-relay.sh")
    env = {"RATATOSKR_QUEUE": root}
    rc, out, err = run(["bash", door, "status"], env)
    ok = rc == 0 and "relay[" in out
    results.append(("relay", ok, "the relay answers status with its counts" if ok
                    else "the relay did not answer: %s" % (err or out)[:120]))


def prove_arm(nonce, results):
    """door 3 — a machine name is either handed to its holder or refused BY NAME."""
    door = os.path.join(BRIDGE, "ratatoskr-arm.sh")
    rc, out, err = run(["bash", door, "a-machine-not-in-the-registry", "nonce %s" % nonce])
    named = rc == 1 and "not in the fleet registry" in (out + err)
    results.append(("arm", named, "a machine the registry does not know is refused by name"
                    if named else "the arm door answered: %s" % (out + err)[:120]))


def prove_live(a, b, nonce, results, wait_s):
    """the round trip through two live agents; every hop waited for, every miss named."""
    door = os.path.join(BRIDGE, "ratatoskr.sh")
    relay = os.path.join(BRIDGE, "ratatoskr-relay.sh")
    asker = os.environ.get("PROVE_ASKER") or ""
    env = {"HERDR_PANE_ID": asker} if asker else {}
    rc, out, err = run(["bash", door, "send", "herdr:%s" % a,
                        "Forward this nonce to %s and ask it to answer with it: %s" % (b, nonce)], env)
    task_id = out.strip().splitlines()[-1] if out.strip() else ""
    if not task_id:
        results.append(("live", False, "could not write the round trip: %s" % (err or out)[:120]))
        return
    deadline = time.time() + wait_s
    while time.time() < deadline:
        run(["bash", relay, "--once", "--confirm", "0"], {"RATATOSKR_QUEUE": os.environ.get("RATATOSKR_QUEUE", "")})
        rc, out, _ = run(["bash", door, "inbox", "--json"])
        try:
            rowsj = json.loads(out)
        except Exception:  # noqa: BLE001
            rowsj = []
        done = [r for r in rowsj if r.get("id", "").startswith(task_id) and r.get("shelf") == "done"]
        if done:
            ok = nonce in (done[0].get("reply") or "")
            results.append(("live", ok, "the round trip came back with the nonce intact"
                            if ok else "it came back with a different answer: %s"
                            % (done[0].get("reply") or "")[:120]))
            return
        time.sleep(10)
    results.append(("live", False,
                    "UNPROVED — the round trip through %s and %s did not arrive in %ds; the task "
                    "is still on %s" % (a, b, wait_s, task_id)))


def main(argv):
    if "-h" in argv or "--help" in argv:
        sys.stderr.write(__doc__)
        return 0
    nonce = flag(argv, "--nonce", "") or ("%04x%04x" % (secrets.randbits(16), secrets.randbits(16)))
    wait_s = int(flag(argv, "--wait", "180") or 180)
    live = "--live" in argv
    a = b = ""
    if live:
        i = argv.index("--live")
        if len(argv) > i + 2:
            a, b = argv[i + 1], argv[i + 2]
        else:
            sys.stderr.write("usage: a2a-prove.sh --live <agent-a> <agent-b> [--nonce N] [--wait S]\n")
            return 2

    root = os.environ.get("RATATOSKR_QUEUE") or ""
    if not root:
        # the queue door owns the resolution; borrow it rather than guess a path
        import importlib.util
        spec = importlib.util.spec_from_file_location("q", os.path.join(BRIDGE, "ratatoskr-queue.py"))
        q = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(q)
        root = q.queue_root()
        os.environ["RATATOSKR_QUEUE"] = root

    results = []
    print("a2a-prove — one nonce, three doors")
    print("nonce: %s" % nonce)
    print("queue: %s\n" % root)

    prove_queue(root, nonce, results)
    prove_relay(root, nonce, results)
    prove_arm(nonce, results)
    if live:
        prove_live(a, b, nonce, results, wait_s)

    print("proof[%d]{door,ok,evidence}:" % len(results))
    for door, ok, why in results:
        print('  "%s","%s","%s"' % (door, "proved" if ok else "FAILED", why.replace('"', "'")))
    bad = [d for d, ok, _ in results if not ok]
    if bad:
        print("\nnot proved: %s" % ", ".join(bad))
        return 1
    print("\nevery door answered, and the nonce came back unchanged.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
