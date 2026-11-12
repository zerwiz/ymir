"""Which models an Eindri may run on: the allow-list and its grants.

The allow-list is the operator's own setting, kept in the home and never in this tree
(RULES/04, RULES/07): `<settings>/models-allowed.yaml`, where `<settings>` is
`$YMIR_SETTINGS_DIR`, or `<home>/config` by default. Its shape is in
`config/models-allowed.yaml.example`. Each user writes their own list. This module only
reads it.

Why it exists: on 2026-11-11 workers sent out on a pro model spent a month of
cloud credit in one night. The Allfather's word on 2026-11-12 was that only the models he
approves may run as Eindri, and that any other model needs a special, dated permission.

The rules:

* A model the list allows (an `allow:` glob) is allowed.
* A model an **active grant** names is allowed. The grant must carry a reason, a
  granted-by, a granted-at and an expiry date, and must not have expired. It may also
  carry `uses: N`, a count of launches. Every use of a grant is written to the use log.
* Anything else is **refused**, and the refusal names the model and the remedy.
* A list that exists but cannot be read is a refusal too (fail closed).
* No list at all is `unpoliced`. That answer is allowed, it is said out loud, and the
  doctor reports it. A fresh install that has never written a list keeps working.
* No environment variable allows a model. The only way to allow one is to write it in
  the file.

How a model is named:

* For pi and opencode, as `provider/model`, which is what the catalogue lists.
* For Claude, as `claude/<model-id>`. A request for a family alias (`opus`, `sonnet`,
  `haiku` or `fable`) resolves to the first allowed Claude id of that family. A request
  in another harness's form (`opencode-go/...`) is refused: Claude serves only
  Anthropic models.
* When no model is named, the list's `defaults.<harness>` is used. For Claude with a
  policed list and no default, the answer is a refusal.

Doors: `bin/model/model-allow.sh` (shell) and `check()` (the engine).
"""

from __future__ import annotations

import datetime as _dt
import fnmatch
import json
import os
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Mapping

FILENAME = "models-allowed.yaml"
USE_LOG = "model-allow.log"
CLAUDE_FAMILIES = ("opus", "sonnet", "haiku", "fable")
CLAUDE_PREFIXES = ("claude/", "anthropic/")
EXIT_OK, EXIT_FAULT, EXIT_USAGE, EXIT_REFUSED = 0, 1, 2, 3


# ── where the list lives ─────────────────────────────────────────────────────────


def _home(env: Mapping[str, str]) -> Path:
    explicit = env.get("YMIR_HOME")
    if explicit:
        return Path(explicit).expanduser()
    xdg = env.get("YMIR_CONFIG_DIR") or str(Path(env.get("XDG_CONFIG_HOME") or "~/.config") / "ymir")
    pointer = Path(xdg).expanduser() / "home"
    try:
        recorded = pointer.read_text(encoding="utf-8").splitlines()[0].strip()
    except (OSError, IndexError):
        recorded = ""
    return Path(recorded or "~/Documents/ymirhome").expanduser()


def settings_dir(env: Mapping[str, str] | None = None) -> Path:
    environ = os.environ if env is None else env
    explicit = environ.get("YMIR_SETTINGS_DIR")
    if explicit:
        return Path(explicit).expanduser()
    return _home(environ) / "config"


def state_dir(env: Mapping[str, str] | None = None) -> Path:
    environ = os.environ if env is None else env
    for key in ("BROKK_STATE_OVERRIDE", "YMIR_STATE_DIR"):
        if environ.get(key):
            return Path(environ[key]).expanduser()
    return _home(environ) / "state"


def list_path(env: Mapping[str, str] | None = None) -> Path:
    return settings_dir(env) / FILENAME


# ── the policy ───────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class Grant:
    model: str
    reason: str
    granted_by: str
    granted_at: str
    expires: str
    uses: int | None
    problem: str = ""  # non-empty: the grant is invalid, and this says why

    @property
    def key(self) -> str:
        return f"{self.model}@{self.granted_at}"


@dataclass(frozen=True)
class Policy:
    path: Path
    present: bool
    allow: tuple[str, ...] = ()
    defaults: Mapping[str, str] = field(default_factory=dict)
    grants: tuple[Grant, ...] = ()
    error: str = ""  # the list exists but could not be read: fail closed


