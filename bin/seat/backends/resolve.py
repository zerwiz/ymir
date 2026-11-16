"""ONE resolver: `herdr:<pane>`, `hermes:<id-or-title>`, or a bare target — and bare is herdr.

WHY (plan 303 §14): five doors reach an agent today, and each learned its own way. A second
backend must not mean a second way, so every caller writes one address and this file decides
which backend answers it. A bare target stays herdr, so nothing that works today changes shape.

    resolve("w6R:p1")            -> herdr, "w6R:p1"
    resolve("herdr:w6R:p1")      -> herdr, "w6R:p1"
    resolve("hermes:fd2ee4d0")   -> hermes, "local-fd2ee4d0…"  (resolved to a real id)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import herdr as herdr_mod   # noqa: E402
import hermes as hermes_mod  # noqa: E402


def backends():
    return {"herdr": herdr_mod.Herdr(), "hermes": hermes_mod.Hermes()}


def resolve(target):
    """(backend name, canonical target). A name the backend cannot resolve stays as written and
    its `get` will say `dead` — the door never invents an address."""
    t = (target or "").strip()
    if t.startswith("hermes:"):
        want = t[7:]
        real = hermes_mod.Hermes().find(want)
        return "hermes", ("hermes:%s" % real["id"]) if real else t
    if t.startswith("herdr:"):
        return "herdr", t[6:]
    return "herdr", t


def backend_for(target):
    name, canon = resolve(target)
    return backends()[name], canon


def all_rows():
    """Every agent and session on this machine, in one vocabulary, from both backends."""
    rows = []
    for name, b in backends().items():
        try:
            rows.extend(b.list())
        except Exception as exc:  # noqa: BLE001
            rows.append({"name": "?", "harness": name, "target": "%s:?" % name, "pane": "",
                         "state": 3, "reason": "backend unreadable (%s)" % str(exc)[:60]})
    return rows
