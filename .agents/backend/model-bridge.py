#!/usr/bin/env python3
"""model-bridge.py — expose a model provider to pi via an OpenAI-compatible
local endpoint.

Why: pi resolves models from ~/.pi/agent/models.json, which cannot read the API
key from the repo's .env. This bridge listens on 127.0.0.1, reads the provider
credential from .env, and proxies /v1/* to the selected provider. pi then just
registers the provider with baseUrl=http://127.0.0.1:PORT/v1 and any placeholder
key.

Providers (YMIR_MODEL_PROVIDER):
    chain         (when the home has a chain file)  every step below, in order, with fallback
    opencode-go   (default)  OpenCode Zen Go gateway — needs a key
    local-rail               the local llama.cpp rail — the second road when no key is here
    openrouter               the OpenRouter gateway — needs a key
    llamacpp                 a llama.cpp rail on another machine (a chain step names its host)
    openai-compatible        any OpenAI-compatible server — optional key

ONLY LLAMA.CPP LOCALLY (2026-11-21, at the operator's word: "only use llama. no ollama or lm
studio"). The LM Studio provider is gone from this door; the local road is the llama.cpp rail.

THE CHAIN (2026-11-21). Any machine may be off, so one door carries the fallback for every
hosted service. The steps live in the home (`<home>/config/model-chain.json`, or the file
YMIR_MODEL_CHAIN names), never here: a step names a provider, a model, and either a base URL
or a fleet HOST whose tailnet address is read from the fleet registry (YMIR_FLEET_JSON, or
fleet.json in YMIR_DATA_DIR). A request goes to the first healthy step; a step that is down,
times out, rate-limits, refuses its key or fails on its side is marked down for
YMIR_CHAIN_HEALTH_TTL seconds (default 30) and the next step is tried. The log names the step
that answered and every step passed over, and each reply carries `X-Ymir-Chain-Step`.
`GET /chain` shows the steps and their cached health; `--chain` prints them without serving.

The order when nothing is named:

    1. the operator NAMED a provider (--provider / YMIR_MODEL_PROVIDER)  — it wins
    2. the home carries a chain file      -> chain
    3. a key is readable for opencode-go  -> opencode-go
    4. the local rail answers on :8080    -> local-rail
    5. none                               -> REFUSE, naming the roads

A key is read by a DOOR, never by a guess: the env file, the process environment, the
vault (`bin/vault/hodd.sh emit secrets/platform.env`) and finally pi's own auth.json.
The value never leaves this process: it is never printed, never written into the env
file, never passed in argv (argv is world-readable through /proc).

Endpoints (OpenAI-compatible):
    GET  /v1/models                          -> model list (for pi listing)
    POST /v1/chat/completions                -> proxied (JSON or SSE stream)

Usage:
    python3 model-bridge.py [--port 4603] [--env /path/.env] [--provider NAME] [--bind HOST]
    python3 model-bridge.py --providers      # the provider names this bridge can serve
    python3 model-bridge.py --resolve-provider   # which provider it would serve, and WHY

Env:
    YMIR_MODEL_PROVIDER       chain | opencode-go | local-rail | openrouter | llamacpp | openai-compatible
    YMIR_MODEL_CHAIN          the chain file (default <YMIR_SETTINGS_DIR>/model-chain.json)
    YMIR_CHAIN_HEALTH_TTL     seconds a step's health is trusted (default 30)
    YMIR_FLEET_JSON           the fleet registry a chain step's host is read from
    YMIR_MODEL_BASE_URL       override the provider's base URL
    YMIR_MODEL_API_KEY        credential for the selected provider
    YMIR_MODEL_BIND           listen address (default 127.0.0.1); a containerised
                              client on another network names the interface it sees
    OPENCODE_GO_API_KEY       credential when provider=opencode-go
    LLAMA_SWAP_API_KEY        credential when provider=local-rail (the rail's own key)
    OPENROUTER_API_KEY        credential when provider=openrouter (else pi's auth.json)
    OPENCODE_GO_BASE_URL      default https://opencode.ai/zen/go/v1
    YMIR_RAIL_BASE_URL        default http://127.0.0.1:8080/v1 (the local rail)
    OPENCODE_GO_BRIDGE_PORT   default 4603
    YMIR_VAULT_DOOR           the vault door keyed for a sealed vault (default bin/vault/hodd.sh)
    YMIR_PI_AUTH              pi's auth.json (default ~/.pi/agent/auth.json)
"""
import argparse
import json
import os
import subprocess
import sys
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DEFAULT_PORT = 4603

# This file lives at <root>/.agents/backend/model-bridge.py, so the tree's own doors
# (the catalog, the vault) are two levels up. Reported, never assumed: a packaged copy
# that lacks them degrades to the static table rather than pretending to read them.
ROOT = __import__("pathlib").Path(__file__).resolve().parents[2]

