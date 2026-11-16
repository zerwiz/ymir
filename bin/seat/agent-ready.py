#!/usr/bin/env python3
"""agent-ready.py — is an agent READY for a turn, in one vocabulary, for both backends.

WHY (plan 303 §12.3 step 1, 2026-11-16): a relay that wakes an agent must first know
whether the agent can take a turn at all. herdr answers in its own words (`idle`,
`working`, `blocked`), Hermes answers in its own (`queued`, `unknown` admission), and
either can be standing on a dialog that would swallow the message — the folder-trust
prompt measured on two panes (`w4E:p1`, `w4E:p2`) being the one that cost the most.
Two vocabularies and a swallowed prompt is how a "delivered" message reaches nobody.

So there is ONE answer per target, and it is one of four:

    ready                 the target can take a turn now
    working               the target is mid-turn; a message will queue behind it
    blocked: <why>        the target exists but cannot take a turn, and this says why
    dead                  the target is not there

The reason after `blocked:` is not decoration — it is what a person quotes when they
ask why a message did not land. `blocked: trust prompt` and `blocked: lost turn, run
recover` are the two that matter today.

TARGETS

    <pane>                     a herdr pane (w6R:p1) — a bare target is herdr, so
                               nothing that already works changes shape
    herdr:<pane>               the same, said plainly
    hermes:<id-or-title>       a Hermes session (a `local-…` id prefix, or a title)

Usage:
    agent-ready.py TARGET [TARGET…] [--json]
    agent-ready.py --all [-[--json]]      every herdr agent and every Hermes session

With one target the answer alone is printed, so a caller can compare strings. With
several, each row is `<target>\t<answer>`. `--json` prints a list of
`{target, backend, state, reason, detail}`.

Exit: 0 ready · 1 working · 2 blocked · 3 dead · 64 usage · 65 the reader itself
failed. Several targets answer with the worst of them, which is the one that needs
a person.

The two readers are deliberately independent and each is small: `herdr agent get`
(this machine's panes) and `hermes sessions list` joined with the runtime's own
admissions table (this machine's Hermes sessions). Neither is guessed from a
version table, and neither invents a state it did not read.
"""
import json
import os
import shutil
import sqlite3
import subprocess
import sys

VERSION = "1.0.0"

# The vocabulary, in severity order. A relay reads `ready`; a person reads the reason.
READY, WORKING, BLOCKED, DEAD = 0, 1, 2, 3
WORD = {READY: "ready", WORKING: "working", BLOCKED: "blocked", DEAD: "dead"}

# Signatures of the dialog that swallows a first message. Matched case-insensitively
# against `herdr agent explain`'s own evidence text, because that text IS the screen.
TRUST_PROMPT = (
    "quick safety check",
    "yes, i trust this folder",
    "trust this folder",
    "do you trust the files in this folder",
    "trust the files in this folder",
)


def run(argv, timeout=25):
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    # herdr answers a present agent on stdout and a missing one on stderr; both are
    # JSON. Reading only one of them is how an empty pane came to look "unsure".
    for raw in (p.stdout, p.stderr):
        raw = (raw or "").strip()
        if raw:
            return raw
    return ""


def as_json(raw):
    try:
        return json.loads(raw)
    except Exception:  # noqa: BLE001
        return {}


def herdr_bin():
    return os.environ.get("HDR_BIN") or os.environ.get("HDR") or "herdr"


# ── herdr ────────────────────────────────────────────────────────────────────────
def herdr_get(pane):
    """The agent row, or the error herdr gave. `{}` when herdr could not be asked."""
    return as_json(run([herdr_bin(), "agent", "get", pane]))


def herdr_explain(pane):
    """herdr's answer for WHY it says what it says: rule name and the screen's evidence."""
    try:
        p = subprocess.run([herdr_bin(), "agent", "explain", pane],
                           capture_output=True, text=True, timeout=25)
    except (OSError, subprocess.TimeoutExpired):
        return "", ""
    text = p.stdout or ""
    rule, evidence = "", ""
    for line in text.splitlines():
        if line.startswith("rule: "):
            rule = line[6:].strip()
        elif line.startswith("evidence: "):
            evidence = line[10:].strip()
    return rule, evidence


def classify_dialog(rule, evidence):
    """A blocked pane is blocked on SOMETHING; name the one a person can act on."""
    hay = (evidence or "").lower()
    for sig in TRUST_PROMPT:
        if sig in hay:
            return "trust prompt"
    if rule:
        # herdr's own rule names the shape (`live_blocked_form`, `live_permission_form`).
        return "prompt (%s)" % rule.replace("live_", "").replace("_form", "")
    return "prompt"