def _date(value: object) -> _dt.datetime | None:
    if isinstance(value, _dt.datetime):
        return value if value.tzinfo else value.replace(tzinfo=_dt.timezone.utc)
    if isinstance(value, _dt.date):
        # A bare date is valid through the end of that day.
        return _dt.datetime(value.year, value.month, value.day, 23, 59, 59, tzinfo=_dt.timezone.utc)
    if isinstance(value, str) and value.strip():
        text = value.strip()
        try:
            if len(text) == 10:
                return _date(_dt.date.fromisoformat(text))
            return _date(_dt.datetime.fromisoformat(text.replace("Z", "+00:00")))
        except ValueError:
            return None
    return None


def _grant(row: object) -> Grant:
    if not isinstance(row, dict):
        return Grant("", "", "", "", "", None, problem="a grant row is not a mapping")
    model = str(row.get("model") or "").strip()
    reason = str(row.get("reason") or "").strip()
    by = str(row.get("granted_by") or row.get("granted-by") or "").strip()
    at_raw = row.get("granted_at") or row.get("granted-at") or ""
    exp_raw = row.get("expires") or ""
    uses_raw = row.get("uses")
    at, exp = str(at_raw).strip(), str(exp_raw).strip()
    missing = [n for n, v in (("model", model), ("reason", reason), ("granted_by", by),
                              ("granted_at", at), ("expires", exp)) if not v]
    problem = ""
    if missing:
        problem = "missing " + ", ".join(missing)
    elif _date(exp_raw) is None:
        problem = f"expires '{exp}' is not a date"
    uses: int | None = None
    if uses_raw is not None:
        try:
            uses = int(uses_raw)
        except (TypeError, ValueError):
            problem = problem or f"uses '{uses_raw}' is not a number"
    return Grant(model, reason, by, at, exp, uses, problem)


def load(env: Mapping[str, str] | None = None, path: Path | None = None) -> Policy:
    target = path or list_path(env)
    if not target.exists():
        return Policy(path=target, present=False)
    try:
        import yaml  # PyYAML: a declared dependency of the engine's config layer
    except ImportError:
        return Policy(path=target, present=True, error="PyYAML is missing, so the allow-list cannot be read")
    try:
        data = yaml.safe_load(target.read_text(encoding="utf-8")) or {}
    except Exception as exc:  # noqa: BLE001 - any parse failure is a refusal
        return Policy(path=target, present=True, error=f"the allow-list does not parse: {exc}")
    if not isinstance(data, dict):
        return Policy(path=target, present=True, error="the allow-list is not a mapping")
    allow = data.get("allow") or []
    if not isinstance(allow, list):
        return Policy(path=target, present=True, error="`allow:` is not a list")
    defaults = data.get("defaults") or {}
    if not isinstance(defaults, dict):
        return Policy(path=target, present=True, error="`defaults:` is not a mapping")
    grants = data.get("grants") or []
    if not isinstance(grants, list):
        return Policy(path=target, present=True, error="`grants:` is not a list")
    return Policy(
        path=target,
        present=True,
        allow=tuple(str(a).strip() for a in allow if str(a).strip()),
        defaults={str(k): str(v).strip() for k, v in defaults.items() if v},
        grants=tuple(_grant(g) for g in grants),
    )


# ── the answer ───────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class Verdict:
    harness: str
    request: str
    key: str  # the policed name: provider/model, or claude/<id>
    model: str  # what the launcher is handed (a bare id for Claude)
    verdict: str  # allowed | granted | unpoliced | refused
    rule: str  # the allow glob or the grant key that matched, or empty
    reason: str
    remedy: str = ""
    grant: Grant | None = None

    @property
    def ok(self) -> bool:
        return self.verdict in ("allowed", "granted", "unpoliced")

    def toon(self) -> str:
        cells = (self.harness, self.request, self.model, self.verdict, self.rule, self.reason)
        row = ",".join(json.dumps(c, ensure_ascii=False) for c in cells)
        out = f"model-allow[1]{{harness,request,model,verdict,rule,reason}}:\n  {row}\n"
        if self.remedy:
            out += f"help: {self.remedy}\n"
        return out


def _is_claude(harness: str) -> bool:
    return harness == "claude"


def _claude_ids(policy: Policy) -> list[str]:
    ids = []
    for entry in policy.allow:
        if entry.startswith("claude/") and not any(ch in entry for ch in "*?["):
            ids.append(entry.split("/", 1)[1])
    return ids


def _log_rows(state: Path) -> list[list[str]]:
    try:
        lines = (state / USE_LOG).read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    rows = []
    for line in lines:
        try:
            cells = json.loads("[" + line + "]")
        except ValueError:
            continue
        if isinstance(cells, list) and len(cells) >= 6:
            rows.append([str(c) for c in cells])
    return rows