# Provider catalogue. `key_env` lists the env names checked, in order; an empty
# key requirement (the local rail) means the bridge starts with no credential.
#
# `vault_key` and `pi_auth` are the two further doors a credential may sit behind on this
# machine (plan 275 item 22): the house vault is the private store, and pi's auth.json is
# what the harness itself uses. `catalog` names the provider as `bin/model/catalog.sh`
# lists it, so /v1/models can answer from the catalogue rather than a stale table.
PROVIDERS = {
    "opencode-go": {
        "base_url": "https://opencode.ai/zen/go/v1",
        "base_url_env": "OPENCODE_GO_BASE_URL",
        "key_env": ["OPENCODE_GO_API_KEY", "YMIR_MODEL_API_KEY"],
        "vault_key": "OPENCODE_GO_API_KEY",
        "pi_auth": "opencode-go",
        "catalog": "opencode-go",
        "requires_key": True,
    },
    "local-rail": {
        "base_url": "http://127.0.0.1:8080/v1",
        "base_url_env": "YMIR_RAIL_BASE_URL",
        "key_env": ["LLAMA_SWAP_API_KEY", "YMIR_MODEL_API_KEY"],
        "vault_key": "LLAMA_SWAP_API_KEY",
        "pi_auth": "llama-swap",
        "catalog": "llama-swap",
        "requires_key": False,
    },
    "openrouter": {
        "base_url": "https://openrouter.ai/api/v1",
        "base_url_env": "OPENROUTER_BASE_URL",
        "key_env": ["OPENROUTER_API_KEY"],
        "vault_key": "OPENROUTER_API_KEY",
        "pi_auth": "openrouter",
        "catalog": "openrouter",
        "requires_key": True,
    },
    # A llama.cpp rail on another machine. It has no default address: a chain step names
    # the fleet host (or a base URL), and its key, if the rail is keyed, by pi_auth/key_env.
    "llamacpp": {
        "base_url": "",
        "base_url_env": "YMIR_LLAMACPP_BASE_URL",
        "key_env": [],
        "catalog": "",
        "requires_key": False,
    },
    "openai-compatible": {
        "base_url": "",
        "base_url_env": "YMIR_MODEL_BASE_URL",
        "key_env": ["YMIR_MODEL_API_KEY"],
        "catalog": "",
        "requires_key": False,
    },
}

# The provider the bridge falls to when no key exists — the llama.cpp rail, never a
# retired door (plan 275 item 22): a door that answers `curl: (7)` is a second failure.
FALLBACK_PROVIDER = "local-rail"

# The static table is the LAST resort, for a machine where neither the provider nor the
# catalogue can answer. It is not an opinion about what the gateway serves — the
# catalogue is (`bin/model/catalog.sh`) — and it is deliberately short.
MODELS = [
    {"id": "deepseek-v4.1-flash", "contextWindow": 1000000, "input": ["text"]},
]

# Resolved at startup.
KEY = ""
BASE_URL = ""
PROVIDER = "opencode-go"
BIND = "127.0.0.1"

# The gateway sits behind Cloudflare, which BANS the signature of a scripted
# client (Python-urllib/3.x) with error 1010: "banned your access based on your
# browser's signature". That was the whole 403 - our own bridge was the client.
USER_AGENT = os.environ.get("YMIR_MODEL_UA", "curl/8.5.0")
SESSION_ID = os.environ.get("YMIR_MODEL_SESSION") or str(__import__("uuid").uuid4())


def load_env(path: str) -> dict:
    env = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                env[k.strip()] = v.strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return env


def resolve_provider(env: dict, cli_provider: str | None) -> str:
    """The provider this bridge serves. `cli_provider` is the operator's NAME, if any.

    Named beats detected — but when nothing is named the fallback is decided by what is
    actually here, and it is never a retired door (plan 275 item 22): a door answering
    `curl: (7)` behind a bare 500 is how OmniChat lost every model at once.
    """
    name, _why = choose_provider(env, cli_provider)
    if not name:
        print("[bridge] ERROR: no provider to serve — "
              "no key for opencode-go, and the local rail does not answer.\n"
              "  named:   --provider chain | opencode-go | local-rail | openrouter | openai-compatible\n"
              "  chain:   write the steps into <home>/config/model-chain.json\n"
              "  keyed:   put OPENCODE_GO_API_KEY in the vault (bin/vault/hodd.sh emit secrets/platform.env)\n"
              "  local:   raise the llama.cpp rail on :8080, or set YMIR_RAIL_BASE_URL", file=sys.stderr)
        raise SystemExit(1)
    if name not in PROVIDERS and name != "chain":
        print(f"[bridge] ERROR: unknown provider '{name}'. "
              f"Choose one of: {', '.join(PROVIDERS)}", file=sys.stderr)
        raise SystemExit(2)
    return name


