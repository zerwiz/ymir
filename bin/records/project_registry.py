#!/usr/bin/env python3
"""project_registry.py — the reader behind bin/records/project.sh (plan 345).

How every project is handled lives in ONE place: the `handling:` block of each row of the home's project registry
(`hodd/identity/projects.yaml`). Its shape is `config/projects.schema.json`. This module reads it, answers one field,
audits every row, and renders the page a person reads.

    project_registry.py <id>                    the row's handling block
    project_registry.py <id> --field delivery   one field (dotted: delivery.road)
    project_registry.py <id> --field f --json   the same, as JSON
    project_registry.py --list                  id · visibility · plans · road, one line each
    project_registry.py --audit [--quiet]       rows missing visibility / plans / delivery, and every schema finding
    project_registry.py --page                  the Markdown page for people (one table, a column per question)

Every command takes `--registry PATH` (a fixture, or another home) and `--schema PATH`.
Exit codes: 0 answered · 1 a finding (audit) or no such field · 2 usage, or no such project/registry.
"""
from __future__ import annotations

import json
import os
import sys

try:
    import yaml
except ImportError:  # pragma: no cover
    print("project.sh: python3 needs PyYAML", file=sys.stderr)
    sys.exit(2)

AUDIT_REQUIRED = ("visibility", "plans", "delivery")
QUESTIONS = ("visibility", "plans", "board", "people", "private_to", "delivery", "deploy", "secrets")
# plan 346's fourteen, each `{value, source}` | `unmeasured` | OWED
FOURTEEN = ("environments", "domains", "data_class", "models_allowed", "licence", "upstream", "scanning", "backups",
            "costs", "clients", "access", "keepers", "lifecycle", "merge_account", "toolchain", "monitoring")


def die(msg: str, code: int = 2) -> None:
    print(f"project.sh: {msg}", file=sys.stderr)
    sys.exit(code)


def load(path: str) -> list[dict]:
    if not os.path.isfile(path):
        die(f"no registry at {path}")
    with open(path, encoding="utf-8") as fh:
        doc = yaml.safe_load(fh) or {}
    rows = doc.get("projects")
    if not isinstance(rows, list):
        die(f"{path}: no `projects:` list")
    return [r for r in rows if isinstance(r, dict)]


def find(rows: list[dict], key: str) -> dict | None:
    k = key.strip().lower()
    for r in rows:
        if str(r.get("id", "")).lower() == k:
            return r
    for r in rows:
        names = [str(r.get("name", ""))] + [str(a) for a in (r.get("aliases") or [])]
        if any(n.lower() == k for n in names):
            return r
    return None


def is_unmeasured(v) -> bool:
    return v == "unmeasured" or (isinstance(v, dict) and v.get("status") == "unmeasured")


def is_owed(v) -> bool:
    return isinstance(v, dict) and v.get("status") == "OWED"


def get_field(row: dict, dotted: str):
    """A field is read from `handling:` only; a dotted path walks into it. The row's own top-level keys
    (delivery:, board: …) are older, different things and never answer a handling question."""
    cur = row.get("handling") or {}
    for p in dotted.split("."):
        if isinstance(cur, dict) and p in cur:
            cur = cur[p]
        else:
            return False, None
    return True, cur


def emit(value, as_json: bool) -> None:
    if as_json:
        print(json.dumps(value, ensure_ascii=False, indent=1, default=str))
    elif isinstance(value, (dict, list)):
        sys.stdout.write(yaml.safe_dump(value, sort_keys=False, allow_unicode=True, width=200))
    elif value is None:
        print("")
    else:
        print(value)


