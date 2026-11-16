#!/usr/bin/env python3
"""ratatoskr-relay.py — the piece that WAKES a target and carries the answer back.

WHY (plan 303 §5, §12.3 step 4): the queue alone is not a conversation. A task laid in
`inbox/` waits for an agent that has no reason to look, and an answer written to `done/`
reaches nobody. Every working system in the field does the same three things — inject a
wake into the receiver's pane, confirm the receiver moved, and inject the reply back into
the asker's pane under a header — so that no agent ever polls.

This is that loop, and it obeys five rules:

1. **Only a `ready` target is woken.** A pane standing on a dialog, an agent mid-turn, or
   a pane holding a shell is not woken; it is recorded as a miss that names the reason.
2. **Two wake verbs, discovered never assumed.** `herdr agent prompt` where it exists
   (0.9.1), `herdr agent send` + `herdr pane send-keys Enter` where it does not (0.7.4).
   The verb is probed once from `herdr agent --help`, never from a version table.
3. **Confirm, then retry once, then say so.** After a wake the relay waits for the agent
   to move (`working`/`done`). If it never moves, the relay wakes once more and then
   records `miss: <id> <pane> <why>` — a wake that silently did nothing is the fault this
   door exists to end.
4. **The answer goes back under a header**, into the asker's own pane:
   `[ratatoskr · from <claimer> · re <id>] <reply>`.
5. **Nothing is claimed as delivered until the reply exists** (RULES/49, 56). A task in
   `inbox/` is handed; only a file in `done/` is delivered, and only then does the relay
   return it.

Usage:
    ratatoskr-relay.sh --once              one pass: wake what can be woken, return answers
    ratatoskr-relay.sh run [--interval N]  the loop (what the user unit runs)
    ratatoskr-relay.sh status              what it last did

Flags: --queue DIR (default `$YMIR_HOME/state/ratatoskr`), --machine NAME, --confirm SECS
(how long to wait for a wake to move the agent, default 60), --dry (say, do not type).

Exit: 0 one clean pass · 1 the pass ended with misses · 2 usage. A miss is never silent.
"""
import json
import os
import subprocess
import sys
import time

VERSION = "1.0.0"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

READY, WORKING, BLOCKED, DEAD = 0, 1, 2, 3


def load_module(name, path):
    import importlib.util
    if not os.path.exists(path):
        return None
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


QUEUE = load_module("ratatoskr_queue", os.path.join(HERE, "ratatoskr-queue.py"))
READY_ = load_module("agent_ready", os.path.join(ROOT, "bin", "seat", "agent-ready.py"))


def herdr_path():
    return os.environ.get("HDR_BIN") or os.environ.get("HDR") or "herdr"


