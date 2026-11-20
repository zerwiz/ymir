"""fleet/rail.py — the LIVING rail resolver (plan 51, Parts 9a/9b/9c).

The Allfather's doctrine: *models come from whichever strong box is CONNECTED at
the moment* — heimdall · whynot · omarchy. The model lane is a live federation,
not a single point: a box that drops out of the tailnet drops out of the lane,
and resolution reroutes. A dead rail is a lane reroute, never an outage.

This module is the ONE owner of that question. It reads the private fleet
registry (`$YMIR_HOME/hodd/data/fleet.json`, never shipped), probes each strong
box for LIVENESS — the cheap keyless `/health`, then an OpenAI-compatible
`/v1/models` — and ranks first-alive. Every surface that states a rail URL calls
this resolver; none restates one.

```
rail_resolution[5]{piece,owns}:
  "strong boxes","the registry's ordered list — `rails` (explicit), else `ear` (the strong boxes Part 9c names for the ear and the models alike), else the hosts whose roles include `forge`. A box the registry does not list is never invented"
  "address","loopback on the box itself, else its tailnet name, else its LAN address — the registry's own rows, never a guess"
  "liveness","`GET /health` (keyless, cheap); when that route is absent or gated, `GET /v1/models` with the shared key; a refused key still reads ALIVE (the rail answers), only the served set is unknown"
  "the answer","the first live box in rank order; with an alias, the first live box that SERVES it (a key-refused box is accepted, the alias unverified)"
  "the key","a REFERENCE — the env var `LLAMA_SWAP_API_KEY` and where its value came from; the value is read only to ask a rail what it serves, and is never emitted"
```

The unit is dependency-injected: `status()`/`resolve()` take `probe=` so a test
can stand a synthetic registry and a scripted liveness in place of a network,
exactly as `dispatch/` takes a scripted registry door. `probe_http` is the real
one. Nothing here launches an agent or writes a value.
"""

from __future__ import annotations

import concurrent.futures
import json
import os
import socket
import subprocess
import urllib.error
import urllib.request
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, replace
from pathlib import Path

from ..paths import DEFAULT_HOME
from typing import Callable

KEY_REF = "LLAMA_SWAP_API_KEY"
DEFAULT_PORT = 8080
DEFAULT_TIMEOUT = 2.0
LOOPBACK = "127.0.0.1"

HEALTH_PATH = "/health"


class RailUnavailable(Exception):
    """No registered rail is alive (or serves the alias) — a declined answer."""


@dataclass(frozen=True)
class Target:
    """A strong box the registry names, with its resolved address (no probe yet)."""

    host: str
    address: str
    port: int
    order: int
    roles: tuple[str, ...] = ()

    @property
    def base(self) -> str:
        return f"http://{self.address}:{self.port}"

    @property
    def url(self) -> str:
        return f"{self.base}/v1"


@dataclass(frozen=True)
class Probe:
    """What a liveness probe learned about one rail."""

    live: bool
    reason: str
    models: tuple[str, ...] = ()
    key_gated: bool = False


@dataclass(frozen=True)
class Rail:
    """One strong box, judged."""

    host: str
    address: str
    base: str
    url: str
    order: int
    live: bool
    reason: str
    models: tuple[str, ...] = ()
    key_gated: bool = False
    roles: tuple[str, ...] = ()


@dataclass(frozen=True)
class Serving:
    """The rail that serves the fleet right now."""

    host: str
    url: str
    key_ref: str = KEY_REF
    alias: str = ""
    alias_verified: bool = False
    models: tuple[str, ...] = ()


@dataclass(frozen=True)
class Resolution:
    """The ranked live set and the serving rail (or a declined answer)."""

    serving: Serving | None
    rails: tuple[Rail, ...]
    reason: str
    key_source: str = "unknown"

    @property
    def live(self) -> tuple[Rail, ...]:
        return tuple(rail for rail in self.rails if rail.live)

    @property
    def declined(self) -> bool:
        return self.serving is None


ProbeFn = Callable[[Target], Probe]


# ── the registry (private; read at runtime, never shipped) ───────────────────

