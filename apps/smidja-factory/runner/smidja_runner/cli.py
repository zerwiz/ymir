"""`smidja` — the one command for the smithy (skills/smidja-launcher).

Every verb the books teach. Add `--on <host>` to have another machine answer it
over ssh, and `--json` for a machine-clean answer. Exit codes: 0 done · 1 refused ·
2 usage · 3 a run waits for a decision · 4 a run was declined.
"""

from __future__ import annotations

import argparse
import json
import sys

from . import paths, remote, verbs

VERBS_HELP = """verbs:
  up                                converge: clear the kill-switch, raise the viewer
  doctor [--stack S]                what this machine has; must be ready before a run
  chains                            the chains this engine has, with their Phases: line
  run <chain> "<ask>"               launch detached; prints the run id at once
      [--mode M] [--service S] [--stack S] [--model P/M] [--tier T] [--smidja-id ID]
      [--no-done-check] [--dry-run]
  modes | services | rosters        the config's presets, teams and agents
  team list|show|new|smoke [name]   teams are `stacks:` in the config
  model show|set|pin [role] [model] which model a role runs (set prints the export)
  sessions [N]                      the last N runs
  phases|tail|procs|gates|envelopes|record <id>
  stop|pause|continue <id>          control a live run (continue undoes pause)
  steer <id> "msg"                  guidance for the run's next agent call
  resume <id> [--from-phase P] [--dry-run]   restart a dead run at its last green phase
  decide <id> <phase> approve|decline|cancel [--note N]
  emergency-stop                    kill every smithy process; set the kill-switch
  watch [--once] [--interval S]     the watchdog
  audit|diagnose|learn|admit|recover <id>
  kaia "<msg>"                      talk to Völundr
  memory <project> [k] | teach <project>
  mission T1|T2 [--stack S] [--model M]
  agent new <name> --from <role> --purpose "…" [--thinking T] [--tools a,b] [--writes dir/]
  view | ui                         open the viewer (with --on: through an ssh tunnel)
  where                             which engine, config, trace and viewer this machine uses
"""