def _grant_uses(state: Path, grant: Grant, *, exclude_task: str = "") -> int:
    """How many distinct errands have launched on this grant (not counting `exclude_task`).

    One errand is one use, however many doors ask about it: the spawner and the engine
    both gate the same launch, and a relaunch of the same errand is the same use.
    """
    tasks = {r[1] for r in _log_rows(state) if r[4] == "granted" and r[5] == grant.key and r[1]}
    tasks.discard(exclude_task)
    return len(tasks)


def _active_grant(
    policy: Policy, key: str, now: _dt.datetime, state: Path, task: str = ""
) -> tuple[Grant | None, str]:
    """The grant that covers `key`, or None and the reason the nearest one did not."""
    why = ""
    for grant in policy.grants:
        if not grant.model or not fnmatch.fnmatchcase(key, grant.model):
            continue
        if grant.problem:
            why = f"the grant for {grant.model} is invalid ({grant.problem})"
            continue
        expiry = _date(grant.expires)
        if expiry is None or expiry < now:
            why = f"the grant for {grant.model} expired on {grant.expires}"
            continue
        if grant.uses is not None and _grant_uses(state, grant, exclude_task=task) >= grant.uses:
            why = f"the grant for {grant.model} is spent ({grant.uses} use(s))"
            continue
        return grant, ""
    return None, why


def check(
    request: str,
    *,
    harness: str = "",
    env: Mapping[str, str] | None = None,
    policy: Policy | None = None,
    now: _dt.datetime | None = None,
    task: str = "",
) -> Verdict:
    """May this harness run this model? Reads the list; writes nothing."""
    environ = dict(os.environ) if env is None else dict(env)
    pol = policy or load(environ)
    harness = (harness or "").strip()
    req = (request or "").strip()
    moment = now or _dt.datetime.now(_dt.timezone.utc)
    fix = f"add it to `allow:` in {pol.path}, or write a dated grant there (model, reason, granted_by, granted_at, expires)"

    if pol.error:
        return Verdict(harness, req, req, req, "refused", "", pol.error,
                       f"repair {pol.path} (see config/models-allowed.yaml.example)")

    # Fill an empty request from the list's default for this harness.
    if not req or req == "default":
        default = pol.defaults.get(harness, "") if harness else ""
        if default:
            req = default
        elif not pol.present:
            return Verdict(harness, request, "", "", "unpoliced", "", f"no allow-list at {pol.path}; the harness default is served")
        elif _is_claude(harness):
            return Verdict(harness, request, "", "", "refused", "",
                           "the claude harness names no model and the allow-list has no `defaults.claude`",
                           f"set `defaults: {{claude: <id>}}` in {pol.path}, or pass --model")
        else:
            return Verdict(harness, request, "", "", "refused", "",
                           f"no model named for harness '{harness or 'unset'}', and the allow-list has no default for it",
                           f"pass --model with a model on the list, or set `defaults.{harness or '<harness>'}` in {pol.path}")

    # Name the model the way the list does.
    if _is_claude(harness):
        bare = req
        for prefix in CLAUDE_PREFIXES:
            if bare.startswith(prefix):
                bare = bare[len(prefix):]
                break
        if "/" in bare:
            return Verdict(harness, request or req, f"claude/{bare}", bare, "refused", "",
                           f"'{req}' is another harness's model; Claude serves Anthropic models only",
                           "pass a Claude model (an id such as claude-opus-5-5, or the alias opus)")
        if bare.lower() in CLAUDE_FAMILIES:
            family = bare.lower()
            match = next((i for i in _claude_ids(pol) if family in i.lower()), "")
            if match:
                bare = match
            elif not pol.present:
                return Verdict(harness, request or req, f"claude/{bare}", bare, "unpoliced", "",
                               f"no allow-list at {pol.path}; the alias '{bare}' is served as the CLI resolves it")
        key, model = f"claude/{bare}", bare
    else:
        key, model = req, req

    if not pol.present:
        return Verdict(harness, request or req, key, model, "unpoliced", "",
                       f"no allow-list at {pol.path}; every model is allowed until one is written")

    for entry in pol.allow:
        if fnmatch.fnmatchcase(key, entry):
            return Verdict(harness, request or req, key, model, "allowed", entry, "on the allow-list")

    grant, why = _active_grant(pol, key, moment, state_dir(environ), task)
    if grant is not None:
        return Verdict(harness, request or req, key, model, "granted", grant.key,
                       f"granted by {grant.granted_by} until {grant.expires}: {grant.reason}", grant=grant)

    reason = f"model '{key}' is not on this fleet's allow-list"
    if why:
        reason += f"; {why}"
    return Verdict(harness, request or req, key, model, "refused", "", reason, fix)