def registry_path(root: str | Path | None = None) -> Path:
    """The fleet registry: `YMIR_FLEET_REGISTRY` → `$YMIR_HOME/hodd/data/fleet.json`."""
    env = os.environ.get("YMIR_FLEET_REGISTRY")
    if env:
        return Path(env)
    home = os.environ.get("YMIR_HOME")
    if not home and root:
        home = str(root)
    if not home:
        home = os.path.expanduser(os.environ.get("YMIR_HOME_DEFAULT", DEFAULT_HOME))
    return Path(home) / "hodd" / "data" / "fleet.json"


def read_registry(path: str | Path | None = None) -> dict:
    """The registry as a dict; a missing or malformed file reads as empty."""
    try:
        doc = json.loads(Path(path or registry_path()).read_text(encoding="utf-8"))
    except Exception:
        return {}
    return doc if isinstance(doc, dict) else {}


def _norm(host: str) -> str:
    return str(host or "").strip().lower().split(".")[0]


def strong_boxes(doc: Mapping) -> list[str]:
    """The ordered strong boxes the registry names, never invented.

    `rails` first (the explicit models list), else `ear` (Part 9c names one
    strong-box set for the ear and the models alike), else every host whose role
    includes `forge` (the pre-9c shape). Only hosts the registry declares count.
    """
    hosts = doc.get("hosts") or {}
    if not isinstance(hosts, Mapping):
        return []
    for key in ("rails", "ear"):
        listed = doc.get(key)
        if not isinstance(listed, Sequence) or isinstance(listed, (str, bytes)):
            continue
        ordered: list[str] = []
        for name in listed:
            name = str(name)
            if name in hosts and name not in ordered:
                ordered.append(name)
        if ordered:
            return ordered
    return sorted(
        host for host, spec in hosts.items() if "forge" in ((spec or {}).get("roles") or [])
    )


def _address_for(name: str, spec: Mapping, self_norm: str) -> str:
    if _norm(name) == self_norm:
        return LOOPBACK
    for key in ("tailnet", "lan"):
        value = spec.get(key)
        if value:
            return str(value)
    return str(name)  # a declared host with no address row: its own name is the address


def candidates(doc: Mapping, self_host: str, port: int = DEFAULT_PORT) -> list[Target]:
    """The registry's strong boxes, as ordered targets with resolved addresses."""
    hosts = doc.get("hosts") or {}
    self_norm = _norm(self_host)
    targets: list[Target] = []
    for order, name in enumerate(strong_boxes(doc)):
        spec = hosts.get(name) or {}
        address = _address_for(name, spec, self_norm)
        if not address:
            continue
        targets.append(
            Target(
                host=name,
                address=address,
                port=int(port),
                order=order,
                roles=tuple(str(role) for role in (spec.get("roles") or [])),
            )
        )
    return targets


def default_host() -> str:
    """This box's fleet name: `YMIR_HOST`, else the short hostname."""
    return _norm(os.environ.get("YMIR_HOST") or socket.gethostname())


# ── the key — a REFERENCE, resolved (value never emitted) ────────────────────

def _engine_root() -> Path | None:
    for var in ("YMIR_ENGINE_ROOT", "BROKK_ROOT_OVERRIDE", "BROKK_HOME"):
        value = os.environ.get(var)
        if value and (Path(value) / "bin" / "hodd.sh").is_file():
            return Path(value)
    return None


def _key_from_auth(path: Path) -> str:
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return ""
    if not isinstance(doc, dict):
        return ""
    for provider in ("llama-swap", "llamacpp-heimdall", "llamacpp-whynot"):
        entry = doc.get(provider)
        if isinstance(entry, dict):
            value = entry.get("key") or entry.get("apiKey")
            if value:
                return str(value)
        elif isinstance(entry, str) and entry:
            return entry
    return ""