def _fmt(value, indent: int = 0) -> str:
    pad = "  " * indent
    if isinstance(value, dict):
        lines = []
        for k, v in value.items():
            if isinstance(v, (dict, list)) and v:
                lines.append(f"{pad}{k}:")
                lines.append(_fmt(v, indent + 1))
            else:
                lines.append(f"{pad}{k}: {v if v not in (None, '') else '-'}")
        return "\n".join(lines)
    if isinstance(value, list):
        if value and all(isinstance(v, dict) for v in value):
            keys = list(dict.fromkeys(k for v in value for k in v))
            rows = [[str(v.get(k, "")) .replace("\n", " ")[:80] for k in keys] for v in value]
            widths = [max(len(k), *(len(r[i]) for r in rows)) for i, k in enumerate(keys)]
            out = [pad + "  ".join(k.ljust(widths[i]) for i, k in enumerate(keys))]
            out += [pad + "  ".join(r[i].ljust(widths[i]) for i in range(len(keys))) for r in rows]
            return "\n".join(out)
        return "\n".join(f"{pad}- {v}" for v in value)
    return f"{pad}{value}"


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="smidja", description="The smithy's one command.",
                                epilog=VERBS_HELP, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("verb")
    p.add_argument("args", nargs="*")
    p.add_argument("--on", metavar="HOST", help="have another machine answer, over ssh")
    p.add_argument("--json", action="store_true", help="machine-clean output")
    p.add_argument("--project-dir")
    for flag in ("--mode", "--service", "--stack", "--roster", "--model", "--tier", "--smidja-id",
                 "--from-phase", "--note", "--thinking", "--tools", "--writes", "--purpose"):
        p.add_argument(flag)
    p.add_argument("--from", dest="base")
    p.add_argument("--interval", type=float, default=10.0)
    p.add_argument("--once", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--no-done-check", action="store_true")
    return p


def _arg(args: list[str], i: int, what: str) -> str:
    if len(args) <= i:
        raise verbs.Refusal(f"missing {what}", f"see: smidja --help")
    return args[i]


def dispatch(ns: argparse.Namespace) -> dict:
    w = paths.where(ns.project_dir)
    a = ns.args
    v = ns.verb.replace("_", "-")
    stack = ns.stack or ns.roster
    table = {
        "where": lambda: {k: str(val) for k, val in vars(w).items()},
        "up": lambda: verbs.up(w),
        "doctor": lambda: verbs.doctor(w, stack),
        "chains": lambda: verbs.chains(w),
        "modes": lambda: verbs.modes(w),
        "services": lambda: verbs.services(w),
        "rosters": lambda: verbs.rosters(w),
        "team": lambda: verbs.team(w, a[0] if a else "list", a[1] if len(a) > 1 else ""),
        "model": lambda: verbs.model(w, a[0] if a else "show", a[1] if len(a) > 1 else "",
                                     a[2] if len(a) > 2 else ""),
        "run": lambda: verbs.run(w, a[0] if (a and (len(a) > 1 or not (ns.mode or ns.service))) else "",
                                 a[-1] if a else "", model_id=ns.model, tier=ns.tier, stack=stack,
                                 mode=ns.mode, service=ns.service, smidja_id=ns.smidja_id,
                                 no_done_check=ns.no_done_check, dry_run=ns.dry_run),
        "sessions": lambda: verbs.sessions(w, int(a[0]) if a else 10),
        "phases": lambda: verbs.phases(w, _arg(a, 0, "run id")),
        "tail": lambda: verbs.tail(w, _arg(a, 0, "run id"), int(a[1]) if len(a) > 1 else 25),
        "procs": lambda: verbs.procs(w, _arg(a, 0, "run id")),
        "gates": lambda: verbs.gates(w, _arg(a, 0, "run id")),
        "envelopes": lambda: verbs.envelopes(w, _arg(a, 0, "run id")),
        "record": lambda: verbs.record(w, _arg(a, 0, "run id")),
        "stop": lambda: verbs.stop(w, _arg(a, 0, "run id")),
        "pause": lambda: verbs.pause(w, _arg(a, 0, "run id")),
        "continue": lambda: verbs.cont(w, _arg(a, 0, "run id")),
        "steer": lambda: verbs.steer(w, _arg(a, 0, "run id"), " ".join(a[1:])),
        "resume": lambda: verbs.resume(w, _arg(a, 0, "run id"), ns.from_phase, ns.dry_run),
        "decide": lambda: verbs.decide(w, _arg(a, 0, "run id"), _arg(a, 1, "phase"),
                                       _arg(a, 2, "approve|decline|cancel"), ns.note or ""),
        "emergency-stop": lambda: verbs.emergency_stop(w),
        "watch": lambda: verbs.watch(w, ns.interval, ns.once),
        "audit": lambda: verbs.audit(w, _arg(a, 0, "run id")),
        "diagnose": lambda: verbs.diagnose(w, _arg(a, 0, "run id")),
        "learn": lambda: verbs.learn(w, _arg(a, 0, "run id")),
        "admit": lambda: verbs.admit(w, _arg(a, 0, "run id")),
        "recover": lambda: verbs.recover(w, _arg(a, 0, "run id")),
        "kaia": lambda: verbs.kaia(w, " ".join(a)),
        "memory": lambda: verbs.memory(w, _arg(a, 0, "project"), int(a[1]) if len(a) > 1 else 5),
        "teach": lambda: verbs.teach(w, _arg(a, 0, "project")),
        "mission": lambda: verbs.mission(w, _arg(a, 0, "T1|T2"), stack, ns.model),
        "view": lambda: {"url": w.viewer + "/", "up": verbs.viewer_up(w)},
        "ui": lambda: {"url": w.viewer + "/", "up": verbs.viewer_up(w)},
        "agent": lambda: (verbs.agent_new(w, _arg(a, 1, "role name"), ns.base or "planner", ns.thinking or "medium",
                                          ns.tools or "", ns.writes or "", ns.purpose or "")
                          if a and a[0] == "new" else (_ for _ in ()).throw(
                              verbs.Refusal("smidja agent new <name> --from <role> --purpose \"…\""))),
        "services-list": lambda: verbs.services(w),
    }
    if v not in table:
        raise verbs.Refusal(f"unknown verb {ns.verb!r}", "see: smidja --help")
    return table[v]()


def _remote_argv(argv: list[str]) -> list[str]:
    """The same command line, minus --on and --json (the far side adds --json)."""
    out, skip = [], False
    for i, tok in enumerate(argv):
        if skip:
            skip = False
            continue
        if tok == "--on":
            skip = True
            continue
        if tok.startswith("--on=") or tok == "--json":
            continue
        out.append(tok)
    return out


def execute(argv: list[str]) -> tuple[int, dict]:
    """Parse and run one command line; every door (CLI, MCP) comes through here."""
    ns = build_parser().parse_args(argv)
    try:
        if ns.on:
            if ns.verb == "view":
                result = remote.tunnel(ns.on)
                code = 1 if "refused" in result else 0
            else:
                code, result = remote.call(ns.on, _remote_argv(argv))
            if not isinstance(result, dict):
                result = {"output": result}
        else:
            result, code = dispatch(ns), 0
    except verbs.Refusal as r:
        result, code = {"refused": r.reason, "help": r.help}, 1
    except FileNotFoundError as e:
        result, code = {"refused": str(e)}, 1
    return code, result


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    as_json = "--json" in argv
    try:
        code, result = execute(argv)
    except KeyboardInterrupt:
        return 130
    print(json.dumps(result, indent=2, default=str) if as_json else _fmt(result))
    return code


if __name__ == "__main__":
    sys.exit(main())