def record(verdict: Verdict, *, task: str = "", env: Mapping[str, str] | None = None) -> None:
    """Append one row to the use log: every grant use and every refusal at a spawn."""
    state = state_dir(env)
    if verdict.verdict == "granted" and task and any(
        r[1] == task and r[4] == "granted" and r[5] == verdict.rule for r in _log_rows(state)
    ):
        return  # this errand's use is already on the record
    try:
        state.mkdir(parents=True, exist_ok=True)
        stamp = _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        cells = (stamp, task, verdict.harness, verdict.key, verdict.verdict, verdict.rule, verdict.reason)
        with (state / USE_LOG).open("a", encoding="utf-8") as fh:
            fh.write(",".join(json.dumps(c, ensure_ascii=False) for c in cells) + "\n")
    except OSError:
        pass  # a log that cannot be written never turns a refusal into a launch


def enforce(request: str, *, harness: str, task: str = "", env: Mapping[str, str] | None = None) -> Verdict:
    """The spawn door: check, write the use log for a grant or a refusal, return the verdict."""
    verdict = check(request, harness=harness, env=env, task=task)
    if verdict.verdict in ("granted", "refused"):
        record(verdict, task=task, env=env)
    return verdict


# ── the audit (Eir's surface) ────────────────────────────────────────────────────


