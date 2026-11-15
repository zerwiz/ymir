#!/usr/bin/env python3
"""herdr-agents.py — list the agents standing in this herdr session, as TOON.

Kept as its own file rather than an inline -c: the JSON shape has nested quotes
that are painful to escape inside a shell heredoc, and a separate file can be
tested on its own.

ONE reader for one question, because a second parser of the same JSON is how
`herdr pane list` came to be read as if a pane were an agent (plan 189 §18.2: a
pane is not an agent — only `herdr agent list` shows a worker). The spawner's
seat proof and the sweep's liveness cross-check both ask this door, so they
cannot disagree about whether a seat is standing.

  --find --cwd <path> [--pane <id>]
      prints `<pane>\t<state>\t<cwd>` and exits 0 when an agent's FOREGROUND cwd
      (or its working directory) is <path>, or when the named pane hosts an
      agent; exits 1 when no agent matches. That is the whole test: the pane is
      the evidence, `state/<id>.status` is only the claim.

  --tsv
      one line per agent, tab-separated, for a caller that needs the whole
      identity of a seat rather than the person's reading of it:
      `pane  status  kind  tab  workspace  focused  cwd` (cwd is the FOREGROUND
      cwd when herdr reports one). `bin/seat/seat-audit.sh` and the tab sweep of
      `bin/seat/seat-reap.sh` read this face, so the pane, its tab and its
      workspace come from one door and cannot disagree.

  --panes [--cwd <path>]
      every PANE herdr reports, with or without an agent in it, as TSV:
      `pane  workspace  agent  status  cwd` (agent and status are empty for a bare
      shell). A pane is not an agent, and this is the face that says so: measured
      2026-11-14, pi died at start in the reviewer's seat, the pane fell back to a
      shell, and the keeper counted that shell as the seat for want of this question.

  --verdict --pane <id>
      `verdict<TAB>state` for the agent that would stand in <pane>. The verdict is
      `live` (herdr reports an agent in working/idle/done/blocked), `dead` (herdr
      says plainly that no agent is here) or `unsure` (herdr gives no readable
      answer — never a licence to close somebody's pane). The state is herdr's own
      word, empty when there is no agent: one read answers both.

  --room --label <label>
      the workspace id carrying that label, or nothing.

  --pane-room --pane <id>
      the workspace <pane> stands in, read from `pane list` and, for a herdr that
      reports no pane list, from the agent row.

Usage: herdr-agents.py [--json] [--tsv] [--panes] [--find [--cwd P] [--pane P]]
                       [--verdict|--pane-room --pane P] [--room --label L]
"""
import json
import subprocess
import sys


def fetch() -> list:
    raw = subprocess.run(
        ["herdr", "agent", "list"],
        capture_output=True, text=True, timeout=15,
    ).stdout
    return (json.loads(raw).get("result") or {}).get("agents") or []


def fetch_panes() -> list:
    raw = subprocess.run(
        ["herdr", "pane", "list"],
        capture_output=True, text=True, timeout=15,
    ).stdout
    return (json.loads(raw).get("result") or {}).get("panes") or []


def fetch_rooms() -> list:
    raw = subprocess.run(
        ["herdr", "workspace", "list"],
        capture_output=True, text=True, timeout=15,
    ).stdout
    return (json.loads(raw).get("result") or {}).get("workspaces") or []


def fetch_agent(pane: str) -> dict:
    proc = subprocess.run(
        ["herdr", "agent", "get", pane],
        capture_output=True, text=True, timeout=15,
    )
    # MEASURED 2026-11-14 on herdr 0.9.1: `agent get` answers a pane with no agent on STDERR with
    # exit 1 (`{"error":{"code":"agent_not_found"…}}`), and a live agent on STDOUT with exit 0. A
    # reader that watched only stdout would call every empty pane "unsure" and never reap a seat.
    for raw in (proc.stdout, proc.stderr):
        raw = (raw or "").strip()
        if not raw:
            continue
        try:
            return json.loads(raw)
        except Exception:  # noqa: BLE001
            continue
    return {}


def arg(args: list, name: str) -> str:
    if name in args:
        i = args.index(name)
        if i + 1 < len(args):
            return args[i + 1]
    return ""


LIVE = ("working", "idle", "done", "blocked")
DEAD = ("", "unknown", "none", "stopped", "exited", "error", "dead")