def read_key(env: Mapping | None = None) -> tuple[str, str]:
    """The shared rail key and the reference that gave it: env → the hoard vault → pi.

    The value is only ever handed to a probe. The door prints the REFERENCE, never
    the value — a secret is referenced by path, never inlined.
    """
    environ = env if env is not None else os.environ
    value = environ.get(KEY_REF) or environ.get("YMIR_LLAMA_API_KEY")
    if value:
        return str(value), "environment"
    root = _engine_root()
    if root:
        try:
            done = subprocess.run(
                ["bash", str(root / "bin" / "hodd.sh"), "emit", "secrets/platform.env"],
                capture_output=True,
                text=True,
                timeout=15,
            )
            for line in done.stdout.splitlines():
                if line.startswith(KEY_REF + "="):
                    return line.split("=", 1)[1].strip(), "hoard"
        except Exception:
            pass
    auth = Path(os.environ.get("PI_AUTH_JSON", os.path.expanduser("~/.pi/agent/auth.json")))
    value = _key_from_auth(auth)
    if value:
        return value, "pi-auth"
    return "", "absent"


# ── the probe — a cheap health check, then the OpenAI-compatible models list ──

def _reason_for(exc: Exception) -> str:
    if isinstance(exc, urllib.error.HTTPError):
        return f"http {exc.code}"
    if isinstance(exc, urllib.error.URLError):
        cause = getattr(exc, "reason", None)
        text = str(cause or exc).lower()
        if "timed out" in text or "timeout" in text:
            return "timeout"
        if "refused" in text:
            return "refused"
        if "name or service" in text or "nodename" in text or "getaddrinfo" in text:
            return "unreachable (dns)"
        return "unreachable"
    if isinstance(exc, (TimeoutError, socket.timeout)):
        return "timeout"
    return "unreachable"


def _get(url: str, timeout: float, key: str = "") -> tuple[int, bytes]:
    headers = {"Accept": "application/json"}
    if key:
        headers["Authorization"] = f"Bearer {key}"
    request = urllib.request.Request(url, headers=headers, method="GET")
    with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310 — a rail URL
        return int(response.status), response.read()


def _ids(body: bytes) -> tuple[str, ...]:
    try:
        doc = json.loads(body.decode("utf-8", "replace"))
    except Exception:
        return ()
    data = doc.get("data") if isinstance(doc, dict) else None
    if not isinstance(data, list):
        return ()
    out: list[str] = []
    for item in data:
        if isinstance(item, dict) and item.get("id"):
            out.append(str(item["id"]))
    return tuple(out)


def _models(target: Target, key: str, timeout: float) -> tuple[tuple[str, ...], bool]:
    try:
        status_code, body = _get(f"{target.url}/models", timeout, key)
        if 200 <= status_code < 300:
            return _ids(body), False
        return (), False
    except urllib.error.HTTPError as exc:
        return (), exc.code in (401, 403)
    except Exception:
        return (), False


def probe_http(target: Target, key: str = "", timeout: float = DEFAULT_TIMEOUT) -> Probe:
    """Judge one rail: `/health` first (keyless), then `/v1/models` (key-gated)."""
    try:
        status_code, _ = _get(f"{target.base}{HEALTH_PATH}", timeout)
        if 200 <= status_code < 300:
            models, gated = _models(target, key, timeout)
            return Probe(True, "health", models, gated)
        reason = f"http {status_code}"
    except urllib.error.HTTPError as exc:
        # a missing health route or a gated one still says the box ANSWERED
        if exc.code not in (401, 403, 404):
            return Probe(False, f"http {exc.code}")
        reason = f"http {exc.code}"
    except Exception as exc:
        return Probe(False, _reason_for(exc))

    models, key_gated = _models(target, key, timeout)
    if models or key_gated:
        return Probe(True, "models" if models else "reachable (key refused)", models, key_gated)
    return Probe(False, reason)


def _probe_all(targets: Sequence[Target], probe: ProbeFn) -> list[Rail]:
    """Judge every candidate in parallel; a probe's own fault is a dead box."""
    def judge(target: Target) -> Rail:
        try:
            result = probe(target)
        except Exception as exc:  # a probe must never sink the resolution
            result = Probe(False, _reason_for(exc))
        return Rail(
            host=target.host,
            address=target.address,
            base=target.base,
            url=target.url,
            order=target.order,
            live=bool(result.live),
            reason=result.reason,
            models=tuple(result.models or ()),
            key_gated=bool(result.key_gated),
            roles=tuple(target.roles),
        )

    if not targets:
        return []
    max_workers = max(1, len(targets))
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as pool:
        judged = dict(zip(targets, pool.map(judge, targets)))
    return [judged[target] for target in targets]


