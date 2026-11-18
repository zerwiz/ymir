"""`ymir doctor hermes` — one row per Hermes surface, four states per door, exit 0 only when all answer
(plan 317 §4.3, slice 8).

A check that cannot prove a door answers is not a check: every owned MCP door gets one real
read-only call, and the `ymir` door must answer `ymir_where` from the release the pin points at.
A surface that is not owed yet (the desktop plugin, slice 13) or is the operator's (an entry Ymir
never seated) is reported and never counted red.

States: `yes` · `no` · `—` (does not apply). A row is red when any of its states is `no`.
"""

from __future__ import annotations

import json
import os
import re
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping

from . import common as C
from . import mcp_probe as M
from . import seat as S

PROBE_SKILL = "bragi-documents"
SKILL_BUDGET = 10.0


@dataclass
class Row:
    surface: str
    configured: str = M.NA
    listening: str = M.NA
    authenticated: str = M.NA
    answering: str = M.NA
    detail: str = ""
    counted: bool = True

    @property
    def red(self) -> bool:
        return self.counted and M.NO in (self.configured, self.listening, self.authenticated, self.answering)

    def cells(self) -> tuple[str, ...]:
        return (self.surface, self.configured, self.listening, self.authenticated, self.answering,
                ("RED · " if self.red else "") + self.detail)


def _yn(b: bool) -> str:
    return M.YES if b else M.NO


def descriptor_row(env: Mapping[str, str], root: Path) -> Row:
    path = root.joinpath(*C.DESCRIPTOR)
    r = Row("descriptor")
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        r.configured, r.detail = M.NO, f"no {path}"
        return r
    r.configured = M.YES
    m = re.search(r"^measured_against:\s*['\"]?([0-9.]+)", text, re.M)
    v = C.run([C.hermes_bin(env), "--version"], timeout=30, env=env)
    have = re.search(r"v(\d+\.\d+\.\d+)", v.out or "")
    if not have:
        r.answering, r.detail = M.NO, f"hermes --version did not answer: {(v.err or v.out).strip()[:80]}"
        return r
    want = m.group(1) if m else ""
    r.answering = _yn(want == have.group(1))
    r.detail = (f"measured_against {want} = hermes {have.group(1)}" if want == have.group(1)
                else f"stale descriptor: measured_against {want or '(none)'}, hermes is {have.group(1)}")
    return r


def seat_rows(env: Mapping[str, str]) -> tuple[list[Row], dict, dict]:
    cfg_path, _text, config, packets, ledger = S.read_inputs(env)
    p = S.plan(config, packets, ledger, C.pin_link(env), C.hermes_scripts(env))
    pending = p.pending
    r = Row("seat", configured=_yn(bool(ledger)), answering=_yn(not pending))
    r.detail = ("every owned entry matches the release" if not pending
                else "drift: " + ", ".join(f"{n} ({s})" for n, s, _ in pending) + " — ymir hermes seat")
    return [r], config, ledger


def door_rows(env: Mapping[str, str], config: dict, ledger: dict, *, timeout: float) -> list[Row]:
    rows: list[Row] = []
    servers = (config or {}).get("mcp_servers") or {}
    owned = (ledger or {}).get("mcp_servers") or {}
    pin = C.pin_link(env)
    pin_real = os.path.realpath(pin) if str(pin) not in ("", ".") else ""
    for name, spec in servers.items():
        if not isinstance(spec, dict):
            continue
        if name not in owned:
            rows.append(Row(f"mcp:{name}", configured=M.YES, detail="operator-owned — not Ymir's to probe",
                            counted=False))
            continue
        if not spec.get("enabled", True):
            rows.append(Row(f"mcp:{name}", configured=M.NO, detail="disabled in config.yaml", counted=owned[name].get("state") != "retired"))
            continue
        tool = "ymir_where" if name == "ymir" else ""
        if spec.get("url"):
            pr = M.probe_http(spec["url"], tool=tool, timeout=timeout)
        else:
            pr = M.probe_stdio(str(spec.get("command") or ""), [str(a) for a in spec.get("args") or []], env,
                               extra_env=spec.get("env"), tool=tool, timeout=max(timeout, 30))
        row = Row(f"mcp:{name}", pr.configured, pr.listening, pr.authenticated, pr.answering, pr.detail)
        if name == "ymir" and pr.answering == M.YES:
            repo = next((ln.split(None, 1)[1] for ln in pr.call_text.splitlines() if ln.startswith("repo")), "")
            on_pin = bool(pin_real) and os.path.realpath(repo) == pin_real
            row.answering = _yn(on_pin)
            row.detail = f"{pr.detail}; ymir_where repo {repo or '(no answer)'}" + (
                "" if on_pin else f" — not the pin {pin_real or '(none)'}")
        elif pr.call_text:
            row.detail += f"; {pr.call_text[:60]}"
        rows.append(row)
    return rows


