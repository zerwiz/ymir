"""The Smíðja MCP — the smithy's verbs as tools, for every harness.

Claude Code, Codex, pi, Hermes and OpenCode all seat this one stdio server, so any
of them can start, watch and steer a run. Inside the run only pi works; this door
never changes that. Every tool is a command line handed to `cli.execute`, so a
tool can do nothing the `smidja` command cannot, and every tool takes `on` to have
another machine answer over ssh.

Stdlib only: newline-delimited JSON-RPC 2.0 on stdin/stdout (MCP stdio).
"""

from __future__ import annotations

import json
import sys

from . import cli

PROTOCOL = "2024-11-05"
ON = {"on": {"type": "string", "description": "another machine (an ssh host) to answer this; omit for this machine"}}
RUN_ID = {"smidja_id": {"type": "string", "description": "the run id"}}


def _schema(props: dict, required: list[str] | None = None) -> dict:
    return {"type": "object", "properties": {**props, **ON}, "required": required or []}


TOOLS = {
    "smidja_doctor": ("What this machine (or `on`) has for the smithy, and whether a run can start.",
                      _schema({"stack": {"type": "string"}}),
                      lambda a: ["doctor"] + (["--stack", a["stack"]] if a.get("stack") else [])),
    "smidja_up": ("Converge: clear the kill-switch and raise the viewer.", _schema({}), lambda a: ["up"]),
    "smidja_chains": ("The chains the engine has, with each one's Phases line.", _schema({}), lambda a: ["chains"]),
    "smidja_rosters": ("The config's agents and models, teams (stacks), modes or services.",
                       _schema({"what": {"type": "string", "enum": ["rosters", "modes", "services"]}}),
                       lambda a: [a.get("what") or "rosters"]),
    "smidja_run": ("Launch a chain DETACHED and return its run id at once. The ask must carry a "
                   "'Done means:' line. Only pi works inside the run.",
                   _schema({"chain": {"type": "string"}, "ask": {"type": "string"},
                            "mode": {"type": "string"}, "service": {"type": "string"},
                            "stack": {"type": "string", "description": "a team from the config"},
                            "model": {"type": "string", "description": "provider/model for every agent"},
                            "tier": {"type": "string"}, "project_dir": {"type": "string"},
                            "dry_run": {"type": "boolean"}}, ["ask"]),
                   lambda a: (["run"] + ([a["chain"]] if a.get("chain") else []) + [a["ask"]]
                              + sum(([f"--{k.replace('_', '-')}", str(a[k])] for k in
                                     ("mode", "service", "stack", "model", "tier", "project_dir") if a.get(k)), [])
                              + (["--dry-run"] if a.get("dry_run") else []))),
    "smidja_sessions": ("Recent runs: id, status, tokens.", _schema({"n": {"type": "integer"}}),
                        lambda a: ["sessions", str(a.get("n") or 10)]),
    "smidja_record": ("One run as phases · steps · state · where it stopped.", _schema(RUN_ID, ["smidja_id"]),
                      lambda a: ["record", a["smidja_id"]]),
    "smidja_phases": ("A run's phases and their status.", _schema(RUN_ID, ["smidja_id"]),
                      lambda a: ["phases", a["smidja_id"]]),
    "smidja_events": ("A run's latest events (the live tail).",
                      _schema({**RUN_ID, "n": {"type": "integer"}}, ["smidja_id"]),
                      lambda a: ["tail", a["smidja_id"], str(a.get("n") or 25)]),
    "smidja_gates": ("Why a phase failed: every gate result.", _schema(RUN_ID, ["smidja_id"]),
                     lambda a: ["gates", a["smidja_id"]]),
    "smidja_envelopes": ("The typed outputs each agent returned.", _schema(RUN_ID, ["smidja_id"]),
                         lambda a: ["envelopes", a["smidja_id"]]),
    "smidja_control": ("Control a live run: stop · pause · continue · steer (with message).",
                       _schema({**RUN_ID, "action": {"type": "string", "enum": ["stop", "pause", "continue", "steer"]},
                                "message": {"type": "string"}}, ["smidja_id", "action"]),
                       lambda a: [a["action"], a["smidja_id"]] + ([a["message"]] if a["action"] == "steer" else [])),
    "smidja_emergency_stop": ("Kill every smithy process and set the kill-switch (a runaway).",
                              _schema({}), lambda a: ["emergency-stop"]),
    "smidja_resume": ("Restart a dead run at its last green phase.",
                      _schema({**RUN_ID, "from_phase": {"type": "string"}, "dry_run": {"type": "boolean"}}, ["smidja_id"]),
                      lambda a: ["resume", a["smidja_id"]] + (["--from-phase", a["from_phase"]] if a.get("from_phase") else [])
                      + (["--dry-run"] if a.get("dry_run") else [])),
    "smidja_decide": ("Settle an approval phase: approve · decline · cancel.",
                      _schema({**RUN_ID, "phase": {"type": "string"},
                               "decision": {"type": "string", "enum": ["approve", "decline", "cancel"]},
                               "note": {"type": "string"}}, ["smidja_id", "phase", "decision"]),
                      lambda a: ["decide", a["smidja_id"], a["phase"], a["decision"]] + (["--note", a["note"]] if a.get("note") else [])),
    "smidja_judge": ("Judge a run: audit (tool-call evidence, gates) or diagnose (why, and the fix).",
                     _schema({**RUN_ID, "how": {"type": "string", "enum": ["audit", "diagnose"]}}, ["smidja_id"]),
                     lambda a: [a.get("how") or "diagnose", a["smidja_id"]]),
    "smidja_memory": ("Völundr's memory: recall a project, learn from a run, or teach a project.",
                      _schema({"action": {"type": "string", "enum": ["recall", "learn", "teach"]},
                               "project": {"type": "string"}, "smidja_id": {"type": "string"}}, ["action"]),
                      lambda a: {"recall": ["memory", a.get("project") or ""],
                                 "learn": ["learn", a.get("smidja_id") or ""],
                                 "teach": ["teach", a.get("project") or ""]}[a["action"]]),
    "smidja_volundr": ("Talk to Völundr, or ask for a run's admission notes or recovery decision.",
                       _schema({"message": {"type": "string"}, "smidja_id": {"type": "string"},
                                "ask": {"type": "string", "enum": ["talk", "admit", "recover"]}}),
                       lambda a: (["kaia", a.get("message") or ""] if (a.get("ask") or "talk") == "talk"
                                  else [a["ask"], a.get("smidja_id") or ""])),
}


