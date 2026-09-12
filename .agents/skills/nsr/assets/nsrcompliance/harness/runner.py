#!/usr/bin/env python3
# harness runner: orchestrates feature scripts + gates and validates typed envelopes.
# Self-contained: resolves the repo root relative to this file, so it runs from
# the compliance skill (.agents/skills/NSRcompliance/) OR from a generated .compliance/ tree.
import argparse
import json
import pathlib
import subprocess
import sys
import time


def find_root():
    for parent in pathlib.Path(__file__).resolve().parents:
        if (parent / ".agents").is_dir():
            return parent
    raise SystemExit("error: no repo root (.agents/ not found upward from runner)")


ROOT = find_root()
SKILL = ROOT / ".agents" / "skills" / "compliance"
FEATURES = ROOT / ".agents" / "skills" / "features"

GATES_MAIN = ROOT / ".compliance" / "gates"
GATES_SKILL = SKILL / "gates"

ENVELOPES_MAIN = ROOT / ".compliance" / "harness" / "envelopes"
ENVELOPES_SKILL = SKILL / "harness" / "envelopes"

TELEMETRY_MAIN = ROOT / ".compliance" / "telemetry" / "logger.py"
TELEMETRY_SKILL = SKILL / "telemetry" / "logger.py"

ACTIONS = ["setup", "test", "smoke_test", "rollback", "start", "stop", "status"]


def first_existing(*paths):
    for p in paths:
        if p.exists():
            return p
    return None


def envelopes_dir():
    d = first_existing(ENVELOPES_MAIN, ENVELOPES_SKILL)
    if d is None:
        d = ENVELOPES_SKILL
        d.mkdir(parents=True, exist_ok=True)
    return d


def telemetry_logger():
    return first_existing(TELEMETRY_MAIN, TELEMETRY_SKILL)


# --- danger model (mirrors .compliance/gates/check_danger.sh) -------------------
DANGER_PRIMS = [
    r"rm[ \t]+-rf", r"rm[ \t]+-fr",
    r":\(\)", r"kill[ \t]+-9", r"\bpkill\b", r"\btaskkill\b",
    r"git[ \t]+push[ \t]+--force", r"git[ \t]+reset[ \t]+--hard",
    r"DROP[ \t]+(TABLE|DATABASE)", r"TRUNCATE[ \t]+TABLE",
    r"dd[ \t]+if=", r"\bmkfs\b", r"chmod[ \t]+-R[ \t]+777",
    r"curl[ \t].*\|[ \t]*sh", r"wget[ \t].*\|[ \t]*sh",
]
GATE_RE = r"^[ \t]*# gate:[ \t]*(dev|guard|human)([ \t:]+|$)"


def gate_level(script):
    if not pathlib.Path(script).exists():
        return "none"
    text = pathlib.Path(script).read_text(errors="ignore")
    m = __import__("re").search(GATE_RE, text, __import__("re").M | __import__("re").I)
    if m:
        return m.group(1).lower()
    if any(__import__("re").search(p, text, __import__("re").I) for p in DANGER_PRIMS):
        return "ungated"
    return "none"


# --- gates -------------------------------------------------------------------
def run_gates():
    results = {}
    if not GATES_MAIN.is_dir():
        print("[harness] no gates at %s" % GATES_MAIN.relative_to(ROOT))
        return {}
    for gate in sorted(GATES_MAIN.glob("*.sh")):
        print("[harness] gate %s" % gate.name)
        results[gate.name] = subprocess.run(["bash", str(gate)], cwd=ROOT).returncode
    return results


# --- feature scripts ---------------------------------------------------------
def run_feature(feature, action):
    script = FEATURES / feature / ("%s.sh" % action)
    if not script.exists():
        return 1, "missing script: %s" % script.relative_to(ROOT)
    level = gate_level(script)
    print("[harness] running %s (gate: %s)" % (script.relative_to(ROOT), level))
    rc = subprocess.run(["bash", str(script)], cwd=ROOT).returncode
    return rc, "%s:%s" % (feature, action), level


# --- envelopes ---------------------------------------------------------------
def satisfies(ftype, value):
    if ftype == "string":
        return isinstance(value, str)
    if ftype == "array":
        return isinstance(value, list)
    if ftype == "object":
        return isinstance(value, dict)
    if ftype == "boolean":
        return isinstance(value, bool)
    if ftype == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if ftype == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    return True


def validate_envelope(data, schema):
    errors = []
    for name, spec in schema.get("fields", {}).items():
        if spec.get("required", False) and name not in data:
            errors.append("missing required field: %s" % name)
            continue
        if name not in data:
            continue
        value = data[name]
        ftype = spec.get("type")
        if ftype and not satisfies(ftype, value):
            errors.append("field %s: expected %s, got %s" % (name, ftype, type(value).__name__))
            continue
        if ftype == "array" and isinstance(value, list):
            item_type = (spec.get("items") or {}).get("type")
            for i, item in enumerate(value):
                if item_type and not satisfies(item_type, item):
                    errors.append("field %s[%d]: expected %s" % (name, i, item_type))
        enum = spec.get("enum")
        if enum and value not in enum:
            errors.append("field %s: must be one of %s, got %r" % (name, enum, value))
    return errors


def load_envelope(path, schema):
    try:
        data = json.loads(pathlib.Path(path).read_text())
    except (OSError, ValueError) as exc:
        return None, ["cannot read envelope %s: %s" % (path, exc)]
    return data, validate_envelope(data, schema)


def load_schema():
    schema = first_existing(ENVELOPES_MAIN / "task_envelope.json",
                            ENVELOPES_SKILL / "task_envelope.json")
    if schema is None:
        raise SystemExit("error: task_envelope.json schema not found")
    return json.loads(schema.read_text())