# ── one-word summaries, for --list and the page ─────────────────────────────────────────────────────────────────────
def short(row: dict, q: str) -> str:
    h = row.get("handling") or {}
    if q not in h:
        return "—"
    v = h[q]
    if is_unmeasured(v):
        return "unmeasured"
    if is_owed(v):
        return "OWED"
    if q == "visibility":
        return str(v.get("value", "?"))
    if q == "plans":
        s = str(v.get("where", "?"))
        if v.get("path"):
            s += f" `{v['path']}`"
        for a in v.get("also") or []:
            s += f" + {a.get('where')}" + (f" `{a['path']}`" if a.get("path") else "")
        return s
    if q == "board":
        e = str(v.get("engine", "?"))
        if e == "none":
            return "none"
        s = e + (f" `{v['place']}`" if v.get("place") else "")
        if v.get("write"):
            s += f" ({v['write']})"
        return s
    if q == "people":
        ms = v.get("members") or []
        return ", ".join(f"{m.get('id') or m.get('account')} ({m.get('role')})" for m in ms) or "none"
    if q == "private_to":
        return str(v) if v else "—"
    if q == "delivery":
        s = str(v.get("road", "?"))
        if v.get("merge_account"):
            s += f" as {v['merge_account']}"
        s += f" · CI {v.get('ci', '?')}"
        chk = v.get("required_checks")
        if isinstance(chk, list) and chk:
            s += " [" + ", ".join(chk) + "]"
        if v.get("extra_rules"):
            s += " · " + ", ".join(v["extra_rules"])
        if v.get("conflict"):
            s += " · ⚠ conflict"
        return s
    if q == "deploy":
        if v.get("how") in (None, "none", []) and v.get("where") in (None, "none"):
            return "none"
        how = v.get("how")
        how = ", ".join(how) if isinstance(how, list) else (how or "?")
        s = f"{v.get('where', '?')}: {how}"
        if v.get("needs_word") == "yes":
            s += " (his word)"
        return s
    if q == "secrets":
        ks = v.get("keys") or []
        return ", ".join(ks) if ks else "none named"
    if isinstance(v, dict) and "value" in v:
        return brief(q, v["value"])
    return str(v)


def _items(val: list) -> list[dict]:
    """List items as dicts: a bare string becomes {name/url/person/who: string}, so a schema-valid
    list of strings never crashes a cell."""
    out = []
    for e in val:
        if isinstance(e, dict):
            out.append(e)
        else:
            t = str(e)
            out.append({"name": t, "url": t, "area": t, "person": None, "github": "?", "who": t, "where": t})
    return out


def brief(q: str, val) -> str:
    """One cell for one of the fourteen."""
    if val in (None, [], {}, ""):
        return "none"
    if isinstance(val, list):
        val = _items(val)
    if q in ("environments",) and isinstance(val, list):
        return ", ".join(f"{e.get('name')}: {e.get('url')}" + (f" ({e['runs_on']})" if e.get("runs_on") else "") for e in val)
    if q == "domains" and isinstance(val, list):
        return ", ".join(f"{d.get('name')} (cert {d.get('cert_expires', '?')})" for d in val)
    if q == "keepers" and isinstance(val, list):
        held = [k for k in val if k.get("person") not in (None, "", "unclaimed")]
        return f"{len(held)} of {len(val)} areas kept" + (": " + ", ".join(f"{k['area']}→{k['person']}" for k in held[:4]) if held else "")
    if q == "access" and isinstance(val, list):
        return ", ".join(f"{a.get('person')} ({a.get('github')})" for a in val)
    if q == "toolchain" and isinstance(val, dict):
        bits = ["/".join(val.get("languages") or [])]
        if val.get("package_manager"):
            pm = val["package_manager"]
            bits.append(", ".join(pm) if isinstance(pm, list) else str(pm))
        return " · ".join(b for b in bits if b) or "none"
    if q == "scanning" and isinstance(val, dict):
        on = [k for k, x in val.items() if x not in (None, False, "no", [], "none")]
        return ", ".join(on) if on else "none"
    if q == "upstream" and isinstance(val, dict):
        return str(val.get("remote", "?"))
    if q == "monitoring" and isinstance(val, list):
        return ", ".join(m.get("url", "?") for m in val)
    if q == "backups" and isinstance(val, list):
        return ", ".join(str(b.get("where") or b.get("data")) for b in val)
    if q == "clients" and isinstance(val, list):
        return ", ".join(str(c.get("who")) for c in val)
    if isinstance(val, (dict, list)):
        return json.dumps(val, ensure_ascii=False)[:80]
    return str(val)