def herdr_ready(pane):
    """(state, reason, detail) for one pane, read from herdr and never guessed."""
    row = herdr_get(pane)
    if not row:
        return BLOCKED, "herdr did not answer", ""
    err = (row.get("error") or {})
    if err.get("code") in ("agent_not_found", "pane_not_found"):
        return DEAD, "no agent in %s" % pane, err.get("code") or ""
    if err:
        return BLOCKED, "herdr error %s" % (err.get("code") or "?"), (err.get("message") or "")[:120]
    a = ((row.get("result") or {}).get("agent") or {})
    if not a:
        return BLOCKED, "herdr answered no agent", ""
    status = (a.get("agent_status") or "").strip().lower()
    kind = (a.get("agent") or "").strip()
    ready_flag = a.get("interactive_ready")
    detail = "agent=%s status=%s" % (kind or "?", status or "?")

    if status in ("working", "done"):
        # Both are PAST needing input: a message queues behind the turn, it is not lost.
        return WORKING, "", detail
    if status == "blocked":
        rule, evidence = herdr_explain(pane)
        return BLOCKED, classify_dialog(rule, evidence), detail
    if status == "idle":
        # An idle agent whose input box is not drawn is the measured launch fault
        # (plan 291 row 5), so `interactive_ready=False` is a block, not a ready.
        if ready_flag is False:
            return BLOCKED, "not at an input prompt", detail
        return READY, "", detail
    if not kind:
        return DEAD, "herdr names no agent", detail
    # herdr could not detect the harness; an agent with no detectable prompt box is
    # ready only when herdr does not contradict it.
    if ready_flag is False:
        return BLOCKED, "not at an input prompt", detail
    return READY, "", detail


# ── Hermes ──────────────────────────────────────────────────────────────────────
def hermes_home():
    return os.environ.get("HERMES_HOME") or os.path.join(os.path.expanduser("~"), ".hermes")


def hermes_sessions():
    """The sessions `hermes sessions list` shows: id, title, workspace, last active.

    Parsed from the table the runtime prints (it has no JSON face at v0.22.6). The id
    is the last field and is the only one with a stable shape, so it is taken first
    and the rest read to its left — a truncated title still leaves a usable row.
    """
    exe = shutil.which("hermes") or os.path.expanduser("~/.local/bin/hermes")
    if not os.path.exists(exe) and not shutil.which("hermes"):
        return None
    try:
        p = subprocess.run([exe, "sessions", "list"], capture_output=True, text=True, timeout=40)
    except (OSError, subprocess.TimeoutExpired):
        return None
    rows, started = [], False
    for line in (p.stdout or "").splitlines():
        if not started:
            if line.startswith("Title") or line.startswith("──") or line.startswith("━"):
                started = True
            continue
        if not line.strip() or line.startswith("─") or line.startswith("━"):
            continue
        parts = line.split()
        if not parts:
            continue
        sid = parts[-1]
        if not sid.startswith("local-") and len(sid) < 16:
            continue
        head = line[: line.rindex(sid)].rstrip()
        # Columns are title (28) · workspace (18) · last active (14), padded with runs
        # of spaces, so a run of two or more IS the column edge.
        cols = [c.strip() for c in head.split("  ") if c.strip()]
        title = cols[0] if cols else ""
        workspace = cols[1] if len(cols) > 1 else ""
        last = cols[2] if len(cols) > 2 else ""
        rows.append({"id": sid, "title": title, "workspace": workspace, "last": last})
    return rows


def hermes_db():
    # The store is a PATH so a test can judge the reader against a fixture of the
    # runtime's own table (never a mock invented for the test); the default is the
    # runtime's own home, so nothing has to be set to work.
    return os.environ.get("AGENT_READY_HERMES_DB") or os.path.join(hermes_home(), "state.db")


def hermes_admission(session_id):
    """The runtime's OWN admission for a session: what it owes, and what it fears.

    `unknown` is deliberate — a turn may have run before the gateway died, so Hermes
    will not guess and the session pauses (`session_authority: paused:
    unknown_execution`). That is `blocked: lost turn, run recover`, and it is a reason
    a person acts on, never a state to retry through.
    """
    db = hermes_db()
    if not os.path.exists(db):
        return None, "no state.db"
    try:
        con = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
        try:
            row = con.execute(
                "SELECT status FROM session_admissions WHERE target_session_id=?"
                " ORDER BY seq DESC LIMIT 1", (session_id,)).fetchone()
        finally:
            con.close()
    except sqlite3.Error as exc:
        return None, str(exc)
    return ((row[0] if row else "") or ""), None


