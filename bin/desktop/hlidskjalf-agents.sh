#!/usr/bin/env bash
# hlidskjalf-agents.sh — WHO IS ACTUALLY STANDING, and what they are doing.
#
# The control plane showed the ROSTER: the twenty-four profiles that *could* run.
# A roster is a leaflet; the panes are the truth. This reads the live pane list
# (herdr) and emits the seats that exist right now, plus every roster figure that
# is NOT standing, marked honestly as not seated.
#
#   bin/desktop/hlidskjalf-agents.sh            # JSON (what /api/agents serves)
#   bin/desktop/hlidskjalf-agents.sh --toon     # TOON (for a human at a terminal)
#
# WHAT A ROW MAY CLAIM (2026-11-14, plan 275 item 9 — at the Allfather's word:
# *"are all agent cards true … cant we show more information about them"*):
#
#   NOMINAL means ALIVE — a herdr pane holds an agent. There is no other meaning,
#   and an unseated figure is `down`, never nominal. (All 24 role cards read
#   NOMINAL while nine agents lived, because the roster's status was invented.)
#   model      the one its launch recorded (state/<id>.meta model=), else the one
#              the operator configured for it (config/agents.yaml), else empty —
#              never a guess.
#   harness    the pane's own agent kind (claude · pi · hermes), or the errand's.
#   pane       the pane id, and a LABEL of "<agent> · <errand>", never the
#              terminal title ("π - ymir" says nothing about the work).
#   machine    this host. seat: the herdr workspace the work sits in.
#   errand     the errand record whose launch names this pane, with its last claim.
#   last       the last message recorded TO it in the fleet log (bin/agents/msg-log.sh).
#
# State comes from the pane's own reported status; no liveness is inferred from a
# process list or from prose. When herdr is absent the connector prints `[]` and
# the gate falls back to the roster — an empty answer is never dressed as a fleet.
set -u

VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

MODE="json"
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --toon) MODE="toon" ;;
esac