def call_tool(name: str, args: dict) -> tuple[bool, dict]:
    if name not in TOOLS:
        return False, {"refused": f"no tool {name}"}
    argv = TOOLS[name][2](args) + ["--json"]
    if args.get("on"):
        argv += ["--on", args["on"]]
    code, result = cli.execute(argv)
    return code == 0, result


def handle(msg: dict) -> dict | None:
    method, mid = msg.get("method"), msg.get("id")
    if mid is None:
        return None                                # a notification
    if method == "initialize":
        result = {"protocolVersion": (msg.get("params") or {}).get("protocolVersion") or PROTOCOL,
                  "capabilities": {"tools": {}},
                  "serverInfo": {"name": "smidja", "version": "1.0.0"},
                  "instructions": "Smíðja, the smithy. Start a run with smidja_run (detached; the ask needs a "
                                  "'Done means:' line), watch it with smidja_record/smidja_events, judge it with "
                                  "smidja_judge. Only pi works inside a run. Every tool takes `on` for another machine."}
    elif method == "tools/list":
        result = {"tools": [{"name": n, "description": d, "inputSchema": s} for n, (d, s, _) in TOOLS.items()]}
    elif method == "tools/call":
        p = msg.get("params") or {}
        ok, data = call_tool(p.get("name", ""), p.get("arguments") or {})
        result = {"content": [{"type": "text", "text": json.dumps(data, indent=2, default=str)}], "isError": not ok}
    elif method == "ping":
        result = {}
    else:
        return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": f"no method {method}"}}
    return {"jsonrpc": "2.0", "id": mid, "result": result}


def main() -> int:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        try:
            reply = handle(msg)
        except Exception as e:   # one bad call must never take the door down
            reply = {"jsonrpc": "2.0", "id": msg.get("id"), "error": {"code": -32603, "message": str(e)}}
        if reply is not None:
            sys.stdout.write(json.dumps(reply) + "\n")
            sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
