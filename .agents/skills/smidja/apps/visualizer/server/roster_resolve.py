#!/usr/bin/env python3
"""Resolve the target repo's roster.yaml into the JSON the chat picker needs.

Emits a single JSON object on stdout:

    { "rosters": [RosterInfo...], "models": [ModelInfo...] }

Mirrors scripts/resolve-config.py's exact model resolution for each stack
(overrides > tier map > defaults) so the UI picker reflects what a real
`factory run` would use, but leaves the yaml on disk untouched — this is
read-only, for the picker only.

Usage:
    python3 server/roster_resolve.py <repoRoot> [roster.yaml-path]
"""
import json
import os
import re
import sys
from pathlib import Path

ROLE_COLORS = {
    "orchestrator": "#c084fc", "planner": "#a78bfa", "builder": "#22d3ee",
    "scout": "#fbbf24", "reviewer": "#fb7185", "documenter": "#e879f9",
}


def _expand(value: str) -> str:
    """Expand ${VAR:-default} in a model id using the current environment."""
    if not isinstance(value, str):
        return value
    pattern = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-([^}]*))?\}")
    return pattern.sub(lambda m: os.environ.get(m.group(1), m.group(2) or ""), value)


def _tiers(r: dict) -> dict:
    return r.get("tiers") or r.get("model_presets") or {}


def _surface(provider: str) -> str:
    if provider in ("lmstudio", "ollama", "local"):
        return "local"
    return "cloud"


def _size_b(model: str) -> int | None:
    """Best-effort parameter size from the model id, e.g. '35b-a3b' -> 35."""
    m = re.search(r"(\d+(?:\.\d+)?)b", model.lower())
    if not m:
        return None
    try:
        return int(float(m.group(1)))
    except ValueError:
        return None


def _provider(model: str) -> str:
    parts = model.split("/")
    return parts[0] if len(parts) > 1 else "local"


def _weak(model: str) -> bool:
    size = _size_b(model)
    if size is not None:
        return size < 9
    # Explicit small-model hints when size parsing fails.
    return bool(re.search(r"(?:^|[^0-9])(4b|7b|8b|0\.6b|0\.5b)(?:[^0-9]|$)", model.lower()))


def resolve_rosters_and_models(repo_root: Path, roster_path: Path | None = None) -> dict:
    r = roster_path or repo_root / "factory" / "factory_config" / "roster.yaml"
    data = {}
    if r and r.exists():
        import yaml
        try:
            data = yaml.safe_load(r.read_text()) or {}
        except Exception:
            data = {}

    defaults = data.get("role_defaults") or {}
    tier_map_by_name = {k: v or {} for k, v in _tiers(data).items()}
    stacks = data.get("stacks") or {}
    role_default_names = list((data.get("model_roles") or {}).keys()) or ["defaults"]

    rosters = []
    models_by_id: dict[str, dict] = {}

    def note_model(model: str) -> None:
        model = _expand(model)
        if not model or model in models_by_id:
            return
        provider = _provider(model)
        models_by_id[model] = {
            "id": model,
            "name": model.split("/")[-1],
            "provider": provider,
            "kind": "local" if _surface(provider) == "local" else "online",
            "size_b": _size_b(model),
            "weak": _weak(model),
        }

    for name, stack in stacks.items():
        tier = stack.get("tier")
        tier_map = tier_map_by_name.get(tier or "", {})
        overrides = stack.get("overrides") or {}
        agents = stack.get("agents") or []

        resolved = []
        for aname in agents:
            ov = overrides.get(aname) or {}
            role_default = defaults.get(aname) or {}
            model = ov.get("model") or tier_map.get(aname) or tier_map.get("defaults", "")
            # Fall back to role_defaults model if one is pinned there.
            if not model and role_default.get("model"):
                model = role_default["model"]
            model = _expand(model)
            if model:
                note_model(model)
            resolved.append({"role": aname, "model": model})

        orchestrator_model = ""
        orch_entry = next((a for a in resolved if a["role"] == "orchestrator"), None)
        if orch_entry and orch_entry["model"]:
            orchestrator_model = orch_entry["model"]
        else:
            orchestrator_model = _expand(
                overrides.get("orchestrator", {}).get("model")
                or tier_map.get("orchestrator")
                or role_defaults_model(data, "orchestrator")
                or ""
            )
            if orchestrator_model:
                note_model(orchestrator_model)

        # Surface: any agent on local provider -> local; mixed -> hybrid.
        surfaces = {_surface(_provider(a["model"])) for a in resolved if a["model"]}
        surface = "hybrid" if len(surfaces) > 1 else (next(iter(surfaces), "local"))

        label = f"{name} — {len(agents)} agents"
        if tier:
            label += f" · {tier}"
        elif not agents:
            label = name

        rosters.append({
            "name": name,
            "label": label,
            "surface": surface,
            "tier": tier or "",
            "agent_count": len(agents),
            "orchestrator_model": orchestrator_model,
            "weak_orchestrator": bool(orchestrator_model and _weak(orchestrator_model)),
            "agents": resolved,
            "summary": (resolved and ", ".join(a["role"] for a in resolved)) or None,
        })

    return {"rosters": rosters, "models": list(models_by_id.values())}


def role_defaults_model(data: dict, role: str) -> str:
    rd = (data.get("role_defaults") or {}).get(role) or {}
    return rd.get("model", "")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: roster_resolve.py <repoRoot> [roster.yaml]")
    repo = Path(sys.argv[1]).resolve()
    rp = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else None
    print(json.dumps(resolve_rosters_and_models(repo, rp), indent=0))