def cmd_list(rows: list[dict]) -> int:
    for r in rows:
        print(f"{r.get('id')}\t{short(r, 'visibility')}\t{short(r, 'plans')}\t{short(r, 'delivery')}")
    return 0


def schema_findings(rows: list[dict], schema_path: str) -> list[str]:
    if not os.path.isfile(schema_path):
        return [f"no schema at {schema_path} — the rows cannot be judged"]
    try:
        import jsonschema  # type: ignore
    except ImportError:
        return [f"python3 has no jsonschema — the rows were not judged against {schema_path}"]
    with open(schema_path, encoding="utf-8") as fh:
        schema = json.load(fh)
    hs = dict(schema["$defs"]["handling"])
    hs["$defs"] = schema["$defs"]
    out = []
    v = jsonschema.Draft202012Validator(hs)
    for r in rows:
        h = r.get("handling")
        if h is None:
            continue
        for e in sorted(v.iter_errors(h), key=lambda e: list(e.path)):
            where = ".".join(str(p) for p in e.path) or "handling"
            msg = e.message if len(e.message) < 160 else e.message[:157] + "…"
            out.append(f"{r.get('id')}: handling.{where}: {msg}")
    return out


def cmd_audit(rows: list[dict], schema_path: str, registry: str, quiet: bool) -> int:
    missing = []
    for r in rows:
        h = r.get("handling") or {}
        lack = [f for f in AUDIT_REQUIRED if f not in h]
        if lack:
            missing.append(f"{r.get('id')}: no {', '.join(lack)}")
    bad = schema_findings(rows, schema_path)
    unmeasured = sum(1 for r in rows for q in QUESTIONS + FOURTEEN if is_unmeasured((r.get("handling") or {}).get(q)))
    owed = sum(1 for r in rows if is_owed((r.get("handling") or {}).get("private_to")))
    owed_all = sum(1 for r in rows for q in QUESTIONS + FOURTEEN if is_owed((r.get("handling") or {}).get(q)))
    conflicts = [r.get("id") for r in rows if isinstance((r.get("handling") or {}).get("delivery"), dict)
                 and r["handling"]["delivery"].get("conflict")]
    findings = missing + bad
    if quiet:
        print(f"projects: {len(rows)} rows · {len(missing)} without visibility/plans/delivery · "
              f"{len(bad)} schema findings · {unmeasured} unmeasured values · {owed_all} values OWED by the operator")
        return 1 if findings else 0
    print(f"registry: {registry}")
    print(f"rows: {len(rows)}")
    print(f"rows without {' / '.join(AUDIT_REQUIRED)}: {len(missing)}")
    for m in missing:
        print(f"  - {m}")
    print(f"schema findings: {len(bad)}")
    for b in bad:
        print(f"  - {b}")
    print(f"values marked unmeasured: {unmeasured}")
    print(f"private_to OWED by the operator: {owed}")
    print(f"values OWED by the operator (all fields): {owed_all}")
    if conflicts:
        print(f"delivery conflicts (a repo rule and the house rule disagree): {len(conflicts)} — {', '.join(conflicts)}")
    return 1 if findings else 0


def md(s: str) -> str:
    return str(s).replace("|", "\\|").replace("\n", " ")


