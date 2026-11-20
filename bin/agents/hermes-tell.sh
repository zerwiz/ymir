#!/usr/bin/env bash
# hermes-tell.sh — hand one line to Hermes through its gateway's API, and print the answer.
#
# The Hermes gateway (`hermes gateway run`, the process the desktop rides on) serves an
# OpenAI-compatible API. This door speaks to it: it reads the listener address and the key from
# Hermes's OWN state and env at call time (never copied into Ymir, never printed), posts one
# stamped line, and prints the reply.
#
# Usage:
#   hermes-tell.sh [--from <who>] "<line>"                     # a fresh session (its id is printed)
#   hermes-tell.sh [--from <who>] --new "<line>"               # the same, said out loud
#   hermes-tell.sh [--from <who>] --session <id|prefix|title> "<line>"   # continue that session
#   hermes-tell.sh [--from <who>] --desktop "<line>"           # the conversation the desktop is on
#   hermes-tell.sh --sessions                                   # sessions a tell can address
#   hermes-tell.sh --where                                      # the road: address, key present?, desktop session
#   hermes-tell.sh --dry-run …                                  # resolve everything, post nothing
#
# Options: --timeout <s> (default 600) · --force (post into a session that is mid-turn).
#
# Promises (plan 340): every line is stamped "[from <who>]"; the result is "handed" plus the
# answer if one came — never "done"; one line only. A session that is mid-turn or still has
# subagents running is REFUSED unless --force: the API has no per-session lock, so a second turn
# would race the first (last writer wins).
#
# Environment: HERMES_HOME (default ~/.hermes) · HERMES_PROFILE (a profile under profiles/) ·
#   HERMES_TELL_ALLOW_REMOTE=1 to send the key to a non-loopback listener (refused by default).
# Exit: 0 answered · 1 refused (busy, no such session) · 2 usage/road missing · 3 the gateway failed.
set -euo pipefail
case "${1-}" in -h|--help) sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
exec python3 - "$@" <<'PY'
import json, os, re, secrets, sqlite3, sys, time, urllib.error, urllib.request

argv = sys.argv[1:]
FROM, MODE, SESSION, TIMEOUT, DRY, FORCE = "script hermes-tell", "new", "", 600, False, False


def die(msg, code=2):
    print("hermes-tell: %s" % msg, file=sys.stderr)
    sys.exit(code)


def say(msg):
    print("hermes-tell: %s" % msg)


action = "tell"
rest = []
i = 0
while i < len(argv):
    a = argv[i]
    if a == "--from":
        FROM = argv[i + 1]; i += 2; continue
    if a == "--session":
        MODE, SESSION = "session", argv[i + 1]; i += 2; continue
    if a == "--new":
        MODE = "new"; i += 1; continue
    if a == "--desktop":
        MODE = "desktop"; i += 1; continue
    if a == "--timeout":
        TIMEOUT = int(argv[i + 1]); i += 2; continue
    if a == "--dry-run":
        DRY = True; i += 1; continue
    if a == "--force":
        FORCE = True; i += 1; continue
    if a in ("--sessions", "--where"):
        action = a[2:]; i += 1; continue
    rest.append(a); i += 1


# ── where Hermes lives: read, never assumed ─────────────────────────────────────
def hermes_home():
    base = os.environ.get("HERMES_HOME") or os.path.join(os.path.expanduser("~"), ".hermes")
    prof = os.environ.get("HERMES_PROFILE", "")
    if prof and prof != "default":
        p = os.path.join(base, "profiles", prof)
        if os.path.isdir(p):
            return p
        die("no Hermes profile %r under %s" % (prof, base))
    return base


HOME = hermes_home()
if not os.path.isdir(HOME):
    die("no Hermes home at %s — skip (Hermes is not installed for this user)" % HOME)


def read_env():
    """KEY=VALUE pairs from Hermes's own .env. Values stay in memory; none is ever printed."""
    out = {}
    try:
        with open(os.path.join(HOME, ".env")) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                k = k.strip().removeprefix("export ").strip()
                v = v.strip()
                if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
                    v = v[1:-1]
                out[k] = v
    except OSError:
        pass
    return out


ENV = read_env()


def listener():
    """The live listener the gateway itself advertises, else the configured one."""
    try:
        with open(os.path.join(HOME, "gateway_state.json")) as f:
            st = json.load(f)
        api = (st.get("platforms") or {}).get("api_server") or {}
        if api.get("state") == "connected" and api.get("listener_base"):
            return api["listener_base"].rstrip("/"), "gateway_state.json"
    except (OSError, ValueError):
        pass
    host = ENV.get("API_SERVER_HOST") or "127.0.0.1"
    port = ENV.get("API_SERVER_PORT") or ""
    if not port:
        return "", ""
    return "http://%s:%s" % (host, port), ".env"