def resolve_hermes(want):
    """`hermes:<id-prefix|title>` → one session row, or a reason it cannot be one."""
    sessions = hermes_sessions()
    if sessions is None:
        return None, "hermes not readable"
    want = (want or "").strip()
    if not want:
        return None, "no session named"
    plain = want[7:] if want.startswith("hermes:") else want

    def bare(sid):
        # Every Hermes session id carries the `local-` prefix; a person quotes the
        # last part of it (`fd2ee4d0`), so both spellings resolve to the same row.
        return sid[6:] if sid.startswith("local-") else sid

    for row in sessions:
        if row["id"] == plain or bare(row["id"]) == bare(plain) or bare(row["id"]).startswith(bare(plain)):
            return row, ""
    hits = [r for r in sessions if plain.lower() in (r["title"] or "").lower()]
    if len(hits) == 1:
        return hits[0], ""
    if len(hits) > 1:
        return None, "ambiguous: %s" % ", ".join(h["id"][:16] for h in hits[:4])
    return None, "no such session"


def hermes_ready(want):
    row, why = resolve_hermes(want)
    if row is None:
        # An ambiguous name is not an absent one: the caller must disambiguate, so it
        # is a block with the candidates named, never a dead target to give up on.
        if why.startswith("ambiguous"):
            return BLOCKED, why, ""
        if why == "no session named":
            return BLOCKED, why, ""
        # Nothing resolves here: the tool is absent, or no session answers to the name.
        return DEAD, why, ""
    status, err = hermes_admission(row["id"])
    detail = "session=%s status=%s" % (row["id"][:24], status or "-")
    if err:
        # A session that answers but whose store cannot be read is NOT ready: the
        # relay would wake it without knowing whether its last turn ever ran.
        return BLOCKED, "hermes store unreadable (%s)" % err[:60], detail
    if status == "unknown":
        return BLOCKED, "lost turn, run recover", detail
    if status in ("queued", "started"):
        return WORKING, "", detail
    return READY, "", detail


# ── one door ────────────────────────────────────────────────────────────────────
def answer(target):
    t = (target or "").strip()
    if not t:
        return {"target": t, "backend": "?", "state": BLOCKED, "reason": "empty target", "detail": ""}
    if t.startswith("hermes:"):
        state, reason, detail = hermes_ready(t)
        backend = "hermes"
    else:
        pane = t[6:] if t.startswith("herdr:") else t
        state, reason, detail = herdr_ready(pane)
        backend = "herdr"
    return {"target": t, "backend": backend, "state": state, "reason": reason, "detail": detail}


def enumerate_all():
    """Every target on this machine, from both backends, in the one vocabulary."""
    targets = []
    rows = as_json(run([herdr_bin(), "agent", "list"]))
    for a in ((rows.get("result") or {}).get("agents") or []):
        if a.get("pane_id"):
            targets.append("herdr:%s" % a["pane_id"])
    for row in (hermes_sessions() or []):
        targets.append("hermes:%s" % row["id"])
    return targets


def line_of(a):
    """The word, and — only for a block — the reason a person acts on.

    `ready`, `working` and `dead` are complete answers; appending prose to them makes
    a caller compare sentences instead of words. `blocked:` is a sentence by design.
    """
    word = WORD[a["state"]]
    return "%s: %s" % (word, a["reason"]) if a["state"] == BLOCKED and a["reason"] else word


def main(argv):
    args = [x for x in argv if x not in ("--json",)]
    as_json_flag = "--json" in argv
    if not args or "-h" in args or "--help" in args:
        sys.stderr.write(__doc__)
        return 64
    if args == ["--version"] or args == ["-v"]:
        print(VERSION)
        return 0

    many = False
    if args[0] == "--all":
        targets, many = enumerate_all(), True
    else:
        targets, many = args, len(args) > 1

    answers = [answer(t) for t in targets]
    if not answers:
        if as_json_flag:
            print("[]")
        return 0
    if as_json_flag:
        print(json.dumps([dict(a, word=line_of(a)) for a in answers], indent=2))
    else:
        for a in answers:
            if many:
                print("%s\t%s" % (a["target"], line_of(a)))
            else:
                print(line_of(a))
    return max(a["state"] for a in answers)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except BrokenPipeError:
        sys.exit(0)