def _meta(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    try:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                out.setdefault(k, v)
    except OSError:
        pass
    return out


def _status_terminal(path: Path) -> bool:
    try:
        lines = [ln for ln in path.read_text(encoding="utf-8", errors="replace").splitlines() if ln.strip()]
    except OSError:
        return False
    return bool(lines) and lines[-1].split(":", 1)[0].strip() in ("done", "failed")


def _configured(env: Mapping[str, str]) -> list[tuple[str, str, str]]:
    """(source, harness, model) for every model a config hands an Eindri by default."""
    out: list[tuple[str, str, str]] = []
    agents_yaml = settings_dir(env) / "agents.yaml"
    try:
        import yaml

        cfg = yaml.safe_load(agents_yaml.read_text(encoding="utf-8")) or {}
    except Exception:  # noqa: BLE001 - an unreadable config is another surface's finding
        cfg = {}
    if isinstance(cfg, dict):
        h = cfg.get("harness") or {}
        local_p = set((h.get("local_providers") or []) if isinstance(h, dict) else [])

        def harness_for(model: str) -> str:
            prov = model.split("/", 1)[0]
            is_local = prov in local_p or "llama" in prov
            return str((h.get("local") if is_local else h.get("online")) or ("pi" if is_local else "opencode"))

        dm = cfg.get("default_model")
        if isinstance(dm, str) and dm:
            out.append(("agents.yaml:default_model", harness_for(dm), dm))
        for name, row in (cfg.get("agents") or {}).items():
            model = row.get("model") if isinstance(row, dict) else row
            harness_name = row.get("harness") if isinstance(row, dict) else None
            if isinstance(model, str) and model and model != "default":
                if harness_name == "claude" and "/" in model:
                    continue  # the doors drop another harness's model for Claude
                out.append((f"agents.yaml:{name}", str(harness_name or harness_for(model)), model))
    pi_settings = Path(env.get("PI_CODING_AGENT_DIR") or "~/.pi/agent").expanduser() / "settings.json"
    try:
        ps = json.loads(pi_settings.read_text(encoding="utf-8"))
        prov, mod = ps.get("defaultProvider"), ps.get("defaultModel")
        if prov and mod:
            out.append(("pi settings.json default", "pi", f"{prov}/{mod}"))
    except (OSError, ValueError, AttributeError):
        pass
    return out


def audit(state_roots: Iterable[Path], env: Mapping[str, str] | None = None) -> list[tuple[str, str, str, str]]:
    """Every seat not yet finished, and every configured default, that the list refuses."""
    environ = dict(os.environ) if env is None else dict(env)
    pol = load(environ)
    rows: list[tuple[str, str, str, str]] = []
    if not pol.present:
        return rows
    for source, harness_name, model in _configured(environ):
        verdict = check(model, harness=harness_name, env=environ, policy=pol)
        if verdict.verdict == "refused":
            rows.append((source, harness_name, verdict.key, verdict.reason))
    seen: set[str] = set()
    for root in state_roots:
        for meta_path in sorted(Path(root).glob("*.meta")):
            sid = meta_path.stem
            if sid in seen:
                continue
            seen.add(sid)
            if _status_terminal(meta_path.with_suffix(".status")):
                continue
            meta = _meta(meta_path)
            harness = meta.get("harness", "")
            if not harness or meta.get("raw_launch"):
                continue
            verdict = check(meta.get("model", ""), harness=harness, env=environ, policy=pol)
            if verdict.verdict == "refused":
                rows.append((f"seat:{sid}", harness, verdict.key or "<harness default>", verdict.reason))
    return rows


# ── the shell door ───────────────────────────────────────────────────────────────


def _usage() -> int:
    print(
        "usage: model-allow.sh check <provider/model|claude-id|alias> [--harness h] [--for <task-id>]\n"
        "       model-allow.sh default <harness>\n"
        "       model-allow.sh list\n"
        "       model-allow.sh filter [--harness h] < catalogue\n"
        "       model-allow.sh audit [<state-dir> …]\n"
        "       model-allow.sh path",
        file=sys.stderr,
    )
    return EXIT_USAGE


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        return _usage()
    verb, rest = argv[0], argv[1:]
    harness, task, positional = "", "", []
    i = 0
    while i < len(rest):
        arg = rest[i]
        if arg in ("--harness", "--for") and i + 1 < len(rest):
            if arg == "--harness":
                harness = rest[i + 1]
            else:
                task = rest[i + 1]
            i += 2
            continue
        if arg.startswith("--harness="):
            harness = arg.split("=", 1)[1]
        elif arg.startswith("--for="):
            task = arg.split("=", 1)[1]
        else:
            positional.append(arg)
        i += 1

    if verb == "path":
        print(list_path())
        return EXIT_OK

    if verb == "check":
        request = positional[0] if positional else ""
        verdict = enforce(request, harness=harness, task=task) if task else check(request, harness=harness)
        sys.stdout.write(verdict.toon())
        if verdict.verdict == "unpoliced":
            print(f"warning: {verdict.reason}", file=sys.stderr)
        return EXIT_OK if verdict.ok else EXIT_REFUSED

    if verb == "default":
        if not positional:
            return _usage()
        verdict = check("", harness=positional[0])
        if not verdict.ok:
            sys.stdout.write(verdict.toon())
            return EXIT_REFUSED
        print(verdict.model)
        return EXIT_OK

    if verb == "list":
        pol = load()
        if pol.error:
            print(f"error: {pol.error}", file=sys.stderr)
            return EXIT_FAULT
        if not pol.present:
            print(f"model-allow-list{{path,state}}:\n  {json.dumps(str(pol.path))},\"unpoliced\"")
            return EXIT_OK
        now = _dt.datetime.now(_dt.timezone.utc)
        print(f"model-allow-list{{path,state}}:\n  {json.dumps(str(pol.path))},\"policed\"")
        print(f"allow[{len(pol.allow)}]{{glob}}:")
        for entry in pol.allow:
            print(f"  {json.dumps(entry)}")
        print(f"defaults[{len(pol.defaults)}]{{harness,model}}:")
        for k, v in pol.defaults.items():
            print(f"  {json.dumps(k)},{json.dumps(v)}")
        print(f"grants[{len(pol.grants)}]{{model,state,granted_by,granted_at,expires,reason}}:")
        for g in pol.grants:
            exp = _date(g.expires)
            state = "invalid: " + g.problem if g.problem else ("expired" if exp is None or exp < now else "active")
            cells = (g.model, state, g.granted_by, g.granted_at, g.expires, g.reason)
            print("  " + ",".join(json.dumps(c, ensure_ascii=False) for c in cells))
        return EXIT_OK

    if verb == "filter":
        # A catalogue (bin/model/catalog.sh's TOON) on stdin; only the rows this list
        # allows come out, so a resolver that picks from it cannot pick a refused model.
        pol = load()
        for n, line in enumerate(sys.stdin.read().splitlines()):
            if n == 0 or not line.startswith("  "):
                print(line)
                continue
            try:
                cells = json.loads("[" + line.strip() + "]")
            except ValueError:
                continue
            if len(cells) >= 2 and check(f"{cells[0]}/{cells[1]}", harness=harness or "pi", policy=pol).ok:
                print(line)
        return EXIT_OK

    if verb == "audit":
        roots = [Path(p) for p in positional] or [state_dir()]
        rows = audit(roots)
        if not load().present:
            print(f"warning: no allow-list at {list_path()}; nothing is policed", file=sys.stderr)
        print(f"model-audit[{len(rows)}]{{source,harness,model,reason}}:")
        for row in rows:
            print("  " + ",".join(json.dumps(c, ensure_ascii=False) for c in row))
        return EXIT_OK if not rows else EXIT_REFUSED

    return _usage()


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main(sys.argv[1:]))
