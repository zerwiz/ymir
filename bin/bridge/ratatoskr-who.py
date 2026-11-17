#!/usr/bin/env python3
"""ratatoskr-who.py — the directory: which agents stand on which machine, and who holds the arm.

WHY (plan 303 §5, §12.3 step 2): the house's directories were opt-in. An agent existed
to a peer only after somebody ran an announce command by hand, and the one peer that
was announced outlived its agent — a stale bridge answering for a worktree that was
gone. `herdr agent list` has neither fault: it lists the panes that exist NOW, so a
dead pane vanishes from it by itself and there is no step to forget.

So the directory is herdr — on this machine, then on every machine the fleet registry
names, over that machine's own road. Nothing is announced and nothing is cached; a
machine that does not answer is a row saying so, never a row quietly dropped.

ONE VOCABULARY. A row's `state` is the same four words `bin/seat/agent-ready.sh`
answers with (`ready`, `working`, `blocked: <why>`, `dead`) so a relay can read a
remote row the way it reads a local one. On this machine the reason is read from
`herdr agent explain`; on a far machine herdr does not carry that call over the road,
so a blocked row there says `blocked: dialog` and names the machine that can say more.

Usage:
    ratatoskr.sh who [--local] [--json] [--machine NAME] [--no-arm]

Exit: 0 rows printed (a dark machine is a row, not a failure) · 1 herdr unreadable on
this machine · 2 usage.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

VERSION = "1.0.0"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

READY, WORKING, BLOCKED, DEAD = 0, 1, 2, 3
WORD = {READY: "ready", WORKING: "working", BLOCKED: "blocked", DEAD: "dead"}


def load_ready_module():
    """The one implementation of the vocabulary. A second copy would drift."""
    import importlib.util
    path = os.path.join(ROOT, "bin", "seat", "agent-ready.py")
    if not os.path.exists(path):
        return None
    spec = importlib.util.spec_from_file_location("agent_ready", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


READY_MOD = load_ready_module()


def herdr_path():
    return os.environ.get("HDR_BIN") or os.environ.get("HDR") or shutil.which("herdr") or "herdr"


def word(state, reason=""):
    return "%s: %s" % (WORD[state], reason) if state == BLOCKED and reason else WORD[state]


def state_of_row(a):
    """herdr's own status → the one vocabulary. Used where `agent explain` is not reachable."""
    status = (a.get("agent_status") or "").strip().lower()
    kind = (a.get("agent") or "").strip()
    ready_flag = a.get("interactive_ready")
    if not kind:
        return DEAD, "herdr names no agent"
    if status in ("working", "done"):
        return WORKING, ""
    if status == "blocked":
        return BLOCKED, "dialog"
    if ready_flag is False:
        return BLOCKED, "not at an input prompt"
    return READY, ""


# ── this machine ────────────────────────────────────────────────────────────────
def local_arm_pane():
    """The pane that holds the arm, asked of the door that already resolves it."""
    named = (os.environ.get("RATATOSKR_ARM_PANE") or "").strip()
    if named:
        # A machine (or a test) that already knows its arm pane names it here, so the
        # directory never re-implements the resolution eindri-notify.sh owns.
        return named
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


def local_rows(want_arm):
    raw = ""
    try:
        p = subprocess.run([herdr_path(), "agent", "list"], capture_output=True, text=True, timeout=25)
        raw = (p.stdout or p.stderr or "").strip()
    except (OSError, subprocess.TimeoutExpired):
        return None
    try:
        agents = (json.loads(raw).get("result") or {}).get("agents") or []
    except Exception:  # noqa: BLE001
        return None
    arm = local_arm_pane() if want_arm else ""
    rows = []
    for a in agents:
        pane = a.get("pane_id") or ""
        if READY_MOD is not None:
            state, reason, _detail = READY_MOD.herdr_ready(pane)
        else:
            state, reason = state_of_row(a)
        rows.append({
            "machine": HOST, "harness": (a.get("agent") or "?"), "pane": pane,
            "name": (a.get("name") or a.get("terminal_title_stripped") or a.get("agent") or "?"),
            "state": word(state, reason), "arm": "yes" if arm and pane == arm else "no",
            "road": "local",
        })
    return arm_miss(rows, arm)


# ── the fleet ───────────────────────────────────────────────────────────────────
FLEET_SNIPPET = r'''
H="$(command -v herdr || echo "$HOME/.local/bin/herdr")"
echo "@@AGENTS@@"
[ -x "$H" ] && "$H" agent list 2>/dev/null
echo
echo "@@ARM@@"
cd "$HOME/ymir" 2>/dev/null && bin/agents/eindri-notify.sh --status 2>/dev/null
echo "@@END@@"
'''


def fleet_hosts():
    home = os.environ.get("YMIR_HOME") or ""
    reg = os.path.join(home, "hodd", "data", "fleet.json") if home else ""
    if not reg or not os.path.exists(reg):
        return {}
    try:
        d = json.load(open(reg))
    except Exception:  # noqa: BLE001
        return {}
    out = {}
    for name, h in (d.get("hosts") or {}).items():
        tail = (h.get("tailnet") or "").strip()
        user = (h.get("user") or "").strip()
        if tail and user and name != HOST:
            out[name] = {"tailnet": tail, "user": user}
    return out


