"""fleet — where the fleet's machines ARE, read as data (plan 51 · plan 58).

`fleet/` is the engine's reading of the private fleet registry
(`$YMIR_HOME/hodd/data/fleet.json` — read at runtime, never shipped): one row per
machine, read by hostname. `rail.py` is the ONE resolver of the living-rail
question (plan 51 Parts 9a/9b/9c): whichever strong box is CONNECTED serves the
fleet, and a dropped box reroutes, never an outage. Every surface that states a
rail URL calls this resolver; none restates one.

```
fleet[1]{module,owns}:
  "rail.py","the strong boxes · liveness (health, then /v1/models) · the ranked live set · the first-alive serving URL · the shared key as a REFERENCE"
```

The layer is reached by `bin/model/rail-resolve.sh` (the door) and its own module CLI
`python3 -m ymir_runtime.fleet`. It decides; it launches nothing.
"""

from __future__ import annotations

from .rail import (
    DEFAULT_PORT,
    DEFAULT_TIMEOUT,
    KEY_REF,
    Probe,
    Rail,
    RailUnavailable,
    Resolution,
    Serving,
    Target,
    candidates,
    default_host,
    probe_http,
    read_key,
    read_registry,
    registry_path,
    resolve,
    serving_url,
    status,
    strong_boxes,
)

__all__ = [
    "DEFAULT_PORT",
    "DEFAULT_TIMEOUT",
    "KEY_REF",
    "Probe",
    "Rail",
    "RailUnavailable",
    "Resolution",
    "Serving",
    "Target",
    "candidates",
    "default_host",
    "probe_http",
    "read_key",
    "read_registry",
    "registry_path",
    "resolve",
    "serving_url",
    "status",
    "strong_boxes",
]