BASE, BASE_FROM = listener()


def api_key():
    return os.environ.get("API_SERVER_KEY") or ENV.get("API_SERVER_KEY") or ""


def loopback(url):
    m = re.match(r"https?://(\[[^\]]+\]|[^:/]+)", url)
    h = (m.group(1) if m else "").strip("[]")
    return h in ("127.0.0.1", "localhost", "::1") or h.startswith("127.")


# ── the session store, read-only ────────────────────────────────────────────────
def db():
    path = os.path.join(HOME, "state.db")
    if not os.path.exists(path):
        return None
    return sqlite3.connect("file:%s?mode=ro" % path, uri=True, timeout=5)


def sessions(limit=20):
    con = db()
    if con is None:
        return []
    try:
        rows = con.execute(
            "SELECT s.id, s.source, COALESCE(s.created_source,''), COALESCE(s.title,''),"
            " (SELECT MAX(timestamp) FROM messages m WHERE m.session_id=s.id) AS la"
            " FROM sessions s WHERE s.archived=0"
            " AND s.source NOT IN ('subagent','cron','tool','oneshot')"
            " ORDER BY la DESC LIMIT ?", (limit,)).fetchall()
    finally:
        con.close()
    return [{"id": r[0], "source": r[1], "created": r[2], "title": r[3], "last": r[4] or 0} for r in rows]


def find(want):
    con = db()
    if con is None:
        die("no state.db in %s — cannot address a session" % HOME)
    try:
        rows = con.execute("SELECT id, COALESCE(title,'') FROM sessions WHERE archived=0").fetchall()
    finally:
        con.close()
    exact = [r for r in rows if r[0] == want]
    if exact:
        return exact[0][0]
    pre = [r for r in rows if r[0].startswith(want) or r[0].removeprefix("local-").startswith(want)]
    if len(pre) == 1:
        return pre[0][0]
    tit = [r for r in rows if want.lower() in r[1].lower()]
    if len(tit) == 1:
        return tit[0][0]
    hits = pre or tit
    if hits:
        die("'%s' matches %d sessions — name more of the id (see --sessions)" % (want, len(hits)), 1)
    die("no Hermes session matches '%s' (see --sessions)" % want, 1)


def desktop_session():
    """The conversation the desktop is driving. A live turn lease held by the desktop names it
    outright; otherwise it is the desktop-made session that spoke last."""
    con = db()
    if con is None:
        return "", "no state.db"
    try:
        now = time.time()
        for cid, holder in con.execute(
                "SELECT conversation_id, holder FROM session_turn_leases WHERE expires_at > ?", (now,)):
            if "platform=desktop" in holder:
                return cid, "a live desktop turn lease"
        # Not filtered on ended_at: closing the window marks the conversation ended
        # (ws_orphan_reap) while the gateway goes on running its turns.
        r = con.execute(
            "SELECT s.id FROM sessions s WHERE s.archived=0 AND s.created_source='desktop'"
            " ORDER BY (SELECT MAX(timestamp) FROM messages m WHERE m.session_id=s.id) DESC LIMIT 1").fetchone()
    finally:
        con.close()
    return (r[0], "the desktop session that spoke last") if r else ("", "no desktop session in state.db")


def desktop_window():
    """Is the Hermes desktop window open? Read from the compositor when there is one."""
    import shutil, subprocess
    if not shutil.which("hyprctl") or not os.environ.get("WAYLAND_DISPLAY"):
        return "unknown (no compositor to ask)"
    try:
        cl = json.loads(subprocess.run(["hyprctl", "clients", "-j"], capture_output=True,
                                       text=True, timeout=5).stdout or "[]")
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return "unknown"
    rx = re.compile(os.environ.get("HERMES_DESKTOP_CLASS", r"(?i)^hermes"))
    hit = [c for c in cl if rx.search(c.get("class", "") or "")]
    return ("open on workspace %s" % hit[0]["workspace"]["name"]) if hit else "closed"


def busy(sid):
    """Why a session must not take a second turn now, or '' when it is free."""
    con = db()
    if con is None:
        return ""
    try:
        now = time.time()
        if con.execute("SELECT 1 FROM session_turn_leases WHERE conversation_id=? AND expires_at>?",
                       (sid, now)).fetchone():
            return "mid-turn (a live turn lease)"
        r = con.execute("SELECT status FROM session_admissions WHERE target_session_id=?"
                        " ORDER BY seq DESC LIMIT 1", (sid,)).fetchone()
        if r and r[0] in ("queued", "started"):
            return "mid-turn (admission %s)" % r[0]
        if r and r[0] == "unknown":
            return "paused on a lost turn — recover it first (bin/seat/backend.sh explain hermes:%s)" % sid[:16]
        n = con.execute("SELECT COUNT(*) FROM async_delegations WHERE parent_session_id=? AND state='running'",
                        (sid,)).fetchone()[0]
        if n:
            return "%d subagent(s) still running under it" % n
    except sqlite3.Error as exc:
        return "store unreadable (%s)" % str(exc)[:60]
    finally:
        con.close()
    return ""