def main() -> int:
    args = sys.argv[1:]
    try:
        agents = fetch()
    except Exception as exc:  # noqa: BLE001
        print(f"herdr-agents[1]{{state}}:\n  \"cannot read herdr agents ({exc})\"")
        return 1

    if "--find" in args:
        want_cwd = ""
        want_pane = ""
        i = 0
        while i < len(args):
            if args[i] == "--cwd" and i + 1 < len(args):
                want_cwd = args[i + 1].rstrip("/") or "/"
                i += 2
                continue
            if args[i] == "--pane" and i + 1 < len(args):
                want_pane = args[i + 1]
                i += 2
                continue
            i += 1
        for a in agents:
            pane = a.get("pane_id") or ""
            fg = (a.get("foreground_cwd") or "").rstrip("/") or "/"
            cwd = (a.get("cwd") or "").rstrip("/") or "/"
            hit_cwd = bool(want_cwd) and want_cwd in (fg, cwd)
            hit_pane = bool(want_pane) and want_pane == pane
            if hit_cwd or hit_pane:
                print(f"{pane}\t{a.get('agent_status') or 'unknown'}\t{fg}")
                return 0
        return 1

    if "--json" in args:
        print(json.dumps(agents, indent=2))
        return 0

    if "--tsv" in args:
        for a in agents:
            print("\t".join([
                a.get("pane_id") or "?",
                a.get("agent_status") or "unknown",
                a.get("agent") or "?",
                a.get("tab_id") or "",
                a.get("workspace_id") or "",
                "true" if a.get("focused") else "false",
                (a.get("foreground_cwd") or a.get("cwd") or "?"),
            ]))
        return 0

    if "--panes" in args:
        want_cwd = arg(args, "--cwd").rstrip("/")
        try:
            panes = fetch_panes()
        except Exception:  # noqa: BLE001
            panes = []
        if not panes:
            # a herdr with no pane list knows only its agent rows — and still reports a pane whose
            # agent died, with an empty kind and the state `unknown`. Same shape, one source fewer.
            panes = [
                {"pane_id": a.get("pane_id"), "workspace_id": a.get("workspace_id"),
                 "agent": a.get("agent"), "agent_status": a.get("agent_status"),
                 "foreground_cwd": a.get("foreground_cwd") or a.get("cwd")}
                for a in agents
            ]
        for p in panes:
            cwd = (p.get("foreground_cwd") or p.get("cwd") or "").rstrip("/")
            if not cwd:
                continue
            if want_cwd and cwd != want_cwd:
                continue
            print("\t".join([
                p.get("pane_id") or "?",
                p.get("workspace_id") or "",
                p.get("agent") or "",
                (p.get("agent_status") or "").lower(),
                cwd,
            ]))
        return 0

    if "--verdict" in args:
        pane = arg(args, "--pane")
        if not pane:
            print("herdr-agents[1]{state}:\n  \"--verdict needs --pane\"")
            return 2
        d = fetch_agent(pane)
        code = (d.get("error") or {}).get("code") or ""
        seen = (d.get("result") or {}).get("agent") or {}
        st = (seen.get("agent_status") or "").strip().lower()
        if code == "agent_not_found":
            print("dead\t")
            return 0
        if code or not d:
            print("unsure\t")
            return 0
        kind = (seen.get("agent") or "").strip()
        if st in LIVE:
            verdict = "live"
        elif not kind or st in DEAD:
            verdict = "dead"
        else:
            verdict = "unsure"
        print(f"{verdict}\t{st}")
        return 0

    if "--room" in args:
        label = arg(args, "--label")
        if not label:
            print("herdr-agents[1]{state}:\n  \"--room needs --label\"")
            return 2
        for w in fetch_rooms():
            if (w.get("label") or "") == label:
                print(w.get("workspace_id") or "")
                return 0
        return 0

    if "--pane-room" in args:
        pane = arg(args, "--pane")
        if not pane:
            print("herdr-agents[1]{state}:\n  \"--pane-room needs --pane\"")
            return 2
        try:
            for p in fetch_panes():
                if (p.get("pane_id") or "") == pane:
                    print(p.get("workspace_id") or "")
                    return 0
        except Exception:  # noqa: BLE001
            pass
        for a in agents:
            if (a.get("pane_id") or "") == pane:
                print(a.get("workspace_id") or "")
                return 0
        return 0

    print(f"herdr-agents[{len(agents)}]{{kind,state,pane,cwd,foreground}}:")
    for a in agents:
        kind = a.get("agent") or "?"
        state = a.get("agent_status") or "unknown"
        pane = a.get("pane_id") or "?"
        cwd = a.get("cwd") or "?"
        fg = a.get("foreground_cwd") or cwd
        print(f'  "{kind}","{state}","{pane}","{cwd}","{fg}"')
    return 0


if __name__ == "__main__":
    sys.exit(main())