def cmd_page(rows: list[dict], registry: str) -> int:
    cols = [("Project", None), ("Public?", "visibility"), ("Plans live", "plans"), ("Board", "board"),
            ("People", "people"), ("Private to", "private_to"), ("Who merges · gates", "delivery"),
            ("Deploy", "deploy"), ("Vault keys (names)", "secrets")]
    out = []
    out.append("# How every project is handled")
    out.append("")
    out.append("> [!NOTE]")
    out.append("> Generated by `bin/records/project.sh --page` from the `handling:` block of each row of "
               "`hodd/identity/projects.yaml`. Do not edit this page; edit the registry and run the command again. "
               "Every value in the registry carries its source; `unmeasured` means nobody could read it, and "
               "`OWED` means only the operator can answer it.")
    out.append("")
    pub = sum(1 for r in rows if short(r, "visibility") == "public")
    priv = sum(1 for r in rows if short(r, "visibility") == "private")
    nor = sum(1 for r in rows if short(r, "visibility") == "no-remote")
    owed = sum(1 for r in rows if short(r, "private_to") == "OWED")
    out.append(f"**{len(rows)} projects** — {pub} public, {priv} private, {nor} with no remote. "
               f"`private_to` is OWED on {owed}.")
    out.append("")
    conflicts = [r for r in rows if isinstance((r.get("handling") or {}).get("delivery"), dict)
                 and r["handling"]["delivery"].get("conflict")]
    if conflicts:
        out.append("> [!IMPORTANT]")
        out.append("> Where a repository's own rule and the house rule disagree about who merges "
                   "(the ⚠ in the table):")
        for r in conflicts:
            out.append(f"> - **{md(r.get('name') or r.get('id'))}** — {md(r['handling']['delivery']['conflict'])}")
        out.append("")
    out.append("| " + " | ".join(c for c, _ in cols) + " |")
    out.append("|" + "---|" * len(cols))
    for r in rows:
        cells = [f"**{md(r.get('name') or r.get('id'))}** `{md(r.get('id'))}`"]
        cells += [md(short(r, q)) for _, q in cols[1:]]
        out.append("| " + " | ".join(cells) + " |")
    out.append("")
    out.append("## The fourteen (plan 346)")
    out.append("")
    groups = [("environments", "domains", "monitoring"), ("licence", "upstream", "toolchain", "scanning"),
              ("access", "keepers", "merge_account", "backups", "clients", "costs"),
              ("data_class", "models_allowed", "lifecycle")]
    titles = ["Where it runs", "What it is built from", "Who and what keeps it", "His word"]
    for title, g in zip(titles, groups):
        out.append(f"### {title}")
        out.append("")
        out.append("| Project | " + " | ".join(g) + " |")
        out.append("|" + "---|" * (len(g) + 1))
        for r in rows:
            out.append(f"| `{md(r.get('id'))}` | " + " | ".join(md(short(r, q)) for q in g) + " |")
        out.append("")
    print("\n".join(out))
    return 0


def main(argv: list[str]) -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(os.path.join(here, "..", ".."))
    registry = os.environ.get("YMIR_PROJECTS_REGISTRY") or os.path.join(
        os.environ.get("YMIR_HOME", ""), "hodd", "identity", "projects.yaml")
    schema = os.path.join(root, "config", "projects.schema.json")
    mode, pid, field, as_json, quiet = "show", None, None, False, False
    a = list(argv)
    while a:
        x = a.pop(0)
        if x in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        if x == "--registry":
            if not a:
                die("--registry needs a path")
            registry = a.pop(0)
        elif x == "--schema":
            if not a:
                die("--schema needs a path")
            schema = a.pop(0)
        elif x == "--field":
            if not a:
                die("--field needs a name")
            field = a.pop(0)
        elif x == "--json":
            as_json = True
        elif x == "--quiet":
            quiet = True
        elif x in ("--audit", "--list", "--page"):
            mode = x[2:]
        elif x.startswith("-"):
            die(f"unknown argument {x}")
        elif pid is None:
            pid = x
        else:
            die(f"one project at a time (got {pid} and {x})")
    rows = load(registry)
    if mode == "audit":
        return cmd_audit(rows, schema, registry, quiet)
    if mode == "list":
        return cmd_list(rows)
    if mode == "page":
        return cmd_page(rows, registry)
    if not pid:
        die("name a project (project.sh <id>), or --audit, --list, --page")
    row = find(rows, pid)
    if row is None:
        die(f"no project {pid!r} in {registry} (project.sh --list names them)")
    if field:
        ok, val = get_field(row, field)
        if not ok:
            print(f"project.sh: {row['id']}: no field {field!r} (handling: does not carry it)", file=sys.stderr)
            return 1
        emit(val, as_json)
        return 0
    emit({"id": row.get("id"), "name": row.get("name"), "handling": row.get("handling") or "none yet"}, as_json)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