def _serving_for(rail: Rail, alias: str = "", verified: bool = False) -> Serving:
    return Serving(
        host=rail.host,
        url=rail.url,
        key_ref=KEY_REF,
        alias=alias,
        alias_verified=verified,
        models=rail.models,
    )


# ── the two verbs ────────────────────────────────────────────────────────────

def _inputs(
    *,
    registry: str | Path | None,
    self_host: str | None,
    port: int | None,
    timeout: float | None,
    doc: Mapping | None,
) -> tuple[dict, str, int, float]:
    document = dict(doc) if doc is not None else read_registry(registry)
    host = self_host or default_host()
    resolved_port = int(port if port is not None else (os.environ.get("YMIR_RAIL_PORT") or DEFAULT_PORT))
    resolved_timeout = float(
        timeout if timeout is not None else (os.environ.get("YMIR_RAIL_TIMEOUT") or DEFAULT_TIMEOUT)
    )
    return document, host, resolved_port, resolved_timeout


def status(
    *,
    registry: str | Path | None = None,
    self_host: str | None = None,
    port: int | None = None,
    timeout: float | None = None,
    key: str | None = None,
    doc: Mapping | None = None,
    probe: ProbeFn | None = None,
) -> Resolution:
    """The ranked live set, and the first live rail as the serving answer."""
    document, host, resolved_port, resolved_timeout = _inputs(
        registry=registry, self_host=self_host, port=port, timeout=timeout, doc=doc
    )
    targets = candidates(document, host, resolved_port)
    if not targets:
        return Resolution(None, (), "the registry names no strong box (rails · ear · forge)")
    if probe is None:
        if key is not None:
            shared, source = key, "given"
        else:
            shared, source = read_key()
        probe = lambda target: probe_http(target, shared, resolved_timeout)  # noqa: E731
    else:
        source = "injected"
    rails = tuple(_probe_all(targets, probe))
    live = [rail for rail in rails if rail.live]
    if live:
        serving = _serving_for(live[0])
        return Resolution(serving, rails, f"served by {serving.host}", source)
    return Resolution(None, rails, "no registered rail is alive", source)


def resolve(
    alias: str = "",
    *,
    registry: str | Path | None = None,
    self_host: str | None = None,
    port: int | None = None,
    timeout: float | None = None,
    key: str | None = None,
    doc: Mapping | None = None,
    probe: ProbeFn | None = None,
) -> Resolution:
    """The serving rail, verified against `alias` when one is named.

    With an alias, the first live box that SERVES it wins; a live box whose key
    was refused answers as the serving rail, the alias left unverified (the gate
    says so, never a fake). No live box serving the alias is a declined answer.
    """
    result = status(
        registry=registry,
        self_host=self_host,
        port=port,
        timeout=timeout,
        key=key,
        doc=doc,
        probe=probe,
    )
    name = str(alias or "").strip()
    if not name or result.serving is None:
        return result
    for rail in result.live:
        if name in rail.models:
            return replace(
                result,
                serving=_serving_for(rail, alias=name, verified=True),
                reason=f"served by {rail.host}; alias {name} verified",
            )
        if not rail.models and rail.key_gated:
            return replace(
                result,
                serving=_serving_for(rail, alias=name, verified=False),
                reason=f"served by {rail.host}; alias {name} unverified (key refused)",
            )
    return replace(result, serving=None, reason=f"alias '{name}' is served by no live rail")


def serving_url(
    alias: str = "",
    **kwargs,
) -> str:
    """The serving OpenAI base URL, or a loud refusal — the callers' one-liner."""
    result = resolve(alias, **kwargs)
    if result.serving is None:
        raise RailUnavailable(result.reason)
    return result.serving.url
