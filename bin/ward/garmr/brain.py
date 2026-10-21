"""brain.py — the hound's judgement: read findings, apply the rules, speak, record.

    brain.py --once          # one pass over the findings since the last offset (the timer)
    brain.py --follow        # watch
    brain.py --file F --once # judge a fixture (tests)
    brain.py --dry-run       # say what it WOULD do, write nothing

Nothing here is a model call except the ladder, and the ladder is only climbed at or
above `escalate.on` and only for a finding the rules did not suppress. The alert is
always the template: "CRITICAL: curl (pid 1234, uid 1000) opened protected <sensitive:…> at …".
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import rules  # noqa: E402

MAX_SEEN = 5000


def _paths(cfg: dict) -> tuple[str, str, str]:
    state = common.state_dir()
    return (cfg["hound"]["findings"],
            os.path.join(state, "offset"),
            os.path.join(state, "judged.jsonl"))


def _load_offset(path: str) -> int:
    try:
        return int(open(path).read().strip() or 0)
    except Exception:
        return 0


def _save_offset(path: str, value: int) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as handle:
        handle.write(str(value))


def _speak(line: str, cfg: dict) -> None:
    if not cfg.get("alert", {}).get("desktop", True):
        return
    script = os.path.join(common.repo_root(), "bin", "time", "snotra", "ymir-say.sh")
    if not os.path.isfile(script):
        return
    try:
        subprocess.run(["bash", script, line[:240]], timeout=15, check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def _rune(line: str, cfg: dict) -> None:
    script = os.path.join(common.repo_root(), "bin", "records", "runes-append.sh")
    if not os.path.isfile(script):
        return
    try:
        subprocess.run(["bash", script, "garmr", line[:400]], timeout=20, check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def _phone(line: str, severity: str, cfg: dict) -> dict | None:
    """The bark reaches the pocket (plan 99 P0). Never blocks the desktop alert."""
    phone = ((cfg.get("alert", {}) or {}).get("phone") or "none").lower()
    if phone in ("", "none"):
        return None
    threshold = rules.ORDER.get(str((cfg.get("alert", {}) or {}).get("phone_at", "high")).upper(), 2)
    if rules.ORDER.get(severity, 0) < threshold:
        return None
    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "notify.py")
    try:
        proc = subprocess.run([sys.executable, script, "--severity", severity, "--line", line],
                              capture_output=True, text=True, timeout=20)
        for row in (proc.stdout or "").splitlines():
            if row.strip().startswith("{"):
                return json.loads(row)
    except Exception:
        return None
    return None


def _escalate(finding: dict, severity: str, context: list[dict], cfg: dict) -> dict | None:
    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "escalate.py")
    try:
        proc = subprocess.run(
            [sys.executable, script, "--finding", json.dumps(finding), "--severity", severity],
            capture_output=True, text=True, timeout=240)
    except Exception:
        return None
    for line in (proc.stdout or "").splitlines():
        if line.strip().startswith("{"):
            try:
                return json.loads(line)
            except ValueError:
                continue
    return None


def paused() -> bool:
    """Paused is ROOT's word: the marker lives in the hound's own state, so a
    process running as the operator cannot silence the judgement."""
    return os.path.exists(common.pause_marker()) or os.path.exists(
        os.path.join(common.state_dir(), "PAUSED"))


def judge(rows: list[dict], cfg: dict, dry_run: bool = False,
          max_escalations: int = 1, escalate_ok: bool = True) -> list[dict]:
    threshold = rules.ORDER.get(str(cfg.get("escalate", {}).get("on", "high")).upper(), 2)
    budget = max_escalations
    out = []
    context: list[dict] = []
    for finding in rows:
        verdict = rules.evaluate(finding, cfg)
        record = {**finding, **verdict}
        context.append({k: record.get(k) for k in ("ts", "kind", "comm", "pid", "uid",
                                                   "target", "argv", "peer", "addr")})
        if verdict["severity"] == "INFO":
            out.append(record)
            continue
        if (escalate_ok and budget > 0 and not dry_run
                and rules.ORDER.get(verdict["severity"], 0) >= threshold
                and not verdict["suppress"]):
            budget -= 1
            answer = _escalate(record, verdict["severity"], context, cfg)
            if answer:
                record["reasoning"] = answer
        out.append(record)
        if not dry_run:
            _rune(verdict["line"], cfg)
            if verdict["severity"] in ("HIGH", "CRITICAL"):
                phone = _phone(verdict["line"], verdict["severity"], cfg)
                if phone:
                    record["phone"] = phone
            if rules.ORDER.get(verdict["severity"], 0) >= rules.ORDER["HIGH"]:
                _speak(verdict["line"], cfg)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Garmr's judgement")
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--follow", action="store_true")
    parser.add_argument("--file")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-escalate", action="store_true", help="rules only, no model")
    parser.add_argument("--max-escalations", type=int, default=1,
                        help="how many findings may be reasoned about in one pass (default 1)")
    args = parser.parse_args()

    cfg = common.load_config()
    if paused() and not args.file:
        print("garmr: the hound is PAUSED — nothing judged (bin/ward/garmr.sh resume)")
        return 0
    findings, offset_path, judged_path = _paths(cfg)
    source = args.file or findings
    if not os.path.exists(source):
        print(f"garmr: no findings yet at {source} — the hound has not written any")
        return 0

    start = 0 if args.file else _load_offset(offset_path)
    with open(source) as handle:
        handle.seek(start)
        rows = []
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except ValueError:
                continue
        end = handle.tell()
    judged = judge(rows, cfg, args.dry_run,
                   max_escalations=max(0, args.max_escalations),
                   escalate_ok=not args.no_escalate)

    if not args.dry_run:
        os.makedirs(os.path.dirname(judged_path), exist_ok=True)
        with open(judged_path, "a") as handle:
            for row in judged:
                handle.write(common.emit(row) + "\n")
        if not args.file:
            _save_offset(offset_path, end)

    counts: dict[str, int] = {}
    for row in judged:
        counts[row["severity"]] = counts.get(row["severity"], 0) + 1
    if judged:
        print(common.emit({"judged": len(judged), "by_severity": counts,
                           "escalated": sum(1 for r in judged if r.get("reasoning"))}))
    for row in judged:
        if row["severity"] in ("HIGH", "CRITICAL"):
            print(row["line"])
        if row.get("reasoning", {}).get("text"):
            print(f"  ↳ {row['reasoning']['rung']}/{row['reasoning']['model']}: "
                  f"{row['reasoning']['text'][:300]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