# --- observability -----------------------------------------------------------
def telemetry(phase, status, latency_ms=0.0, run_id=None):
    logger = telemetry_logger()
    if logger is None:
        return
    cmd = ["python3", str(logger), "log", "--phase", phase, "--status", status,
           "--latency-ms", str(latency_ms)]
    if run_id:
        cmd += ["--run-id", run_id]
    subprocess.run(cmd, cwd=ROOT)


def write_result(task_id, status, gates, detail, error):
    result = {
        "envelope": "result",
        "task_id": task_id,
        "status": status,
        "gates": gates,
        "evidence": ["gates pass"] if status == "success" else [],
        "ts": time.time(),
    }
    if detail:
        result["artifacts"] = [detail]
    if error:
        result["error"] = error
    out = envelopes_dir() / ("result_%s.json" % task_id)
    out.write_text(json.dumps(result, indent=2) + "\n")
    print("[harness] wrote %s" % out.relative_to(ROOT))


# --- commands ----------------------------------------------------------------
def cmd_envelope(args):
    data, errors = load_envelope(args.envelope, load_schema())
    for err in errors:
        print("[harness] ENVELOPE FAIL: %s" % err, file=sys.stderr)
    if not errors:
        print("[harness] envelope OK: %s (task %s)" % (args.envelope, data.get("task_id")))
    return 1 if errors else 0


def cmd_plan(args):
    data, errors = load_envelope(args.plan, load_schema())
    task_id = (data or {}).get("task_id", "unknown")
    if errors:
        for err in errors:
            print("[harness] ENVELOPE FAIL: %s" % err, file=sys.stderr)
        write_result(task_id, "fail", {}, None, "envelope invalid")
        telemetry("plan", "fail")
        return 1

    gates = run_gates()
    gate_fail = [name for name, rc in gates.items() if rc != 0]
    if gate_fail:
        print("[harness] PLAN FAIL: gates failed: %s" % ", ".join(gate_fail))
        write_result(task_id, "fail", gates, None, "gates failed")
        telemetry("plan", "fail")
        return 1

    script = FEATURES / data["feature"] / ("%s.sh" % args.action)
    level = gate_level(script) if script.exists() else "none"
    if level in ("human", "guard") and not args.confirm_gate:
        print("[harness] PLAN REFUSED: %s %s is gated '%s' (irreversible); "
              "human must run it or pass --confirm-gate" % (data["feature"], args.action, level))
        write_result(task_id, "escalate", gates, None, "human-gated script")
        telemetry("plan", "escalate")
        return 1
    if level == "ungated":
        print("[harness] PLAN FAIL: script has dangerous primitives but no # gate: annotation")
        write_result(task_id, "fail", gates, None, "ungated dangerous script")
        telemetry("plan", "fail")
        return 1

    t0 = time.time()
    rc, detail, _ = run_feature(data["feature"], args.action)
    if rc != 0:
        print("[harness] PLAN FAIL: feature %s %s failed" % (data["feature"], args.action))
        write_result(task_id, "fail", gates, detail, "feature failed")
        telemetry("plan", "fail", latency_ms=(time.time() - t0) * 1000.0)
        return 1

    print("[harness] PLAN PASS")
    write_result(task_id, "success", gates, detail, None)
    telemetry("plan", "success", latency_ms=(time.time() - t0) * 1000.0)
    return 0


def stub_marker(path):
    try:
        return bool(__import__("re").search(r"\bSTUB\b|# stub[: ]", path.read_text(errors="ignore"), __import__("re").I))
    except (OSError, ValueError):
        return True


def cmd_list(_args):
    print("[harness] registry (root %s)" % ROOT)
    for domain in ("lifecycle", "git_ops", "features"):
        d = ROOT / ".agents" / "skills" / domain
        if not d.is_dir():
            continue
        scripts = sorted(p.name for p in d.glob("*.sh"))
        if not scripts:
            continue
        print("  %s/  %s" % (domain, " ".join(scripts)))
    fdir = FEATURES
    print("[harness] features: %s" % (" ".join(sorted(p.name for p in fdir.iterdir() if p.is_dir()))
                                      if fdir.is_dir() else "(none)"))
    for feature_dir in sorted(fdir.iterdir()) if fdir.is_dir() else []:
        if not feature_dir.is_dir():
            continue
        line = []
        for s in sorted(feature_dir.glob("*.sh")):
            line.append("%s%s" % (s.stem, "*STUB" if stub_marker(s) else ""))
        print("  features/%s  %s" % (feature_dir.name, " ".join(line)))
    return 0


def main():
    p = argparse.ArgumentParser(description="WayOfNorthStar deterministic harness runner (self-contained)")
    p.add_argument("--envelope", metavar="FILE", help="validate a task envelope; exit 1 on violation")
    p.add_argument("--plan", metavar="ENVELOPE", help="full run: envelope -> gates -> feature -> result envelope")
    p.add_argument("--feature", help="feature name under .agents/skills/features/")
    p.add_argument("--action", choices=ACTIONS, default="test")
    p.add_argument("--gates", action="store_true", help="run all validation gates")
    p.add_argument("--list", action="store_true", help="show the script registry (stubs flagged)")
    p.add_argument("--confirm-gate", action="store_true", help="allow running a human/guard-gated script")
    a = p.parse_args()

    if a.list:
        return cmd_list(a)
    if a.envelope:
        return cmd_envelope(a)
    if a.plan:
        return cmd_plan(a)
    if a.gates:
        results = run_gates()
        return 0 if all(rc == 0 for rc in results.values()) else 1
    if a.feature:
        rc, _, _ = run_feature(a.feature, a.action)
        return rc
    p.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())