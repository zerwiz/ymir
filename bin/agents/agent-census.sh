#!/usr/bin/env bash
# agent-census.sh — how many agents are running on THIS machine, and which of them are stale.
#
# The arm holder is the Allfather's right hand on his machines, so it must know exactly what is
# running beside it (his word, 2026-11-10: "the arm holder should know exactly how many agents are
# running on the computer"). Measured that day on heimdall: 5 harness processes, 18 herdr
# workspaces, 7 of them old Eindri smithies whose errands had long reported `done`, and 79
# worktrees under .yggdrasil — and no door that put those numbers in one place.
#
# It READS and never closes. Closing a pane or reaping a worktree is a separate, named act.
#
#   agent-census.sh            # the full census (TOON)
#   agent-census.sh --digest   # the session-start lines: counts + every stale seat
#   agent-census.sh --json     # machine-readable
#
# Sources, each a door that already owns its answer:
#   processes   /proc — every harness the lock law knows (claude codex opencode grok kimi pi pi-signed)
#   herdr       `herdr pane list` / `herdr agent list` (a clean skip when herdr is absent, Rule 25)
#   errands     <state>/<id>.meta (window=, worktree=) + the last line of <state>/<id>.status
#   worktrees   `git worktree list` of this repo (the main checkout's .yggdrasil and any nested one)
#   the helm    bin/records/ymir-state.sh lock owner
#
# Exit: 0 ran · 2 usage.
set -uo pipefail
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODE="${1:-full}"
case "$MODE" in -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; -v|--version) echo "$VERSION"; exit 0 ;;
  full|--digest|--json) ;; *) echo "error: unknown mode $MODE" >&2; exit 2 ;; esac

STATE=""
. "$ROOT/bin/vault/hoard-lib.sh"
hoard_state_dir STATE
OWNER="$(bash "$ROOT/bin/records/ymir-state.sh" lock owner 2>/dev/null | tr -d '[:space:]')"
PANES=""; AGENTS=""
if command -v herdr >/dev/null 2>&1; then
  PANES="$(timeout 10 herdr pane list 2>/dev/null || true)"
  AGENTS="$(timeout 10 herdr agent list 2>/dev/null || true)"
fi

python3 - "$MODE" "$STATE" "$ROOT" "${OWNER:-}" "$PANES" "$AGENTS" <<'PY'
import json, os, re, sys
from pathlib import Path
mode, state, root, owner, panes_raw, agents_raw = sys.argv[1:7]
state, root = Path(state), Path(root)
HARNESS = re.compile(r"^(claude|codex|opencode|grok|kimi|pi|pi-signed|hermes|cursor-agent|gemini)$")

def proc_rows():
    out = []
    for d in Path("/proc").iterdir():
        if not d.name.isdigit():
            continue
        try:
            comm = (d / "comm").read_text().strip()
        except Exception:
            continue
        if not HARNESS.match(comm):
            continue
        try:
            cwd = os.readlink(d / "cwd")
        except Exception:
            cwd = "?"
        try:
            tty = os.readlink(d / "fd/0")
        except Exception:
            tty = "?"
        try:
            ticks = int((d / "stat").read_text().rsplit(")", 1)[1].split()[19])
            up = float(Path("/proc/uptime").read_text().split()[0])
            age = int(up - ticks / os.sysconf("SC_CLK_TCK"))
        except Exception:
            age = -1
        out.append({"pid": int(d.name), "harness": comm, "cwd": cwd,
                    "tty": tty.replace("/dev/", ""), "age_h": round(age / 3600, 1) if age >= 0 else None,
                    "helm": d.name == owner})
    return sorted(out, key=lambda r: r["pid"])

def load(raw, key):
    try:
        res = json.loads(raw)["result"]
        return res.get(key) or []
    except Exception:
        return []

panes = load(panes_raw, "panes")
agents = {a.get("pane_id"): a for a in load(agents_raw, "agents")}
herdr_up = bool(panes_raw.strip())

