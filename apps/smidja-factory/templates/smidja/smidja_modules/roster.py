"""The roster — teams as ONE file: `stacks:` · `role_defaults:` · `tiers:`.

The books are explicit: a team is a `stacks:` block in the project's
`smidja/smidja_smidja_config/roster.yaml`, and a `factory.yaml`, a `team.yaml` or
a wrapper that restates it is a SECOND COPY OF THE TRUTH (create_config.md, "One
shape, not two"). So this module does not invent a shape and does not write a
file: it RESOLVES a stack into the same `smidjaConfig` every chain already runs,
in memory, and hands it to the loader.

That is the whole point of the seam: `agents.load_config()` sees a file with
`stacks:` and asks this module for the selected stack's config, so a team is a
choice at launch (`SMIDJA_STACK=plan-build-review`) and never a second file on
disk.

Model precedence MIRRORS `apps/visualizer/server/roster_resolve.py` exactly —
overrides > tier > role_defaults — because a picker that resolves one model and
a run that resolves another is the fault the smithy has already paid for once.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import yaml


def is_roster(data: Any) -> bool:
    """A roster is a mapping with `stacks:`; a config is a mapping with `agents:`."""
    return isinstance(data, dict) and isinstance(data.get("stacks"), dict)


def load(path: str | Path) -> dict:
    data = yaml.safe_load(Path(path).read_text()) or {}
    return data if isinstance(data, dict) else {}


def stack_names(roster: dict) -> list[str]:
    return sorted((roster.get("stacks") or {}).keys())


def select_stack(roster: dict, name: str = "") -> str:
    """Which stack this launch is for: the argument, then the env, then a lone one.

    A roster with several stacks and no choice is a REFUSAL, not a default: a run
    that picks a team for you is a run that spends your tokens on the wrong one.
    """
    chosen = (name or os.environ.get("SMIDJA_STACK") or os.environ.get("SMIDJA_ROSTER") or "").strip()
    available = stack_names(roster)
    if chosen:
        if chosen not in available:
            raise SystemExit(
                f"no stack {chosen!r} in this roster — it holds: {', '.join(available) or '(none)'}")
        return chosen
    if len(available) == 1:
        return available[0]
    raise SystemExit(
        "this roster holds several stacks and none was chosen — name one with "
        f"--stack <name> or SMIDJA_STACK=<name>: {', '.join(available) or '(none)'}")


def _tier_model(roster: dict, tier: str, role: str) -> str:
    """`tiers.<tier>.<role>`, then `tiers.<tier>.defaults` — the picker's order."""
    tiers = roster.get("tiers") or roster.get("model_presets") or {}
    tier_map = tiers.get(tier or "") or {}
    return str(tier_map.get(role) or tier_map.get("defaults") or "")


def resolve(roster: dict, stack_name: str = "") -> dict:
    """One stack, expanded into the config shape every chain already reads.

    The result is a plain dict with `defaults`, `observability` and `agents` —
    exactly what `smidjaConfig` parses — so a roster run and a config run are the
    same run, and nothing downstream needs to know which file it came from.
    """
    name = select_stack(roster, stack_name)
    stack = (roster.get("stacks") or {}).get(name) or {}
    roles = roster.get("role_defaults") or {}
    defaults = dict(roster.get("defaults") or {})
    overrides = stack.get("overrides") or {}
    tier = str(stack.get("tier") or "")

    agents: list[dict] = []
    for role in stack.get("agents") or []:
        role_default = dict(roles.get(role) or {})
        override = dict(overrides.get(role) or {})
        model = (str(override.get("model") or "")
                 or _tier_model(roster, tier, role)
                 or str(role_default.get("model") or "")
                 or str(defaults.get("model") or ""))
        entry: dict[str, Any] = {
            "name": role,
            "model": model,
            # The surface is a per-(team × agent) assignment, like the model:
            # one team watches its builder work, another runs it headless.
            "coding_agent": str(override.get("coding_agent")
                                or stack.get("coding_agent")
                                or defaults.get("coding_agent")
                                or "pi"),
        }
        for key in ("thinking", "color", "purpose", "tools", "writes",
                    "harness_engineering", "prompt_engineering"):
            if key in role_default:
                entry[key] = role_default[key]
            if key in override:
                entry[key] = override[key]
        if not entry.get("prompt_engineering"):
            # A stamped repo keeps its prompts beside its data; a project that
            # keeps them elsewhere says so in role_defaults.
            base = defaults.get("prompt_dir") or "smidja/smidja_data/prompt_engineering"
            entry["prompt_engineering"] = {
                "system": f"{base}/{role}/system.md",
                "user": f"{base}/{role}/user.md",
            }
        agents.append(entry)

    if not agents:
        raise SystemExit(f"stack {name!r} names no agents — a team with no members is not a team")

    config: dict[str, Any] = {
        "defaults": defaults,
        "observability": dict(roster.get("observability") or {}),
        "agents": agents,
        # Kept for the reader (the trace and the board can say WHICH team ran).
        "stack": {
            "name": name,
            "tier": tier,
            "inject": list(stack.get("inject") or []),
            "kaia_tier": stack.get("kaia_tier") or "",
            "roster": str(roster.get("__path__") or ""),
        },
    }
    return config


def describe(roster: dict) -> list[dict]:
    """Every stack, resolved: what a picker or `--list` prints."""
    out = []
    for name in stack_names(roster):
        try:
            config = resolve(roster, name)
        except SystemExit as error:
            out.append({"name": name, "error": str(error), "agents": []})
            continue
        out.append({
            "name": name,
            "tier": config["stack"]["tier"],
            "error": "",
            "agents": [{"role": a["name"], "model": a["model"],
                        "coding_agent": a["coding_agent"]} for a in config["agents"]],
        })
    return out