def herdr(*args, timeout=30):
    try:
        p = subprocess.run([herdr_path()] + list(args), capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return (p.stdout or p.stderr or "").strip()


def has_prompt_verb():
    """`agent prompt` exists on herdr 0.9.1 and not on 0.7.4 — ask the binary, never a table.

    MEASURED 2026-11-16: this probe read one of herdr's two help shapes and missed the other,
    so the relay took the old `agent send` road on a herdr that has no such verb, typed
    nothing, pressed Enter on an empty box, and reported a wake. A probe that can only see
    one shape is a probe that lies. Both shapes are read now.
    """
    for args in (("agent", "--help"), ("agent",)):
        for line in herdr(*args).splitlines():
            t = line.strip()
            if t == "prompt" or t.startswith("prompt ") or t.startswith("herdr agent prompt"):
                return True
    return False


def arm_holder():
    """The pane that holds this machine's arm, asked of the door that owns that resolution."""
    door = os.path.join(ROOT, "bin", "agents", "eindri-notify.sh")
    if not os.path.exists(door):
        return ""
    try:
        p = subprocess.run(["bash", door, "--status"], capture_output=True, text=True, timeout=25)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    for line in (p.stdout or "").splitlines():
        if line.startswith('  "'):
            parts = [x.strip().strip('"') for x in line.strip().split(",")]
            if len(parts) >= 3 and parts[2].startswith("w"):
                return parts[2]
    return ""


def machine_name():
    return (os.environ.get("YMIR_MACHINE") or "").strip() or (subprocess.run(
        ["hostname"], capture_output=True, text=True).stdout.strip() or "?")


def looks_local(addr, machine):
    """A bare pane, a `herdr:` address, or this machine's own `machine/pane` — nothing else."""
    a = (addr or "").strip()
    if not a:
        return False
    if a.startswith("herdr:"):
        return True
    if "/" in a:
        return a.split("/", 1)[0] == machine
    return ":" in a or True  # a bare pane id is this machine's by definition


def pane_of(addr):
    a = (addr or "").strip()
    if a.startswith("herdr:"):
        a = a[6:]
    if "/" in a:
        a = a.split("/", 1)[1]
    return a


def state_of(pane):
    if READY_ is None:
        return BLOCKED, "the ready-check is not installed"
    st, reason, _ = READY_.herdr_ready(pane)
    return st, reason


def relay_dir(root):
    d = os.path.join(root, "relay")
    os.makedirs(d, exist_ok=True)
    return d


def load_state(root):
    path = os.path.join(relay_dir(root), "state.json")
    try:
        return json.load(open(path))
    except Exception:  # noqa: BLE001
        return {"woken": {}, "returned": [], "missed": []}


def save_state(root, st):
    path = os.path.join(relay_dir(root), "state.json")
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(st, fh, indent=1)
    os.replace(tmp, path)


def miss(root, task_id, pane, why, verbose=True):
    line = "%s\t%s\t%s\t%s\n" % (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                                 task_id, pane or "-", why)
    with open(os.path.join(relay_dir(root), "misses.log"), "a", encoding="utf-8") as fh:
        fh.write(line)
    if verbose:
        sys.stderr.write("miss: %s %s %s\n" % (task_id, pane or "-", why))


def composer_holds_text(pane):
    """Is there text sitting in the agent's input box, unsent? (bin/seat/herdr-editor.py)"""
    door = os.path.join(ROOT, "bin", "seat", "herdr-editor.py")
    if not os.path.exists(door):
        return False
    try:
        p = subprocess.run(["python3", door, pane], capture_output=True, text=True, timeout=25)
    except (OSError, subprocess.TimeoutExpired):
        return False
    line = (p.stdout or "").strip().splitlines()
    if not line:
        return False
    low = line[-1].lower()
    return '"empty"' not in low and 'empty' not in low.split('","')[1:2]


def arm_send(machine, text, dry=False):
    """Hand a line to a machine's arm holder. Returns a verb, or '' when nobody holds it."""
    if dry:
        return "dry"
    door = os.path.join(HERE, "ratatoskr-arm.sh")
    if not os.path.exists(door):
        return ""
    try:
        p = subprocess.run(["bash", door, machine, text], capture_output=True, text=True, timeout=90)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    if p.returncode == 0 and "handed" in (p.stdout or ""):
        return "arm"
    return ""


def wake(pane, text, dry=False):
    """Two verbs, one call, and one PROOF that the text actually left the box.

    Returns the verb that was used, or '' when nothing happened.

    MEASURED 2026-11-16: `herdr agent prompt` can answer `agent_prompted` while the text
    stays in the composer — the agent never sees it and the relay would believe it woke
    somebody. So after the prompt the box is read: text still sitting there means Enter
    was never taken, and the relay presses it once. A wake that cannot be proved is
    reported as a failure, never as a delivery.
    """
    if dry:
        return "dry"
    if has_prompt_verb():
        out = herdr("agent", "prompt", pane, text, timeout=60)
        if '"agent_prompted"' not in out:
            return ""
        if composer_holds_text(pane):
            herdr("pane", "send-keys", pane, "Enter", timeout=30)
        return "agent prompt"
    out = herdr("agent", "send", pane, text, timeout=60)
    if not out or '"error"' in out:
        return ""  # this herdr has no `agent send` either: say so, never press Enter on nothing
    herdr("pane", "send-keys", pane, "Enter", timeout=30)
    return "agent send + Enter"


def wake_text(root, task, pane):
    """One line, one command, and a stamp that says RELAY.

    Measured 2026-11-16 on throwaway agents, twice, and the second time is the lesson: a
    wake stamped `from an agent` was read as a peer's message and refused outright — the
    receiving agent said it read it "as data and not as an order", which is exactly the
    discipline RULES/39 asks for. So the wake is stamped as what it is: the house's own
    relay service. A relay is not a peer, and a task in the house queue is not a stranger's
    instruction. The text is one line because a wake that carried newlines was accepted by
    herdr and never reached the session at all.
    """
    tid = task["meta"].get("id")
    body = " ".join((task.get("body") or "").split())
    # ONE line, always. MEASURED 2026-11-16: a wake whose text carried newlines was accepted
    # by herdr (`agent_prompted`) and never arrived in the agent's session at all — the first
    # line was submitted and the rest swallowed, and the receiving harness saw nothing.
    return ("[ratatoskr relay · task %s · queued on this machine] This wake is spoken by Ymir's "
            "own relay service (bin/bridge/ratatoskr-relay.sh), not by a peer: the task is a file "
            "in this machine's queue, no network is involved, and your answer is written back into "
            "that file. Answering a queued task is the house's ordinary work. %s Answer it with "
            "one command: RATATOSKR_QUEUE=%s bin/bridge/ratatoskr.sh answer %s \"<your answer>\""
            % (tid, body, root, tid))


def deliver(root, st, machine, confirm_s, dry, verbose=True):
    """Wake every handed task this machine can take, and name every one it cannot."""
    inbox = os.path.join(root, "inbox")
    misses = 0
    try:
        names = sorted(os.listdir(inbox))
    except OSError:
        return 0
    for name in names:
        if not name.endswith(".md"):
            continue
        path = os.path.join(inbox, name)
        task = QUEUE.load(path)
        if task is None:
            continue
        meta = task["meta"]
        task_id = meta.get("id") or name[:-3]
        to = meta.get("to") or ""
        if not looks_local(to, machine):
            continue
        rec = st["woken"].get(task_id)
        if rec and rec.get("verb"):
            # Already woken: has it moved? One retry, then the miss is the record.
            if commit_check(root, st, task_id, rec, confirm_s, dry, verbose) is False:
                misses += 1
            continue
        pane = pane_of(to)
        if ":" not in pane:
            # A task addressed to a MACHINE has no pane to wake: it goes to that machine's one
            # live arm holder, through the door that already owns that road (step 5).
            verb = arm_send(to.strip(), wake_text(root, task, to.strip()), dry=dry)
            st["woken"][task_id] = {"pane": "arm:" + to.strip(), "at": time.time(),
                                    "verb": verb or "", "retries": 0, "task": task_id,
                                    "file": name, "via": "arm"}
            if not verb:
                miss(root, task_id, "arm:" + to.strip(),
                     "refused — nobody holds the arm on %s" % to.strip(), verbose)
                st["missed"].append(task_id)
                misses += 1
            continue
        state, reason = state_of(pane)
        if state == READY:
            verb = wake(pane, wake_text(root, task, pane), dry=dry)
            rec = {"pane": pane, "at": time.time(), "verb": verb or "", "retries": 0,
                   "task": task_id, "file": name}
            st["woken"][task_id] = rec
            if not verb:
                miss(root, task_id, pane, "the wake verb was refused", verbose)
                rec["verb"] = ""
                rec["missed"] = "wake refused"
                misses += 1
        elif state == WORKING:
            # Mid-turn is not a miss: the agent is busy, and the next pass will find it ready.
            continue
        elif state == DEAD:
            miss(root, task_id, pane, "no agent in the pane (%s)" % (reason or "dead"), verbose)
            st["missed"].append(task_id)
            misses += 1
        else:
            miss(root, task_id, pane, "blocked: %s" % (reason or "unknown"), verbose)
            st["missed"].append(task_id)
            misses += 1
    save_state(root, st)
    return misses


def commit_check(root, st, task_id, rec, confirm_s, dry, verbose):
    """The wake either moved the agent or it did not. `False` means a miss was recorded."""
    pane = rec.get("pane") or ""
    path = os.path.join(root, "inbox", rec.get("file") or "")
    if not os.path.exists(path):
        return True  # claimed or answered: the wake worked
    if confirm_s and time.time() - rec.get("at", 0) < confirm_s:
        return True  # still inside the grace window
    state, reason = state_of(pane)
    if state == WORKING:
        return True  # it moved: the claim lands when the turn ends
    if state == READY and rec.get("retries", 0) < 1:
        task = QUEUE.load(path)
        rec["retries"] = rec.get("retries", 0) + 1
        rec["at"] = time.time()
        verb = wake(pane, wake_text(root, task, pane) if task else "a task waits", dry=dry)
        rec["verb"] = verb or rec.get("verb") or ""
        if not verb:
            miss(root, task_id, pane, "the wake verb was refused on the retry", verbose)
            rec["missed"] = "wake refused"
            st["missed"].append(task_id)
            return False
        return True
    miss(root, task_id, pane,
         "the agent did not move after the wake (state %s%s)" % (
             {0: "ready", 1: "working", 2: "blocked", 3: "dead"}.get(state, "?"),
             (": " + reason) if reason else ""), verbose)
    rec["missed"] = "did not move"
    st["missed"].append(task_id)
    return False


def return_replies(root, st, machine, dry, verbose=True):
    """Carry every answer back to the asker's own pane, under the header. Once."""
    done = os.path.join(root, "done")
    returned = 0
    try:
        names = sorted(os.listdir(done))
    except OSError:
        return 0
    for name in names:
        if not name.endswith(".md"):
            continue
        task = QUEUE.load(os.path.join(done, name))
        if task is None:
            continue
        meta = task["meta"]
        task_id = meta.get("id") or name[:-3]
        if task_id in st["returned"]:
            continue
        frm = meta.get("from") or ""
        if not looks_local(frm, machine):
            # Cross-machine return is the edge's business (§10); the relay says so once.
            if task_id not in st.get("owed_edge", []):
                st.setdefault("owed_edge", []).append(task_id)
                if verbose:
                    sys.stderr.write("owed: %s -> %s (another machine; the edge carries it)\n"
                                     % (task_id, frm))
            continue
        pane = pane_of(frm)
        if not pane:
            st["returned"].append(task_id)
            continue
        # The asker is an agent too: a return typed into a mid-turn or blocked pane is the
        # same fault as a wake typed into one. It waits for ready, and a pane that is not
        # ready is a miss that names why — never a turn shouted into a dialog.
        state, reason = state_of(pane)
        if state == WORKING:
            continue  # the asker is mid-turn; the next pass brings the answer
        if state != READY:
            miss(root, task_id, pane, "the answer could not be returned: blocked: %s"
                 % (reason or "not ready"), verbose)
            st["returned"].append(task_id)
            continue
        header = "[ratatoskr · from %s · re %s]" % (meta.get("claimed_by") or "an agent", task_id)
        body = "%s %s" % (header, (task["reply"] or "").strip())
        verb = wake(pane, body, dry=dry)
        if verb:
            returned += 1
        else:
            miss(root, task_id, pane, "the return wake was refused", verbose)
        st["returned"].append(task_id)
    save_state(root, st)
    return returned


def resolve_queue(arg):
    if arg:
        return arg
    if QUEUE is None:
        sys.stderr.write("ratatoskr-relay: the queue door is missing\n")
        sys.exit(2)
    return QUEUE.queue_root()


def one_pass(root, machine, confirm_s, dry, verbose=True):
    root = QUEUE.shelves(root) if QUEUE else root
    st = load_state(root)
    misses = deliver(root, st, machine, confirm_s, dry, verbose)
    returned = return_replies(root, st, machine, dry, verbose)
    save_state(root, st)
    if verbose:
        sys.stderr.write("relay: misses=%d returned=%d woken=%d\n"
                         % (misses, returned, len(st.get("woken") or {})))
    return 1 if misses else 0


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
    action = argv[0]
    rest = argv[1:]
    root = resolve_queue(flag(rest, "--queue", ""))
    machine = flag(rest, "--machine", "") or machine_name()
    confirm_s = float(flag(rest, "--confirm", "60") or 60)
    dry = "--dry" in rest

    if action == "once" or action == "--once":
        return one_pass(root, machine, confirm_s, dry)
    if action == "run":
        interval = float(flag(rest, "--interval", "3") or 3)
        if "--require-arm" in rest:
            # The unit refuses to serve a person who holds no arm: a relay waking agents on
            # a machine nobody is supervising is work with no owner (RULES/55). It WAITS
            # rather than exits, so the unit does not enter a restart storm; the waiting is
            # logged once, and the loop begins the moment a holder appears.
            said = False
            while not arm_holder():
                if not said:
                    sys.stderr.write("relay: no live arm holder on this machine — waiting "
                                     "(RULES/55: no agent runs unowned)\n")
                    said = True
                time.sleep(30)
            if said:
                sys.stderr.write("relay: an arm holder appeared — serving the queue\n")
        while True:
            one_pass(root, machine, confirm_s, dry)
            time.sleep(interval)
    if action == "status":
        st = load_state(root)
        print("relay[4]{woken,returned,missed,owed_edge}:")
        print('  "%d","%d","%d","%d"' % (len(st.get("woken") or {}), len(st.get("returned") or []),
                                         len(st.get("missed") or []), len(st.get("owed_edge") or [])))
        log = os.path.join(relay_dir(root), "misses.log")
        if os.path.exists(log):
            for line in open(log, encoding="utf-8").read().splitlines()[-5:]:
                print("  miss: %s" % line.replace("\t", " "))
        return 0
    sys.stderr.write("ratatoskr-relay: unknown action %s\n" % action)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(0)