# herdr is resolved here, never assumed to be on the caller's PATH: the gate's
# unit runs with a trimmed PATH (no ~/.local/bin), and a bare `herdr` there is
# invisible — which is how a live fleet once served an empty board.
resolve_herdr() {
  if [ -n "${HERDR_BIN_PATH:-}" ] && [ -x "${HERDR_BIN_PATH}" ]; then printf '%s' "$HERDR_BIN_PATH"; return 0; fi
  if command -v herdr >/dev/null 2>&1; then command -v herdr; return 0; fi
  local c
  for c in "$HOME/.local/bin/herdr" "$HOME/.cargo/bin/herdr" /usr/local/bin/herdr /usr/bin/herdr; do
    [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}
HERDR="$(resolve_herdr || true)"
if [ -z "$HERDR" ]; then
  [ "$MODE" = json ] && printf '[]\n' || printf 'agents[0]{name}:\n'
  exit 0
fi
raw="$("$HERDR" pane list 2>/dev/null)"

# The roster is read from the REPO root, absolute, so a caller's cwd can never
# point it at the wrong directory. An explicit ROSTER_DIR always wins.
if REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then :; else REPO_ROOT="$ROOT"; fi
export ROSTER_DIR="${ROSTER_DIR:-$REPO_ROOT/.agents/agents}"

# The records that make a card true live OUTSIDE the tree (Rule 04): the errand
# claims in the home's state root, the operator's agent set in its settings.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/hoard-lib.sh" "$SCRIPT_DIR/../../bin/vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
# The fallback is NOT restated here: the home is whatever the one resolver says
# (bin/vault/hoard-lib.sh), and when the resolver is missing the card says so by
# leaving these empty rather than guessing a path (Rule 07, defaults-guard).
STATE_DIR="${YMIR_STATE_DIR:-}"; SETTINGS_DIR="${YMIR_SETTINGS_DIR:-}"
if [ -z "$STATE_DIR" ] && command -v hoard_state_dir >/dev/null 2>&1; then hoard_state_dir STATE_DIR; fi
if [ -z "$SETTINGS_DIR" ] && command -v hoard_settings_dir >/dev/null 2>&1; then hoard_settings_dir SETTINGS_DIR; fi
if [ -z "$SETTINGS_DIR" ] && command -v ymir_home_root >/dev/null 2>&1; then
  _home=""; ymir_home_root _home && SETTINGS_DIR="$_home/config"; unset _home
fi
AGENTS_YAML="${YMIR_AGENTS_YAML:-$SETTINGS_DIR/agents.yaml}"
MSGLOG="${YMIR_MSG_LOG:-$STATE_DIR/fleet/messages.jsonl}"

MODE="$MODE" RAW="$raw" STATE_DIR="$STATE_DIR" AGENTS_YAML="$AGENTS_YAML" \
MSGLOG="$MSGLOG" MACHINE="$(hostname -s 2>/dev/null || uname -n)" \
python3 - <<'PY'
import glob, json, os, re

mode = os.environ.get("MODE", "json")
raw = os.environ.get("RAW", "")
ROSTER_DIR = os.environ.get("ROSTER_DIR", ".agents/agents")
STATE_DIR = os.environ.get("STATE_DIR", "")
AGENTS_YAML = os.environ.get("AGENTS_YAML", "")
MSGLOG = os.environ.get("MSGLOG", "")
MACHINE = os.environ.get("MACHINE", "")

PANE_RE = re.compile(r"^w[0-9A-Za-z]+:p[0-9]+$")


def read(path, limit=None):
    try:
        with open(path, errors="replace") as fh:
            return fh.read(limit) if limit else fh.read()
    except OSError:
        return ""


def frontmatter(text):
    if not text.startswith("---"):
        return ""
    parts = text.split("---", 2)
    return parts[1] if len(parts) > 2 else ""


def fm_scalar(block, key):
    for line in block.splitlines():
        if line.startswith(key + ":"):
            return line.split(":", 1)[1].strip().strip('"').strip("'")
    return ""


def fm_list(block, key):
    """A YAML list under `<key>:` — either inline [a, b] or the usual `  - a` rows."""
    out, grab = [], False
    for line in block.splitlines():
        if line.startswith(key + ":"):
            rest = line.split(":", 1)[1].strip()
            if rest.startswith("["):
                return [x.strip().strip("\"'") for x in rest.strip("[]").split(",") if x.strip()]
            if rest:
                return [rest]
            grab = True
            continue
        if grab:
            s = line.strip()
            if s.startswith("- "):
                out.append(s[2:].strip().strip("\"'"))
            elif s and not line.startswith((" ", "\t")):
                break
    return out


def panes():
    """The STANDING seats: a herdr pane an agent runs in. A pane is the WHERE."""
    try:
        data = json.loads(raw)
    except ValueError:
        return []
    pl = (data.get("result") or {}).get("panes") or data.get("panes") or []
    out = []
    for p in pl:
        agent = (p.get("agent") or "").strip()
        state = (p.get("agent_status") or "unknown").strip()
        if not agent and state in ("", "unknown", None):
            continue
        title = (p.get("terminal_title_stripped") or p.get("terminal_title") or "").strip()
        out.append({
            "pane": p.get("pane_id") or "",
            "harness": agent or "agent",
            "state": state or "unknown",
            "title": title,
            "cwd": p.get("foreground_cwd") or p.get("cwd") or "",
            "workspace": p.get("workspace_id") or "",
        })
    return out


def roster():
    """The AGENTS, from the canonical roster (.agents/agents/*.md). A pane is the where; this is the WHO."""
    try:
        files = sorted(f for f in os.listdir(ROSTER_DIR) if f.endswith(".md"))
    except OSError:
        return []
    out = []
    for f in files:
        stem = f[:-3]
        block = frontmatter(read(os.path.join(ROSTER_DIR, f), 8000))
        figure = (fm_scalar(block, "name") or stem.split("-")[0]).lower()
        out.append({
            "figure": figure,
            "name": fm_scalar(block, "norse_name") or fm_scalar(block, "name") or figure,
            "role": fm_scalar(block, "descriptor") or fm_scalar(block, "role") or "agent",
            "domain": fm_scalar(block, "domain") or "ymirlabs",
            "model": fm_scalar(block, "model"),
            "capabilities": fm_list(block, "capabilities"),
        })
    return out


def errands():
    """pane → the errand whose launch named it, newest launch wins.

    This is the only match between a pane and its work that is evidence rather than
    prose: the launcher wrote `window=`/`herdr_pane_id=` into state/<id>.meta, and
    the seat's claim is the last line of state/<id>.status.
    """
    out = {}
    for meta in glob.glob(os.path.join(STATE_DIR, "*.meta")):
        kv = {}
        for line in read(meta).splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                kv[k.strip()] = v
        pane = kv.get("herdr_pane_id") or kv.get("window") or ""
        if not PANE_RE.match(pane.strip()):
            continue
        ident = kv.get("id") or os.path.basename(meta)[:-5]
        try:
            launched = int(kv.get("launched") or 0)
        except ValueError:
            launched = 0
        prev = out.get(pane.strip())
        if prev and prev["launched"] > launched:
            continue
        out[pane.strip()] = {
            "id": ident,
            "harness": kv.get("harness", ""),
            "model": kv.get("model", ""),
            "mode": kv.get("mode", ""),
            "worktree": kv.get("worktree", ""),
            "launched": launched,
        }
    for pane, e in out.items():
        claims = [ln for ln in read(os.path.join(STATE_DIR, e["id"] + ".status")).splitlines() if ln.strip()]
        last = claims[-1] if claims else ""
        e["claim"] = last
        e["state"] = last.split(":", 1)[0].strip().lower()
    return out


def worktree_errand(cwd):
    """A pane that works inside a Yggdrasil worktree is doing THAT errand: the tree is
    named for the errand it was cut for. Evidence, not a title match."""
    m = re.search(r"/\.yggdrasil/([^/]+)", cwd or "")
    if not m:
        return None
    ident = m.group(1)
    claims = [ln for ln in read(os.path.join(STATE_DIR, ident + ".status")).splitlines() if ln.strip()]
    last = claims[-1] if claims else ""
    meta = {}
    for line in read(os.path.join(STATE_DIR, ident + ".meta")).splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            meta[k.strip()] = v
    return {
        "id": ident,
        "harness": meta.get("harness", ""),
        "model": meta.get("model", ""),
        "mode": meta.get("mode", ""),
        "worktree": meta.get("worktree", ""),
        "launched": 0,
        "claim": last,
        "state": last.split(":", 1)[0].strip().lower(),
    }


def configured_models():
    """config/agents.yaml — the model the operator chose for an agent that is not standing."""
    models, default = {}, ""
    if not AGENTS_YAML or not os.path.exists(AGENTS_YAML):
        return models
    in_agents = False
    for line in read(AGENTS_YAML).splitlines():
        s = line.rstrip()
        if s.startswith("default_model:"):
            default = s.split(":", 1)[1].strip()
        if s.startswith("agents:"):
            in_agents = True
            continue
        if not in_agents:
            continue
        if s and not s.startswith((" ", "\t", "#")):
            in_agents = False
            continue
        if "{" in s and "}" in s:
            name = s.strip().split(":", 1)[0].strip().lower()
            body = s.split("{", 1)[1].split("}", 1)[0]
            model = ""
            for part in body.split(","):
                if part.strip().startswith("model:"):
                    model = part.split("model:", 1)[1].strip()
            if name and model:
                models[name] = model
    models["__default__"] = default
    return models


def last_messages():
    """The newest recorded message per target — the fleet log is the one record of agent speech."""
    out = {}
    lines = read(MSGLOG).splitlines()[-400:] if MSGLOG else []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except ValueError:
            continue
        for key in (row.get("pane"), row.get("to")):
            if key:
                out[str(key).lower()] = row
    return out


ps = panes()
rs = roster()
er = errands()
msgs = last_messages()
cfg = configured_models()
default_model = cfg.get("__default__", "")

# The errand that owns a pane, by name: an errand id that carries the figure's own
# name is the dispatch's own word about who is in the pane (bragi-…, sindri-…).
matched = {}
for pane, e in er.items():
    for a in rs:
        fig = a["figure"]
        if fig and (e["id"] == fig or e["id"].startswith(fig + "-") or ("-" + fig + "-") in e["id"]):
            matched.setdefault(fig, (pane, e))
            break


def build(*, ident, name, role, domain, pane, harness, state, model, model_source,
          capabilities, errand, errand_claim, errand_state, cfg_model, workspace, cwd):
    alive = bool(pane) and state not in ("", "unknown")
    last = msgs.get(pane.lower()) if pane else None
    # A pane is named by ITS AGENT and ITS ERRAND, never by the terminal title
    # ("π - ymir" says nothing about the work). A seat with no errand record says that
    # rather than guessing one from the title.
    if pane:
        label = name if (not errand or errand == name) else "%s · %s" % (name, errand)
    else:
        label = ""
    return {
        "id": ident,
        "name": name,
        "role": role,
        "realm": "work",
        "domain": domain,
        "status": "nominal" if alive else "down",
        "alive": alive,
        "capabilities": capabilities,
        "skills": [],
        "interface": {
            "protocol": "a2a/1.0",
            "endpoint": ("pane://%s" % pane) if pane else "",
            "signed": False,
        },
        "model": model,
        "modelSource": model_source,
        "configuredModel": cfg_model,
        "uptime": 0,
        "tasksDone": 0,
        "traceability": 0,
        "kind": harness or role,
        "state": state if pane else "unseated",
        "pane": pane,
        "paneLabel": label,
        "harness": harness,
        "machine": MACHINE,
        "seat": workspace,
        "cwd": cwd,
        "task": errand,
        "errand": errand,
        "errandState": errand_state,
        "errandClaim": errand_claim,
        "lastMessage": (last or {}).get("text", ""),
        "lastMessageAt": (last or {}).get("ts", ""),
        "lastMessageFrom": (last or {}).get("from", ""),
        "live": {
            "kind": harness,
            "state": state,
            "pane": pane,
            "workspace": workspace,
            "cwd": cwd,
            "task": errand,
        } if pane else None,
    }


rows = []

# THE ROSTER FIRST — every smith, and the plain truth about whether it stands.
for a in rs:
    hit = matched.get(a["figure"])
    cfg_model = cfg.get(a["figure"]) or default_model
    if hit:
        pane, e = hit
        p = next((x for x in ps if x["pane"] == pane), None)
        if p:
            model = e["model"] or cfg_model
            rows.append(build(
                ident="pane:" + pane, name=a["name"], role=a["role"],
                domain=a["domain"], pane=pane, harness=p["harness"], state=p["state"],
                model=model, model_source="launched" if e["model"] else ("configured" if cfg_model else "none"),
                capabilities=a["capabilities"], errand=e["id"], errand_claim=e["claim"],
                errand_state=e["state"], cfg_model=cfg_model, workspace=p["workspace"], cwd=p["cwd"]))
            continue
    rows.append(build(
        ident="roster:" + a["figure"], name=a["name"], role=a["role"], domain=a["domain"],
        # An unseated figure has NO harness: nothing is running it. Naming one would be
        # a guess dressed as a fact (it used to say "pi" for anyone configured).
        pane="", harness="", state="unseated",
        model=cfg_model, model_source="configured" if cfg_model else "none",
        capabilities=a["capabilities"], errand="", errand_claim="", errand_state="",
        cfg_model=cfg_model, workspace="", cwd=""))

# THEN THE SEATS THAT ANSWER TO NO ONE ON THE ROSTER: kept visible, named by their errand.
HELM_PANE = read(os.path.join(STATE_DIR, ".arm.pane")).strip().splitlines()[0].strip() if os.path.exists(os.path.join(STATE_DIR, ".arm.pane")) else ""
used = {pane for pane, _ in matched.values()}
for p in ps:
    if p["pane"] in used:
        continue
    e = er.get(p["pane"]) or worktree_errand(p["cwd"]) or {}
    model = e.get("model") or ""
    errand = e.get("id", "")
    is_helm = bool(HELM_PANE) and p["pane"] == HELM_PANE
    # A seat with no errand and no roster figure is still real work in a real pane, so it
    # is named for the only two things known about it: its harness and its pane id. (The
    # terminal title was the old name, and "π - ymir" names nobody.)
    rows.append(build(
        ident="pane:" + p["pane"],
        name=errand or ("the helm" if is_helm else "%s · %s" % (p["harness"], p["pane"])),
        role=(e.get("mode") or "errand") if errand else ("counsellor · helm" if is_helm else (p["harness"] + " seat")),
        domain="ymirlabs", pane=p["pane"], harness=p["harness"], state=p["state"],
        model=model, model_source="launched" if model else "none",
        capabilities=[], errand=errand, errand_claim=e.get("claim", ""),
        errand_state=e.get("state", ""), cfg_model="", workspace=p["workspace"], cwd=p["cwd"]))

if mode == "json":
    print(json.dumps(rows))
    raise SystemExit

alive = [r for r in rows if r["alive"]]
print("agents[%d]{name,state,status,pane,label,model,errand,machine}:" % len(rows))
for r in rows:
    q = lambda s: '"%s"' % str(s or "").replace('"', '\\"')
    print("  %s,%s,%s,%s,%s,%s,%s,%s" % (
        q(r["name"]), q(r["state"]), q(r["status"]), q(r["pane"]), q(r["paneLabel"]),
        q(r["model"]), q(r["errand"]), q(r["machine"])))
print("standing: %d of %d" % (len(alive), len(rows)))
PY