def choose_provider(env: dict, cli_provider: str | None) -> tuple[str, str]:
    """(provider, why). The `why` is REPORTED because a door that cannot say why it chose
    a provider leaves the operator guessing at the one place the fleet already broke."""
    named = (cli_provider or env.get("YMIR_MODEL_PROVIDER")
             or os.environ.get("YMIR_MODEL_PROVIDER") or "").strip()
    if named:
        return named, "named by the operator"
    chain_file = chain_path(env)
    if chain_file:
        return "chain", f"the home carries a chain ({chain_file})"
    spec = PROVIDERS["opencode-go"]
    key, where = resolve_key(env, spec)
    if key:
        return "opencode-go", f"a key is readable ({where})"
    rail = resolve_base_url(env, PROVIDERS[FALLBACK_PROVIDER])
    if rail_answers(rail):
        return FALLBACK_PROVIDER, f"no key, and the rail answers on {rail}"
    return "", "no key for opencode-go and no rail answering"


def vault_env() -> dict:
    """The vault's secret names, read through the ONE door and kept in memory.

    `bin/vault/hodd.sh emit secrets/platform.env` is the house's single way to a secret
    (Rule 04: referenced, never inlined). It is bounded, it is silent on failure, and
    nothing it prints is ever logged — only the KEY'S NAME may be reported.
    """
    door = os.environ.get("YMIR_VAULT_DOOR") or str(ROOT / "bin" / "vault" / "hodd.sh")
    if not os.path.exists(door):
        return {}
    try:
        out = subprocess.run(["bash", door, "emit", "secrets/platform.env"],
                             capture_output=True, timeout=25).stdout.decode("utf-8", "replace")
    except Exception:
        return {}
    return load_env_text(out)


def load_env_text(text: str) -> dict:
    """KEY=value per line, with the `export ` the vault door adds stripped."""
    env = {}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[len("export "):]
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def pi_auth_key(name: str) -> str:
    """pi's own credential for a provider, from `~/.pi/agent/auth.json` (a documented
    pi path, never a house one). The harness reads its key there, so a bridge serving
    the same rail reads the same key instead of inventing a second place."""
    if not name:
        return ""
    path = os.environ.get("YMIR_PI_AUTH") or os.path.expanduser("~/.pi/agent/auth.json")
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception:
        return ""
    v = data.get(name) if isinstance(data, dict) else None
    if isinstance(v, dict):
        return str(v.get("key") or "")
    return v if isinstance(v, str) else ""


def resolve_base_url(env: dict, spec: dict) -> str:
    for holder in (env, os.environ):
        v = holder.get("YMIR_MODEL_BASE_URL")
        if v:
            return v
    v = env.get(spec["base_url_env"]) or os.environ.get(spec["base_url_env"])
    return v or spec["base_url"]


