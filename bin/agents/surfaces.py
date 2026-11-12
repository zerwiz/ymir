#!/usr/bin/env python3
"""surfaces.py — read config/surfaces.yaml, the ONE register of Eir's surfaces (plan 278).

    surfaces.py [REGISTER]      one row per surface, tab-separated: name, risk, roles, why

Eir (bin/agents/eir-doctor.sh) and Gróa (bin/agents/groa-update.sh) read the same rows, so the list Eir
checks and the list Gróa may mend can never disagree. A register that does not parse prints nothing and
exits 1: the caller falls back to its own list with every mend treated as `ask`, never as `safe`.

The register is code: it is read only from the repository (or a path the caller names), never from a scan
result, a journal or a unit description (RULES/39).
"""
from __future__ import annotations

import sys
from pathlib import Path

RISKS = ("safe", "ask", "never")


def main(argv: list[str]) -> int:
    path = Path(argv[1]) if len(argv) > 1 else Path(__file__).resolve().parents[2] / "config" / "surfaces.yaml"
    try:
        import yaml
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except Exception:  # no parser, no file, or a file that does not parse: the caller falls back
        return 1
    rows = data.get("surfaces")
    if not isinstance(rows, list):
        return 1
    seen: set[str] = set()
    out: list[str] = []
    for r in rows:
        if not isinstance(r, dict):
            return 1
        name = str(r.get("name", "")).strip()
        risk = str(r.get("risk", "")).strip()
        if not name.isidentifier() or name in seen or risk not in RISKS:
            return 1  # a malformed row would make the whole list untrustworthy
        seen.add(name)
        roles = r.get("roles", "all")
        roles = ",".join(str(x) for x in roles) if isinstance(roles, list) else str(roles)
        why = " ".join(str(r.get("why", "")).split()).replace("\t", " ")
        out.append(f"{name}\t{risk}\t{roles}\t{why}")
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