errands = {}
for meta in state.glob("*.meta"):
    fields = {}
    for line in meta.read_text(errors="ignore").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            fields[k] = v
    last = ""
    st = meta.with_suffix(".status")
    if st.is_file():
        lines = [l for l in st.read_text(errors="ignore").splitlines() if l.strip()]
        last = lines[-1] if lines else ""
    errands[fields.get("window", "")] = {"id": meta.stem, "worktree": fields.get("worktree", ""), "status": last}

TERMINAL = ("done:", "failed:", "needs-decision:", "paused:")
pane_rows = []
for p in panes:
    pid = p.get("pane_id", "")
    a = agents.get(pid)
    e = errands.get(pid)
    # A pane id is reused by herdr; it is this errand's only while it still stands in its worktree.
    if e and e["worktree"] and not (p.get("cwd") or "").startswith(e["worktree"]):
        e = None
    verdict = "agent" if a else "shell"
    if e:
        verdict = "stale-errand" if (e["status"].startswith(TERMINAL) and not a) else ("errand" if a else "errand-no-agent")
    pane_rows.append({"pane": pid, "workspace": p.get("workspace_id", ""), "cwd": p.get("cwd", ""),
                      "agent": (a or {}).get("agent", ""), "agent_status": (a or {}).get("agent_status", ""),
                      "errand": (e or {}).get("id", ""), "errand_status": (e or {}).get("status", "")[:70],
                      "verdict": verdict})

import subprocess
try:
    wl = subprocess.run(["git", "-C", str(root), "worktree", "list", "--porcelain"], capture_output=True, text=True, timeout=20).stdout
    worktrees = [l.split(" ", 1)[1] for l in wl.splitlines() if l.startswith("worktree ")][1:]
except Exception:
    worktrees = []
procs = proc_rows()
by_h = {}
for r in procs:
    by_h[r["harness"]] = by_h.get(r["harness"], 0) + 1
stale = [r for r in pane_rows if r["verdict"] == "stale-errand"]
unseen = [r for r in procs if not any(r["cwd"] == p["cwd"] and p["agent"] == r["harness"] for p in pane_rows)]

if mode == "--json":
    print(json.dumps({"helm": owner, "processes": procs, "panes": pane_rows, "worktrees": len(worktrees),
                      "stale_errand_panes": stale, "herdr": herdr_up}, indent=1)); sys.exit(0)

q = lambda s: '"' + str(s).replace('"', "'") + '"'
summary = " · ".join(f"{n} {h}" for h, n in sorted(by_h.items())) or "none"
if mode == "--digest":
    print(f"agents running: {len(procs)} ({summary}) · helm pid {owner or 'none'}")
    if herdr_up:
        print(f"herdr: {len(panes)} pane(s) in {len({p['workspace'] for p in pane_rows})} workspace(s) · "
              f"{len(agents)} agent(s) detected · {len(stale)} stale errand pane(s)")
    else:
        print("herdr: not running here (skip)")
    print(f"worktrees: {len(worktrees)} linked to this repo (git worktree list)")
    for r in unseen:
        print(f"OUTSIDE_HERDR {r['harness']} pid {r['pid']} on {r['tty']} in {r['cwd']} ({r['age_h']} h)")
    for r in stale:
        print(f"STALE_PANE {r['pane']} errand {r['errand']} — {r['errand_status'][:60]}")
    sys.exit(0)

print(f"census[1]{{helm,processes,herdr_panes,herdr_agents,stale_errand_panes,worktrees}}:")
print(f"  {q(owner or 'none')},{len(procs)},{len(panes)},{len(agents)},{len(stale)},{len(worktrees)}")
print(f"processes[{len(procs)}]{{pid,harness,age_h,tty,cwd,helm}}:")
for r in procs:
    print(f"  {r['pid']},{q(r['harness'])},{r['age_h']},{q(r['tty'])},{q(r['cwd'])},{str(r['helm']).lower()}")
print(f"panes[{len(pane_rows)}]{{pane,workspace,agent,verdict,errand,errand_status}}:")
for r in pane_rows:
    print(f"  {q(r['pane'])},{q(r['workspace'])},{q(r['agent'] or '-')},{q(r['verdict'])},{q(r['errand'] or '-')},{q(r['errand_status'] or '-')}")
PY