def skills_row(env: Mapping[str, str]) -> Row:
    """The shipped shelf loads from `~`. `hermes skills list` is the local loader's own answer;
    `hermes skills inspect` previews a REGISTRY skill and never sees a local one (measured 2026-11-18)."""
    r = Row("skills", configured=M.YES)
    t0 = time.monotonic()
    res = C.run([C.hermes_bin(env), "skills", "list"], timeout=SKILL_BUDGET + 20, env=env,
                cwd=str(C.user_home(env)))
    took = time.monotonic() - t0
    line = next((ln for ln in (res.out or "").splitlines() if re.search(rf"\b{re.escape(PROBE_SKILL)}\b", ln)), "")
    found = res.rc == 0 and "enabled" in line
    r.answering = _yn(found and took <= SKILL_BUDGET)
    where = "external" if "external" in line else ("local" if line else "absent")
    r.detail = (f"`hermes skills list` from ~ in {took:.1f}s: {PROBE_SKILL} {where}"
                + (", enabled" if found else f" — exit {res.rc}: {(res.err or '').strip()[:80]}"))
    return r


def hooks_rows(env: Mapping[str, str], config: dict) -> list[Row]:
    rows: list[Row] = []
    doc = C.run([C.hermes_bin(env), "hooks", "doctor"], timeout=90, env=env)
    text = (doc.out or "") + (doc.err or "")
    bad = re.findall(r"(?im)^.*\b(error|fail|unhealthy|invalid)\b.*$", text)
    rows.append(Row("hooks", configured=_yn(bool((config or {}).get("hooks"))), answering=_yn(doc.rc == 0 and not bad),
                    detail=f"hermes hooks doctor exit {doc.rc}" + (f": {bad[0].strip()[:80]}" if bad else "")))
    entries = ((config or {}).get("hooks") or {}).get("pre_llm_call") or []
    cmd = next((e.get("command") for e in entries if isinstance(e, dict) and "ymir" in str(e.get("command"))), "")
    r = Row("digest", configured=_yn(bool(cmd)))
    if cmd:
        sid = f"ymir-doctor-{C.stamp().lower()}"
        payload = json.dumps({"hook_event_name": "pre_llm_call", "session_id": sid,
                              "cwd": str(C.user_home(env)), "extra": {"is_first_turn": True}})
        res = C.run([str(cmd)], timeout=60, env=env, cwd=str(C.user_home(env)), input_text=payload)
        try:
            got = json.loads((res.out or "{}").strip().splitlines()[-1])
        except (ValueError, IndexError):
            got = {}
        r.answering = _yn("context" in got)
        r.detail = ("a synthetic first turn from ~ received the digest"
                    if "context" in got else f"a synthetic first turn from ~ got {(res.out or '').strip()[:40] or 'nothing'}"
                    + f" (exit {res.rc}) — the seated hook runs {cmd}")
        state = C.state_dir(env)
        for f in (state / f"digest.{sid}.md", state / f"injected.{sid}"):
            try:
                f.unlink()
            except FileNotFoundError:
                pass
    rows.append(r)
    return rows


def cron_row(env: Mapping[str, str], ledger: dict) -> Row:
    script = C.hermes_scripts(env) / S.WORKERS_SCRIPT
    r = Row("cron", configured=_yn(script.exists()))
    pin = C.pin_link(env)
    target = pin / "src" / "ymir_runtime" / "hermes" / "cli.py"
    r.answering = _yn(script.exists() and target.exists())
    jobs = C.run([C.hermes_bin(env), "cron", "list"], timeout=60, env=env)
    ours = len(re.findall(r"ymir-workers\.py", jobs.out or ""))
    r.detail = (f"{script.name} seated; the pin {'carries' if target.exists() else 'LACKS'} the verb it imports; "
                f"{ours} Hermes cron job(s) run it (none is the notes road the Allfather chose)")
    if not script.exists():
        r.detail = f"{script} not seated — ymir hermes seat"
    return r


def desktop_row(env: Mapping[str, str]) -> Row:
    plugin = C.hermes_home(env) / "desktop-plugins" / "hlidskjalf-lite" / "plugin.js"
    return Row("desktop", configured=_yn(plugin.exists()), counted=False,
               detail=("plugin present" if plugin.exists() else "no desktop plugin yet — plan 317 slice 13, not owed"))


def pin_row(env: Mapping[str, str]) -> Row:
    pin = C.pin_link(env)
    real = os.path.realpath(pin) if str(pin) not in ("", ".") else ""
    return Row("pin", configured=_yn(bool(real)), answering=_yn(bool(real) and Path(real).is_dir()),
               detail=f"{pin} -> {real}" if real else "no pin on this seat")


def doctor(env: Mapping[str, str] | None = None, *, out: Callable[[str], None] = print, timeout: float = 10.0) -> int:
    env = C.environ(env)
    if C.run([C.hermes_bin(env), "--version"], timeout=30, env=env).rc == 127:
        out("hermes_doctor: hermes is not installed on this seat — a clean skip (RULES/25)")
        return 0
    rows: list[Row] = [descriptor_row(env, C.tree_root()), pin_row(env)]
    try:
        s_rows, config, ledger = seat_rows(env)
    except C.HermesError as exc:
        s_rows, config, ledger = [Row("seat", configured=M.NO, detail=str(exc))], {}, {}
    rows += s_rows
    rows += door_rows(env, config, ledger, timeout=timeout)
    rows.append(skills_row(env))
    rows += hooks_rows(env, config)
    rows.append(cron_row(env, ledger))
    rows.append(desktop_row(env))
    out(f"hermes_doctor[{len(rows)}]{{surface,configured,listening,authenticated,answering,detail}}:")
    for r in rows:
        out(C.row(*r.cells()))
    red = [r.surface for r in rows if r.red]
    out(f"hermes_doctor: {'all answer' if not red else str(len(red)) + ' red: ' + ', '.join(red)}")
    return 1 if red else 0