def title_of(sid):
    con = db()
    if con is None:
        return ""
    try:
        r = con.execute("SELECT COALESCE(title,'') FROM sessions WHERE id=?", (sid,)).fetchone()
    finally:
        con.close()
    return r[0] if r else ""


# ── the actions ─────────────────────────────────────────────────────────────────
if action == "sessions":
    print("sessions{id,source,made_by,title,last,state}:")
    for s in sessions():
        last = time.strftime("%Y-%m-%dT%H:%M", time.localtime(s["last"])) if s["last"] else "-"
        state = busy(s["id"]) or "ready"
        print('  %s,%s,%s,"%s",%s,"%s"' % (s["id"], s["source"], s["created"], s["title"][:40], last, state))
    sys.exit(0)

if action == "where":
    dsid, why = desktop_session()
    print("hermes_road{field,value}:")
    print('  home,%s' % HOME)
    print('  listener,%s' % (BASE or "none"))
    print('  listener_from,%s' % (BASE_FROM or "-"))
    print('  key,%s' % ("present (API_SERVER_KEY, not shown)" if api_key() else "absent"))
    print('  desktop_session,%s' % (dsid or "-"))
    print('  desktop_how,"%s"' % why)
    print('  desktop_state,"%s"' % ((busy(dsid) or "ready") if dsid else "-"))
    print('  desktop_window,"%s"' % desktop_window())
    sys.exit(0)

if not rest:
    die("usage: hermes-tell.sh [--from <who>] [--new|--session <id>|--desktop] \"<line>\"")
line = " ".join(rest)
if "\n" in line:
    die("one line only — put a long message in a letter file and tell Hermes its path")
text = "[from %s] %s" % (FROM, line)

if not BASE:
    die("the Hermes gateway's API is not configured (no API_SERVER_PORT in %s/.env and no live listener)" % HOME)
if not loopback(BASE) and os.environ.get("HERMES_TELL_ALLOW_REMOTE") != "1":
    die("the listener %s is not loopback — refusing to send the key over it (HERMES_TELL_ALLOW_REMOTE=1 overrides)" % BASE)
key = api_key()

if MODE == "session":
    sid, how = find(SESSION), "named"
elif MODE == "desktop":
    sid, how = desktop_session()
    if not sid:
        die("no desktop session to land in (%s)" % how, 1)
    win = desktop_window()
    if win == "closed":
        how += " · the desktop window is closed, so the line waits in the session until it opens"
else:
    sid, how = "tell-%s-%s" % (time.strftime("%Y%m%dT%H%M%S"), secrets.token_hex(3)), "new"

if not key:
    die("API_SERVER_KEY is not set in Hermes's env — the gateway refuses to continue a session without it", 2)

if MODE != "new":
    why = busy(sid)
    if why and not FORCE:
        die("session %s (%s) is busy: %s — not sent; wait, or --force" % (sid[:24], title_of(sid)[:30] or "untitled", why), 1)

say("road gateway-api %s · session %s (%s%s)" % (BASE, sid, how, (" · " + title_of(sid)[:40]) if title_of(sid) else ""))
if DRY:
    say("dry run — would post: %s" % text)
    sys.exit(0)

body = json.dumps({"messages": [{"role": "user", "content": text}], "stream": False}).encode()
req = urllib.request.Request(BASE + "/v1/chat/completions", data=body, method="POST", headers={
    "Content-Type": "application/json",
    "Authorization": "Bearer " + key,
    "X-Hermes-Session-Id": sid,
})
t0 = time.time()
say("handed — waiting for the answer (up to %ss)" % TIMEOUT)
try:
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        echoed = r.headers.get("X-Hermes-Session-Id") or sid
        data = json.loads(r.read().decode() or "{}")
except urllib.error.HTTPError as e:
    msg = ""
    try:
        msg = json.loads(e.read().decode()).get("error", {}).get("message", "")
    except Exception:  # noqa: BLE001
        pass
    die("handed, but the gateway answered HTTP %s %s" % (e.code, msg[:200]), 3)
except (urllib.error.URLError, TimeoutError, OSError) as e:
    die("handed, but no answer came (%s) — the turn may still run; read the session later" % str(e)[:120], 3)

choices = data.get("choices") or []
answer = ((choices[0].get("message") or {}).get("content") if choices else "") or ""
say("answered in %.1fs · session %s" % (time.time() - t0, echoed))
print(answer.strip() or "(an empty answer)")
PY