def rail_answers(base_url: str, timeout: float = 1.5) -> bool:
    """Does the local rail answer at its root? A closed port is a fast, quiet no."""
    if not base_url:
        return False
    root = base_url.rstrip("/")
    root = root[:-3] if root.endswith("/v1") else root
    try:
        req = urllib.request.Request(root + "/v1/models",
                                     headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return 200 <= r.status < 500
    except urllib.error.HTTPError as e:
        # 401 from a keyed rail still proves the door is OPEN: the model is served there.
        return e.code in (401, 403)
    except Exception:
        return False


def resolve_key(env: dict, spec: dict) -> tuple[str, str]:
    """(key, where it came from). The second half is REPORTED, never implied: a
    bridge that says 'key from <env file>' while it really read the environment
    is a small lie in the one place an operator looks to understand the door."""
    for name in spec["key_env"]:
        v = env.get(name)
        if v:
            return v, f"{name} in the env file"
        v = os.environ.get(name)
        if v:
            return v, f"{name} in the environment"
    vault_name = spec.get("vault_key")
    if vault_name:
        v = vault_env().get(vault_name)
        if v:
            return v, f"{vault_name} in the vault"
    pi_name = spec.get("pi_auth")
    if pi_name:
        v = pi_auth_key(pi_name)
        if v:
            return v, f"{pi_name} in pi's auth.json"
    return "", "no key"


def catalog_models(spec: dict) -> list:
    """The models this provider serves, from the ONE catalogue door.

    `/v1/models` answered `deepseek-v4-flash` for a whole week because the bridge fell back
    to a hand-written table while the gateway was unreachable — so a model the house uses
    (v4.1) was invisible to every chat that listed models. `bin/model/catalog.sh` already
    knows every model pi can serve; the bridge reads it rather than keeping a second table.
    """
    wanted = spec.get("catalog") or ""
    if not wanted:
        return []
    door = os.environ.get("YMIR_CATALOG_BIN") or str(ROOT / "bin" / "model" / "catalog.sh")
    if not os.path.exists(door):
        return []
    try:
        out = subprocess.run(["bash", door], capture_output=True, timeout=45).stdout.decode("utf-8", "replace")
    except Exception:
        return []
    rows = []
    for line in out.splitlines():
        line = line.strip()
        if not line.startswith('"'):
            continue
        cells = [c.strip().strip('"') for c in line.rstrip(",").split('","')]
        cells = [c.strip('"') for c in cells]
        if len(cells) < 2 or cells[0] != wanted:
            continue
        rows.append({"id": cells[1], "object": "model"})
    return rows


# --------------------------------------------------------------------------- the chain
# Resolved at startup when the provider is `chain`; HEALTH is the cached answer per step.
CHAIN: list = []
HEALTH: dict = {}
_HEALTH_LOCK = __import__("threading").Lock()


def health_ttl() -> float:
    try:
        return float(os.environ.get("YMIR_CHAIN_HEALTH_TTL", "30"))
    except ValueError:
        return 30.0


def chain_path(env: dict) -> str:
    """The chain file, or "" when this home carries none. Named by YMIR_MODEL_CHAIN, else the
    home's settings shelf. Never a path in this tree: the steps name the operator's machines."""
    named = env.get("YMIR_MODEL_CHAIN") or os.environ.get("YMIR_MODEL_CHAIN") or ""
    if named:
        return named if os.path.exists(named) else ""
    settings = os.environ.get("YMIR_SETTINGS_DIR") or ""
    if not settings and os.environ.get("YMIR_HOME"):
        settings = os.path.join(os.environ["YMIR_HOME"], "config")
    if settings:
        cand = os.path.join(settings, "model-chain.json")
        if os.path.exists(cand):
            return cand
    return ""


def fleet_hosts() -> dict:
    path = os.environ.get("YMIR_FLEET_JSON") or ""
    if not path and os.environ.get("YMIR_DATA_DIR"):
        path = os.path.join(os.environ["YMIR_DATA_DIR"], "fleet.json")
    if not path:
        return {}
    try:
        with open(path) as f:
            return (json.load(f) or {}).get("hosts", {}) or {}
    except Exception:
        return {}


def load_chain(env: dict, path: str) -> list:
    """Read the steps and resolve each one's address and key. A step whose host or key
    cannot be resolved stays in the list, marked, so the log and /chain can say why."""
    with open(path) as f:
        data = json.load(f)
    hosts = fleet_hosts()
    steps = []
    for i, raw in enumerate(data.get("steps", [])):
        kind = raw.get("provider", "")
        base_spec = PROVIDERS.get(kind)
        step = {"name": raw.get("name") or f"step-{i + 1}", "provider": kind,
                "model": raw.get("model") or "*", "timeout": int(raw.get("timeout", 120)),
                "probe_timeout": int(raw.get("probe_timeout", 5)),
                "base": "", "key": "", "key_where": "no key", "problem": ""}
        if not base_spec or kind == "chain":
            step["problem"] = f"unknown provider '{kind}'"
            steps.append(step)
            continue
        spec = dict(base_spec)
        if raw.get("pi_auth"):
            spec["pi_auth"] = raw["pi_auth"]
        if raw.get("key_env"):
            spec["key_env"] = [raw["key_env"]] + list(spec.get("key_env", []))
            spec["vault_key"] = raw["key_env"]
        base = raw.get("base_url", "")
        if not base and raw.get("host"):
            h = hosts.get(raw["host"]) or {}
            addr = h.get("tailnet") or h.get("lan") or ""
            if addr:
                base = f"http://{addr}:{int(raw.get('port', 8080))}/v1"
            else:
                step["problem"] = f"host '{raw['host']}' has no address in the fleet registry"
        if not base and not raw.get("host"):
            base = env.get(spec["base_url_env"]) or os.environ.get(spec["base_url_env"]) or spec["base_url"]
        step["base"] = base
        if base:
            step["key"], step["key_where"] = resolve_key(env, spec)
            if spec.get("requires_key") and not step["key"]:
                step["problem"] = "no key readable"
        steps.append(step)
    return steps


def _step_headers(step: dict, stream: bool = False) -> dict:
    h = {"Content-Type": "application/json",
         "Accept": "text/event-stream" if stream else "application/json",
         "User-Agent": USER_AGENT,
         "x-opencode-session": SESSION_ID}
    if step.get("key"):
        h["Authorization"] = f"Bearer {step['key']}"
    return h


def _mark(step: dict, ok: bool, why: str) -> None:
    with _HEALTH_LOCK:
        HEALTH[step["name"]] = (__import__("time").time(), ok, why)


def step_healthy(step: dict) -> tuple[bool, str]:
    """(usable, why). Cached for health_ttl() seconds so a dead machine costs one probe per
    window, not one per request. The probe is GET <base>/models, bounded by the step's
    probe_timeout (default 5 s; a gateway with a long model list may need more)."""
    if step.get("problem"):
        return False, step["problem"]
    now = __import__("time").time()
    with _HEALTH_LOCK:
        cached = HEALTH.get(step["name"])
    if cached and now - cached[0] < health_ttl():
        return cached[1], cached[2] + " (cached)"
    try:
        req = urllib.request.Request(step["base"].rstrip("/") + "/models", headers=_step_headers(step))
        r = _curl_open(req, timeout=step.get("probe_timeout", 5))
        ok = 200 <= r.status < 300
        why = "probe ok" if ok else f"probe http {r.status}"
    except OSError as e:
        ok, why = False, "probe unreachable: " + str(e).strip().splitlines()[0][:80] if str(e).strip() else "probe unreachable"
    _mark(step, ok, why)
    return ok, why


# Statuses that say the STEP is unwell (mark it down for the window). Any other non-2xx
# falls through to the next step for this request only: a 400 may be the request's fault.
_STEP_DOWN = {401, 403, 408, 429}


def _is_error_body(body: bytes, stream: bool) -> bool:
    """A 200 that carries an error and no answer is a refusal, not an answer."""
    head = body[:4096]
    if stream:
        return b'"error"' in head and b'"choices"' not in head
    try:
        d = json.loads(body or b"{}")
    except Exception:
        return False
    return isinstance(d, dict) and "error" in d and "choices" not in d


def chain_status() -> list:
    rows = []
    for st in CHAIN:
        with _HEALTH_LOCK:
            h = HEALTH.get(st["name"])
        rows.append({"step": st["name"], "provider": st["provider"], "model": st["model"],
                     "base_url": st["base"], "key": "present" if st["key"] else st["key_where"],
                     "problem": st["problem"],
                     "health": None if not h else {"ok": h[1], "why": h[2],
                                                   "age_s": round(__import__("time").time() - h[0], 1)}})
    return rows



def is_https(url: str) -> bool:
    return url.startswith("https://")


def split_url(url: str) -> tuple[str, str]:
    rest = url.split("://", 1)[1]
    host, _, path = rest.partition("/")
    return host, "/" + path if path else ""


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # quieter, timestamped
        print(f"[bridge] {self.log_date_time_string()} {fmt % args}", flush=True)

    def _send(self, code: int, body: bytes, ctype: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _models(self) -> list:
        # Ask the provider what it serves; then the catalogue (the house's one
        # opinion); then the static table, which is nothing but a last resort.
        try:
            req = urllib.request.Request(_upstream("models"),
                                         headers={**_auth_headers(), "User-Agent": USER_AGENT,
         # The Zen gateway requires a session id; without it: 400 MissingSessionID.
         "x-opencode-session": SESSION_ID})
            with _curl_open(req, timeout=10) as r:
                data = json.loads(r.read())
            live = data.get("data", [])
            if live:
                return live
        except Exception:
            pass
        from_catalog = catalog_models(PROVIDERS.get(PROVIDER, {}))
        if from_catalog:
            return from_catalog
        return [{"id": m["id"], "object": "model"} for m in MODELS]

    def do_GET(self):
        if self.path.split("?")[0] in ("/chain", "/v1/chain"):
            for st in CHAIN:
                step_healthy(st)
            self._send(200, json.dumps({"provider": PROVIDER, "steps": chain_status()}).encode(),
                       "application/json")
            return
        if self.path.split("?")[0] == "/v1/models" and PROVIDER == "chain":
            ids = ["auto"] + [st["model"] for st in CHAIN if st["model"] != "*"]
            seen = []
            for i in ids:
                if i not in seen:
                    seen.append(i)
            payload = {"object": "list", "data": [{"id": i, "object": "model"} for i in seen]}
            self._send(200, json.dumps(payload).encode(), "application/json")
            return
        if self.path.split("?")[0] == "/v1/models":
            payload = {"object": "list", "data": self._models()}
            self._send(200, json.dumps(payload).encode(), "application/json")
        else:
            self._send(404, json.dumps({"error": "not found"}).encode(), "application/json")

    def do_POST(self):
        if self.path.split("?")[0] != "/v1/chat/completions":
            self._send(404, json.dumps({"error": "not found"}).encode(), "application/json")
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length) if length else b"{}"
            req = json.loads(body)
            if PROVIDER == "chain":
                self._chain(req, bool(req.get("stream")))
                return
            mid = req.get("model", "")
            # opencode-go rejects the `opencode-go/` prefix; strip provider prefixes.
            if PROVIDER == "opencode-go" and "/" in mid and mid.split("/", 1)[0] != "openai":
                req["model"] = mid.split("/", 1)[1]
            # Name the model on every request: a generation is only PROVEN to have
            # used a model when the door says which one it forwarded (2026-11-10).
            print(f"[bridge] model={req['model']} provider={PROVIDER} stream={bool(req.get('stream'))}", flush=True)
            body = json.dumps(req).encode()
            self._proxy(body, req.get("stream", False))
        except Exception as e:
            print(f"[bridge] proxy error: {e}", flush=True)
            try:
                self._send(500, json.dumps({"error": str(e)}).encode(), "application/json")
            except Exception:
                pass

    def _chain(self, req: dict, stream: bool) -> None:
        """Walk the chain: the first healthy step that answers is relayed; every step passed
        over is named in the log, so the operator can see which road carried the call."""
        asked = req.get("model", "")
        passed = []
        last = None
        # Two passes. The first trusts the health cache; the LAST-DITCH pass asks each step the
        # health check skipped (never one with a config problem) once, because a probe can be
        # wrong — a slow model list is not a dead gateway — and a 503 is the worst answer.
        skipped = []
        order = [(st, False) for st in CHAIN]
        i = 0
        while i < len(order):
            st, last_ditch = order[i]
            i += 1
            if not last_ditch:
                ok, why = step_healthy(st)
                if not ok:
                    passed.append(f"{st['name']}=skip({why})")
                    if not st.get("problem"):
                        skipped.append(st)
                    if i == len(order) and skipped:
                        order += [(s2, True) for s2 in skipped]
                    continue
            r = dict(req)
            if st["model"] != "*":
                r["model"] = st["model"]
            elif st["provider"] == "opencode-go" and "/" in str(asked):
                r["model"] = str(asked).split("/", 1)[1]
            up = urllib.request.Request(st["base"].rstrip("/") + "/chat/completions",
                                        data=json.dumps(r).encode(), headers=_step_headers(st, stream),
                                        method="POST")
            try:
                resp = _curl_open(up, timeout=st["timeout"])
            except OSError as e:
                why = "unreachable or timed out: " + (str(e).strip().splitlines() or [""])[0][:80]
                _mark(st, False, why)
                passed.append(f"{st['name']}={why}{' (last ditch)' if last_ditch else ''}")
                if i == len(order) and skipped and not last_ditch:
                    order += [(s2, True) for s2 in skipped]
                continue
            whole = resp.read()
            if 200 <= resp.status < 300 and not _is_error_body(whole, stream):
                _mark(st, True, "answered")
                print(f"[chain] answered step={st['name']}{' (last ditch)' if last_ditch else ''} provider={st['provider']} model={r['model']} "
                      f"asked={asked or '-'} stream={stream} passed=[{'; '.join(passed)}]", flush=True)
                self._relay(resp.status, whole, stream, st["name"])
                return
            why = f"http {resp.status}" + (" refusal" if 200 <= resp.status < 300 else "")
            if resp.status in _STEP_DOWN or resp.status >= 500 or 200 <= resp.status < 300:
                _mark(st, False, why)
            passed.append(f"{st['name']}={why}{' (last ditch)' if last_ditch else ''}")
            last = (resp.status, whole)
            if i == len(order) and skipped and not last_ditch:
                order += [(s2, True) for s2 in skipped]
        print(f"[chain] NO STEP ANSWERED asked={asked or '-'} passed=[{'; '.join(passed)}]", flush=True)
        payload = {"error": {"message": "no model step answered", "passed": passed,
                             "last_status": last[0] if last else None}}
        self._send(503, json.dumps(payload).encode(), "application/json")

    def _relay(self, status: int, whole: bytes, stream: bool, step: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "text/event-stream" if stream else "application/json")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Ymir-Chain-Step", step)
        if stream:
            self.send_header("Transfer-Encoding", "chunked")
            self.send_header("Connection", "close")
        else:
            self.send_header("Content-Length", str(len(whole)))
        self.end_headers()
        try:
            if stream:
                if whole:
                    self.wfile.write(f"{len(whole):x}\r\n".encode() + whole + b"\r\n")
                self.wfile.write(b"0\r\n\r\n")
            else:
                self.wfile.write(whole)
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _proxy(self, body: bytes, stream: bool) -> None:
        req = urllib.request.Request(
            _upstream("chat/completions"),
            data=body,
            headers=_auth_headers(stream),
            method="POST",
        )
        try:
            resp = _curl_open(req, timeout=300)
        except urllib.error.HTTPError as e:
            # Relay the provider's error verbatim so the operator sees the cause.
            payload = e.read()
            self._send(e.code, payload, e.headers.get("Content-Type", "application/json"))
            return
        self.send_response(resp.status)
        ctype = resp.headers.get("Content-Type", "application/json")
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-cache")
        if stream:
            # no Content-Length: frame as chunked so the client gets EOF at
            # the terminating 0-chunk even though upstream SSE never closes
            self.send_header("Transfer-Encoding", "chunked")
            self.send_header("Connection", "close")
            chunked = True
        else:
            # A NON-STREAM REPLY IS DELIMITED, ALWAYS (2026-11-14, plan 275 item 22). The
            # upstream body is already whole in memory here, so the honest framing is its
            # real length — never "no length and hope the client stops" — and the body is
            # written once instead of re-read until the socket fills the disk.
            whole = resp.read()
            self.send_header("Content-Length", str(len(whole)))
            chunked = False
        self.end_headers()
        if not chunked:
            try:
                self.wfile.write(whole)
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
            return
        while True:
            chunk = resp.read(4096)
            if not chunk:
                break
            try:
                if chunked:
                    self.wfile.write(f"{len(chunk):x}\r\n".encode() + chunk + b"\r\n")
                else:
                    self.wfile.write(chunk)
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                break  # client went away; upstream closes with us
        if chunked:
            try:
                self.wfile.write(b"0\r\n\r\n")
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass


def _upstream(suffix: str) -> str:
    return BASE_URL.rstrip("/") + "/" + suffix


def _auth_headers(stream: bool = False) -> dict:
    h = {"Content-Type": "application/json",
         "Accept": "text/event-stream" if stream else "application/json",
         # Cloudflare at the gateway bans the signature of a scripted client
         # (Python-urllib/3.x) with error 1010. Our own bridge WAS that client,
         # which is why every worker's first turn came back 403.
         "User-Agent": USER_AGENT,
         # The Zen gateway requires a session id; without it: 400 MissingSessionID.
         "x-opencode-session": SESSION_ID}
    if KEY:
        h["Authorization"] = f"Bearer {KEY}"
    return h



class _CurlResponse:
    """What urlopen's callers actually use: .status, .read(), iteration.

    My first curl transport returned a bare BytesIO, so the proxy died on
    '.status' - a bridge that answers 500 looks like a broken model when it is a
    broken wrapper. This presents the shape the callers expect.

    AND `.read(n)` MUST CONSUME (2026-11-14, plan 275 item 22): the first version
    returned the WHOLE body on every call, so the proxy's `while chunk := resp.read(4096)`
    loop never ended — it re-wrote the same 640-byte reply forever and a chat client was
    handed a response with no end (measured: one completion through :4604 produced a 13 GB
    download of repeated JSON). A wrapper whose read() does not advance is not a stream.
    """

    def __init__(self, body: bytes, status: int):
        self._buf = __import__("io").BytesIO(body)
        self.status = status
        self.headers = {"content-type": "application/json"}

    def read(self, n: int = -1) -> bytes:
        return self._buf.read(n)

    def __iter__(self):
        return iter(self._buf.readlines())

    def __enter__(self):
        return self

    def __exit__(self, *_a):
        return False


def _curl_open(req, timeout: int = 60):
    """Perform an upstream request with curl's fingerprint.

    Cloudflare at the gateway bans a scripted client's TLS shape (error 1010,
    browser_signature_banned) whatever User-Agent it claims - measured: urllib 403,
    curl 200 on the same request. So the bridge speaks through curl and hands the
    caller a response-shaped object.
    """
    import json as _json, subprocess
    argv = ["curl", "-sS", "--max-time", str(timeout), "-w", "\n%{http_code}",
            "-X", (req.get_method() or "GET")]
    for k, v in (req.header_items() or []):
        argv += ["-H", f"{k}: {v}"]
    # THE BODY NEVER RIDES IN argv. A prompt is user content and grows without
    # bound; argv has a hard kernel limit (E2BIG, ~128 KiB per argument on this
    # host) that surfaces as "[Errno 7] Argument list too long: 'curl'" — a 500 on
    # a request that was perfectly valid (measured 2026-10-24: every errand whose
    # prompt crossed the line died here). curl reads the body from stdin instead.
    data = req.data
    if data:
        argv += ["--data-binary", "@-"]
    argv.append(req.full_url)
    payload = data if isinstance(data, (bytes, type(None))) else str(data).encode()
    out = subprocess.run(argv, capture_output=True, input=payload)
    raw = out.stdout
    body, _, tail = raw.rpartition(b"\n")
    try:
        status = int(tail.strip() or b"0")
    except ValueError:
        body, status = raw, 0
    if status == 0 and out.returncode != 0:
        raise OSError((out.stderr or b"curl failed").decode()[:300])
    return _CurlResponse(body, status or 200)


def _self_test() -> int:
    """Prove a body far larger than argv allows still crosses (E2BIG regression).

    A 2 MiB payload is sent through `_curl_open` to a throwaway local sink. Before
    the fix this raised OSError(7, 'Argument list too long'); a body that large is
    an ordinary long prompt, not an edge case.
    """
    import threading
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    got = {}

    class Sink(BaseHTTPRequestHandler):
        def do_POST(self):
            n = int(self.headers.get("Content-Length") or 0)
            got["len"] = len(self.rfile.read(n))
            self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
        def log_message(self, *a):
            pass

    srv = ThreadingHTTPServer(("127.0.0.1", 0), Sink)
    threading.Thread(target=srv.handle_request, daemon=True).start()
    port = srv.server_address[1]
    body = b"x" * (2 * 1024 * 1024)
    req = urllib.request.Request(f"http://127.0.0.1:{port}/", data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    ok = True
    try:
        _curl_open(req, timeout=30)
    except OSError as e:
        ok = False
        print(json.dumps({"bridge_self_test": "FAIL", "error": str(e)}))
    srv.server_close()
    if ok and got.get("len") == len(body):
        print(json.dumps({"bridge_self_test": "PASS", "bytes": got["len"]}))
        return 0
    print(json.dumps({"bridge_self_test": "FAIL", "received": got.get("len")}))
    return 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--self-test", action="store_true", help="prove a multi-megabyte body crosses (E2BIG regression)")
    ap.add_argument("--port", type=int,
                    default=int(os.environ.get("OPENCODE_GO_BRIDGE_PORT", DEFAULT_PORT)))
    ap.add_argument("--env", default=os.environ.get("ENV_FILE",
                    str(__import__("pathlib").Path(__file__).resolve().parents[1] / ".env")))
    ap.add_argument("--provider", default=None,
                    help="chain | opencode-go | local-rail | openrouter | llamacpp | openai-compatible")
    ap.add_argument("--bind", default=os.environ.get("YMIR_MODEL_BIND", "127.0.0.1"),
                    help="listen address (default 127.0.0.1, or YMIR_MODEL_BIND)")
    ap.add_argument("--chain", action="store_true",
                    help="print the chain's steps and their health (probed now), without serving")
    ap.add_argument("--providers", action="store_true",
                    help="print the provider names this bridge can serve, one per line")
    ap.add_argument("--resolve-provider", dest="resolve_provider", action="store_true",
                    help="print which provider this bridge would serve, and WHY, without serving")
    args = ap.parse_args()
    if getattr(args, "self_test", False):
        return _self_test()
    if args.providers:
        print("\n".join(PROVIDERS))
        return 0
    if args.chain:
        env = load_env(args.env)
        path = chain_path(env)
        if not path:
            print("chain: none — no model-chain.json in the home's settings (YMIR_MODEL_CHAIN unset)")
            return 1
        CHAIN[:] = load_chain(env, path)
        print(f"chain[{len(CHAIN)}]{{step,provider,model,base_url,key,healthy,why}}:")
        for st in CHAIN:
            ok, why = step_healthy(st)
            print('  "%s","%s","%s","%s","%s",%s,"%s"' % (st["name"], st["provider"], st["model"], st["base"],
                  "present" if st["key"] else st["key_where"], "true" if ok else "false", why))
        return 0
    if getattr(args, "resolve_provider", False):
        env = load_env(args.env)
        name, why = choose_provider(env, args.provider)
        if name == "chain":
            print('provider[4]{provider,why,base_url,key}:')
            print('  "chain","%s","%s","per step"' % (why, chain_path(env)))
            return 0
        spec = PROVIDERS.get(name, {})
        base = resolve_base_url(env, spec) if spec else ""
        _key, where = resolve_key(env, spec) if spec else ("", "no key")
        print('provider[4]{provider,why,base_url,key}:')
        print('  "%s","%s","%s","%s"' % (name or "NONE", why, base or "",
                                            "present" if _key else where))
        return 0 if name else 1

    global KEY, BASE_URL, PROVIDER, BIND
    BIND = args.bind
    env = load_env(args.env)
    PROVIDER = resolve_provider(env, args.provider)
    if PROVIDER == "chain":
        path = chain_path(env)
        if not path:
            print("[bridge] ERROR: provider 'chain' named, but the home carries no model-chain.json "
                  "(set YMIR_MODEL_CHAIN or write <home>/config/model-chain.json)", file=sys.stderr)
            return 1
        CHAIN[:] = load_chain(env, path)
        if not CHAIN:
            print(f"[bridge] ERROR: the chain {path} has no steps", file=sys.stderr)
            return 1
        for st in CHAIN:
            print(f"[chain] step {st['name']}: {st['provider']} model={st['model']} -> {st['base'] or '-'} "
                  f"({'key present' if st['key'] else st['key_where']}){' PROBLEM: ' + st['problem'] if st['problem'] else ''}",
                  flush=True)
        print(f"[bridge] provider 'chain' on {BIND}:{args.port}/v1 ({len(CHAIN)} steps, from {path})", flush=True)
        srv = ThreadingHTTPServer((BIND, args.port), Handler)
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            print("\n[bridge] stopped", flush=True)
        return 0
    spec = PROVIDERS[PROVIDER]
    BASE_URL = resolve_base_url(env, spec)
    KEY, KEY_SOURCE = resolve_key(env, spec)

    if spec["requires_key"] and not KEY:
        print(f"[bridge] ERROR: provider '{PROVIDER}' requires a key. Set "
              f"{' or '.join(spec['key_env'])} in {args.env}, in the vault, or in pi's auth.json — "
              f"or choose the local rail with '--provider local-rail'.", file=sys.stderr)
        return 1
    if not BASE_URL:
        print(f"[bridge] ERROR: provider '{PROVIDER}' has no base URL. Set "
              f"YMIR_MODEL_BASE_URL in {args.env}.", file=sys.stderr)
        return 1

    host, path = split_url(BASE_URL)
    keynote = "no key required" if not KEY else f"key from {KEY_SOURCE}"
    print(f"[bridge] provider '{PROVIDER}' on {BIND}:{args.port}/v1 "
          f"-> {host}{path.rstrip('/')}/chat/completions ({keynote})", flush=True)

    srv = ThreadingHTTPServer((BIND, args.port), Handler)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n[bridge] stopped", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