def ask_machine(name, h, want_arm):
    argv = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6",
            "-o", "StrictHostKeyChecking=accept-new",
            "%s@%s" % (h["user"], h["tailnet"]), FLEET_SNIPPET]
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=25)
    except (OSError, subprocess.TimeoutExpired):
        return [{"machine": name, "harness": "-", "pane": "-", "name": "-",
                 "state": word(DEAD), "arm": "-", "road": "dark: no answer in 25s"}]
    text = p.stdout or ""
    if "@@END@@" not in text:
        return [{"machine": name, "harness": "-", "pane": "-", "name": "-",
                 "state": word(DEAD), "arm": "-", "road": "dark: the road answered nothing"}]
    agents_raw = text.split("@@AGENTS@@", 1)[1].split("@@ARM@@", 1)[0].strip()
    arm_raw = text.split("@@ARM@@", 1)[1].split("@@END@@", 1)[0]
    arm = ""
    for line in arm_raw.splitlines():
        if line.startswith('  "'):
            parts = [x.strip().strip('"') for x in line.strip().split(",")]
            if len(parts) >= 3 and parts[2].startswith("w"):
                arm = parts[2]
                break
    try:
        agents = (json.loads(agents_raw).get("result") or {}).get("agents") or []
    except Exception:  # noqa: BLE001
        return [{"machine": name, "harness": "-", "pane": "-", "name": "-",
                 "state": word(DEAD), "arm": "-", "road": "dark: herdr is not installed there"}]
    rows = []
    for a in agents:
        pane = a.get("pane_id") or ""
        state, reason = state_of_row(a)
        rows.append({
            "machine": name, "harness": (a.get("agent") or "?"), "pane": pane,
            "name": (a.get("name") or a.get("terminal_title_stripped") or a.get("agent") or "?"),
            "state": word(state, reason),
            "arm": ("yes" if arm and pane == arm else ("no" if want_arm else "-")),
            "road": "tailnet",
        })
    if not rows:
        rows.append({"machine": name, "harness": "-", "pane": "-", "name": "-",
                     "state": word(DEAD), "arm": "-", "road": "no agent stands there"})
    return arm_miss(rows, arm, name)


def arm_miss(rows, arm, machine=None):
    """Name the arm pane when herdr does not list an agent in it.

    Measured 2026-11-16: the heart's arm holder names pane `w2:p3`, and herdr there
    lists no agent in it. That is a real miss — a wake sent to that pane reaches a
    shell — so the directory says it in a row of its own instead of leaving the arm
    column empty and looking healthy.
    """
    if not arm:
        return rows
    for r in rows:
        if r["pane"] == arm:
            return rows
    rows.append({
        "machine": machine or HOST, "harness": "-", "pane": arm, "name": "(the arm)",
        "state": word(DEAD), "arm": "yes",
        "road": "the arm pane holds no agent herdr lists",
    })
    return rows


HOST = (os.environ.get("YMIR_MACHINE") or subprocess.run(
    ["hostname"], capture_output=True, text=True).stdout.strip() or "?")


def main(argv):
    want_local = "--local" in argv
    want_json = "--json" in argv
    want_arm = "--no-arm" not in argv
    only = ""
    if "--machine" in argv:
        i = argv.index("--machine")
        if i + 1 < len(argv):
            only = argv[i + 1]
    if "-h" in argv or "--help" in argv:
        sys.stderr.write(__doc__)
        return 0

    rows = local_rows(want_arm)
    if rows is None:
        sys.stderr.write("ratatoskr-who: herdr did not answer on this machine\n")
        return 1
    # Hermes sessions have no pane, so they are rows here through the backend adapter
    # (plan 303 §14, step 9a): the same row shape, one vocabulary, and the state read from
    # the runtime's own admission rather than guessed from a title.
    try:
        import importlib.util
        bp = os.path.join(ROOT, "bin", "seat", "backends", "resolve.py")
        if os.path.exists(bp):
            spec = importlib.util.spec_from_file_location("backend_resolve", bp)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            for r in mod.backends()["hermes"].list():
                rows.append({"machine": HOST, "harness": "hermes", "pane": "-",
                             "name": (r.get("name") or "?"),
                             "state": word(r.get("state", 0), r.get("reason") or ""),
                             "arm": "no" if want_arm else "-", "road": "hermes session"})
    except Exception as exc:  # noqa: BLE001
        rows.append({"machine": HOST, "harness": "hermes", "pane": "-", "name": "?",
                     "state": word(DEAD), "arm": "-",
                     "road": "hermes unreadable (%s)" % str(exc)[:60]})

    if not want_local:
        hosts = fleet_hosts()
        if only:
            hosts = {k: v for k, v in hosts.items() if k == only}
        if hosts:
            with ThreadPoolExecutor(max_workers=len(hosts)) as pool:
                for part in pool.map(lambda kv: ask_machine(kv[0], kv[1], want_arm), hosts.items()):
                    rows.extend(part)
    if only:
        rows = [r for r in rows if r["machine"] == only]

    if want_json:
        print(json.dumps(rows, indent=2))
        return 0
    print("who[%d]{machine,harness,pane,name,state,arm,road}:" % len(rows))
    for r in rows:
        print('  "%s","%s","%s","%s","%s","%s","%s"' % (
            r["machine"], r["harness"], r["pane"], r["name"].replace('"', "'"),
            r["state"], r["arm"], r["road"]))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except BrokenPipeError:
        sys.exit(0)
