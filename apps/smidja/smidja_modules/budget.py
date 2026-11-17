"""The machine's memory line, and what a team may cost against it.

A factory that raises more agents than the machine can carry does not fail
loudly — it swaps, then the OOM killer picks a victim, and the victim is whatever
the operator was using. The heart died at 07:20 with seven errands and thirty-six
containers on it (plan 003), and plan 315 §6.3 says the fix belongs here: **a team
whose members exceed the machine's budget is refused before a pane is raised.**

The arithmetic is the estate's own, in plan 003's shape:

    available for agents = RAM − Σ(budget.memory_ceiling_mb of every service)
                               − the desk's reserve
    seats the machine can carry = available ÷ the floor one seated agent holds

`Σ memory_ceiling_mb` is read from the operator's registry
(`hodd/identity/services.yaml`) — the same numbers plan 003 writes, never a table
kept here. Every term is printed with the verdict, because a refusal that does not
show its arithmetic is indistinguishable from a bug.
"""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Optional

SEAT_FLOOR_MB = int(os.environ.get("SMIDJA_SEAT_FLOOR_MB", "400"))
DESK_RESERVE_MB = int(os.environ.get("SMIDJA_DESK_RESERVE_MB", "2048"))
LOCAL_RESIDENT_MB = int(os.environ.get("SMIDJA_LOCAL_MODEL_MB", "8192"))

# A model served by one of these holds RAM/VRAM on this machine. One resident at
# a time is the rail's law, so N local agents cost ONE residency, not N.
_LOCAL_PROVIDERS = ("llama", "llamacpp", "lmstudio", "ollama", "llama-swap",
                    "llama.cpp", "local")


def _mb(value: str) -> int:
    """`96Mi` · `1.5G` · `512M` · `1024` → megabytes."""
    text = str(value).strip()
    match = re.match(r"^([\d.]+)\s*([KMG]i?B?|B)?$", text, re.I)
    if not match:
        return 0
    amount = float(match.group(1))
    unit = (match.group(2) or "M").upper()
    scale = {"B": 1 / 1024 / 1024, "K": 1 / 1024, "M": 1,
             "G": 1024}.get(unit[0], 1)
    return int(amount * scale)


def machine_ram_mb() -> int:
    """This machine's physical memory. A clean 0 when it cannot be read."""
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemTotal:"):
                return int(line.split()[1]) // 1024
    except OSError:
        pass
    try:                                          # macOS
        import subprocess
        out = subprocess.run(["sysctl", "-n", "hw.memsize"], capture_output=True,
                             text=True, timeout=10, check=False)
        if out.returncode == 0 and out.stdout.strip().isdigit():
            return int(out.stdout.strip()) // 1024 // 1024
    except (OSError, ValueError):
        pass
    return 0


def _services_yaml() -> Optional[Path]:
    """The operator's service registry, wherever this machine keeps its home."""
    for key in ("YMIR_HOME", "YMIR_HOARD"):
        root = os.environ.get(key)
        if not root:
            continue
        base = Path(root)
        for candidate in (base / "hodd" / "identity" / "services.yaml",
                          base / "identity" / "services.yaml"):
            if candidate.is_file():
                return candidate
    return None


def estate_mb() -> tuple[int, int, str]:
    """The estate's declared ceiling: (total_mb, services_counted, source)."""
    path = _services_yaml()
    if path is None:
        return 0, 0, "no registry on this machine (hodd/identity/services.yaml absent)"
    try:
        import yaml
        data = yaml.safe_load(path.read_text()) or {}
    except Exception:                             # noqa: BLE001 — an unreadable registry is not a crash
        return 0, 0, f"{path} could not be read"
    services = data.get("services") if isinstance(data, dict) else data
    total, counted = 0, 0
    for row in services or []:
        if not isinstance(row, dict):
            continue
        budget = row.get("budget") or {}
        if isinstance(budget, dict):
            if isinstance(budget.get("memory_ceiling_mb"), (int, float)):
                total += int(budget["memory_ceiling_mb"])
                counted += 1
                continue
            for key in ("memory", "MemoryMax", "memory_max"):
                if budget.get(key):
                    total += _mb(budget[key])
                    counted += 1
                    break
    return total, counted, str(path)


def _is_local(model: str) -> bool:
    provider = str(model or "").split("/", 1)[0].lower()
    return any(provider.startswith(name) for name in _LOCAL_PROVIDERS)


def seat_cost_mb(cfg) -> dict:
    """What this roster costs when every member is seated at once."""
    agents = list(cfg.agents)
    local = any(_is_local(agent.model) for agent in agents)
    floor = len(agents) * SEAT_FLOOR_MB
    resident = LOCAL_RESIDENT_MB if local else 0
    return {
        "members": len(agents),
        "names": [agent.name for agent in agents],
        "seat_floor_mb": SEAT_FLOOR_MB,
        "floors_mb": floor,
        "local_resident_mb": resident,
        "local": local,
        "needed_mb": floor + resident,
    }


def check(cfg) -> dict:
    """The whole arithmetic, and the verdict. Never raises; the caller decides."""
    cost = seat_cost_mb(cfg)
    ram = machine_ram_mb()
    estate, counted, source = estate_mb()
    available = ram - estate - DESK_RESERVE_MB if ram else 0
    seats_fit = max(0, available // SEAT_FLOOR_MB) if available > 0 else 0
    over = bool(ram) and (cost["needed_mb"] > available or cost["members"] > seats_fit)
    return {
        "ok": not over,
        "ram_mb": ram,
        "estate_mb": estate,
        "estate_services": counted,
        "estate_source": source,
        "desk_reserve_mb": DESK_RESERVE_MB,
        "available_mb": max(0, available),
        "seats_fit": seats_fit,
        **cost,
    }


def refusal(verdict: dict) -> str:
    """The one sentence a refused roster gets — with the number it needed."""
    return (
        f"this team needs {verdict['members']} seats: {verdict['floors_mb']} MB of "
        f"harness floor ({verdict['members']} × {verdict['seat_floor_mb']} MB)"
        + (f" + {verdict['local_resident_mb']} MB for one resident local model"
           if verdict["local_resident_mb"] else "")
        + f" = {verdict['needed_mb']} MB, and this machine leaves "
          f"{verdict['available_mb']} MB for agents "
          f"({verdict['ram_mb']} MB RAM − {verdict['estate_mb']} MB declared by "
          f"{verdict['estate_services']} service(s) − {verdict['desk_reserve_mb']} MB "
          f"for the desk) — at most {verdict['seats_fit']} seat(s). "
          f"Remove members, or raise the machine's line."
    )
