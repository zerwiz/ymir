#!/usr/bin/env python3
"""gimle_oauth.py — the MCP door as an OAuth 2.1 resource server (plan 149, item 1).

Standard library only, like the door it sits beside. The door never runs a login itself: an identity
provider (the issuer — Dex with Google and GitHub connectors, or Authelia, or any OIDC issuer) logs the
person in, and this module only answers three questions about a bearer token:

  1. is it real?        — a JWT verified against the issuer's JWKS (RS256/384/512), or RFC 7662
                          introspection against the issuer; `--oauth-mode` picks, `auto` tries JWT first
  2. is it for us?      — its audience (or `client_id`) must be one of the door's own client ids, or the
                          door's resource URL; a token another app was given is refused, by name
  3. who, and which groups? — `userinfo` (plus the token's own claims) gives `preferred_username`
                          (then `email`, then `sub`) as the Gimlé subject, and `groups` for scope

What a client sees, per the MCP authorization spec (RFC 9728 shape):

  GET /.well-known/oauth-protected-resource[/mcp]  → {"resource", "authorization_servers": [issuer], …}
  401 on a missing or bad token                    → WWW-Authenticate: Bearer resource_metadata="…"

The header is what makes a client (a custom connector, a CLI harness, mcp-remote) begin the login.

Groups decide scope (plan 149, item 3) — `scope_from_groups()`:
  gimle-all              → every place
  gimle-place-<Name>     → that place (a name may carry spaces: `gimle-place-acme/Field Notes`)
  gimle-write            → may write — and only if the door itself runs with --allow-write
  no place group         → no places (default deny, the same as the token file)
A group may arrive prefixed the way Dex's GitHub connector names teams (`<org>:<team>`); the part after the
last `:` is what is matched, so a team named `gimle-all` in any org the issuer trusts works as-is.

A local groups file (`--oauth-groups`) adds groups per person for issuers that carry none (Google without
a Workspace admin key, GitHub without teams): one line per person, `<username|email|sub> <group>,<group>`.

Cache: a verified identity is kept ≈60 s (never past the token's own `exp`); a refusal ≈10 s, so a busy
client — or a broken one retrying — does not hammer the issuer.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

GROUP_ALL = "gimle-all"
GROUP_WRITE = "gimle-write"
GROUP_PLACE = "gimle-place-"

# DigestInfo prefixes for EMSA-PKCS1-v1_5 (RFC 8017 §9.2, note 1).
_DIGEST_INFO = {
    "RS256": (hashlib.sha256, bytes.fromhex("3031300d060960864801650304020105000420")),
    "RS384": (hashlib.sha384, bytes.fromhex("3041300d060960864801650304020205000430")),
    "RS512": (hashlib.sha512, bytes.fromhex("3051300d060960864801650304020305000440")),
}


class Refused(Exception):
    """A token that does not admit its bearer. `why` is the sentence the ledger records."""

    def __init__(self, why: str, subject: str = ""):
        super().__init__(why)
        self.why = why
        self.subject = subject


def b64url_decode(s: str) -> bytes:
    s = s.strip()
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def b64url_encode(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def rsa_verify(alg: str, n: int, e: int, signing_input: bytes, sig: bytes) -> bool:
    """RSASSA-PKCS1-v1_5 verification with nothing but pow() — the door takes no crypto dependency."""
    if alg not in _DIGEST_INFO:
        return False
    hash_fn, prefix = _DIGEST_INFO[alg]
    k = (n.bit_length() + 7) // 8
    if len(sig) != k:
        return False
    s = int.from_bytes(sig, "big")
    if s >= n:
        return False
    em = pow(s, e, n).to_bytes(k, "big")
    t = prefix + hash_fn(signing_input).digest()
    if k < len(t) + 11:
        return False
    expected = b"\x00\x01" + b"\xff" * (k - len(t) - 3) + b"\x00" + t
    return hmac.compare_digest(em, expected)


def scope_from_groups(groups, all_group: str = GROUP_ALL, write_group: str = GROUP_WRITE,
                      place_prefix: str = GROUP_PLACE) -> tuple[list[str], bool]:
    """Groups → (places, may_write): `<place_prefix><Name>` → place Name, `all_group` → '*'.

    The door's --allow-write still decides whether writing is possible at all."""
    places: list[str] = []
    may_write = False
    for raw in groups or []:
        g = str(raw).strip()
        if ":" in g:
            g = g.rsplit(":", 1)[1].strip()
        if g == all_group:
            if "*" not in places:
                places.append("*")
        elif g == write_group:
            may_write = True
        elif g.startswith(place_prefix):
            name = g[len(place_prefix):].strip()
            if name and name not in places:
                places.append(name)
    return places, may_write


class OAuthConfig:
    def __init__(self, issuer: str, resource: str = "", audiences=None, mode: str = "auto",
                 client_id: str = "", secret_file: str = "", groups_file: str = "",
                 groups_claim: str = "groups", cache_ttl: int = 60, scopes=None, secret: str = "",
                 all_group: str = GROUP_ALL, write_group: str = GROUP_WRITE, place_prefix: str = GROUP_PLACE):
        self.issuer = issuer.rstrip("/")
        self.resource = resource
        self.audiences = [a for a in (audiences or []) if a]
        self.mode = mode
        self.client_id = client_id
        self.secret_file = secret_file
        self.groups_file = groups_file
        self.groups_claim = groups_claim
        self.cache_ttl = cache_ttl
        self.scopes = scopes or ["openid", "profile", "email", "groups", "offline_access"]
        self.secret = secret  # the introspection secret's VALUE, when given directly (else secret_file)
        self.all_group = all_group
        self.write_group = write_group
        self.place_prefix = place_prefix


class ResourceServer:
    """Validates bearer tokens for one issuer. Thread-safe; one instance per door."""

    def __init__(self, cfg: OAuthConfig, fetch=None):
        self.cfg = cfg
        self._fetch = fetch or _http
        self._lock = threading.Lock()
        self._cache: dict[str, tuple[float, object]] = {}
        self._discovery: tuple[float, dict] | None = None
        self._jwks: tuple[float, dict] | None = None
        self._jwks_refetched = 0.0

    # ── what the door publishes ─────────────────────────────────────────────────
    def metadata(self, resource: str) -> dict:
        return {
            "resource": resource,
            "authorization_servers": [self.cfg.issuer],
            "bearer_methods_supported": ["header"],
            "scopes_supported": self.cfg.scopes,
            "resource_name": "Gimlé",
        }

    @staticmethod
    def challenge(metadata_url: str, error: str = "", why: str = "") -> str:
        h = f'Bearer resource_metadata="{metadata_url}"'
        if error:
            safe = why.replace('"', "'").replace("\\", "/")[:200]
            h += f', error="{error}", error_description="{safe}"'
        return h

    def authorization_server_metadata(self) -> dict:
        """The issuer's own discovery document — served on the door for clients of the older spec."""
        return self.discovery()

    # ── the issuer ──────────────────────────────────────────────────────────────
    def discovery(self) -> dict:
        now = time.time()
        with self._lock:
            if self._discovery and self._discovery[0] > now:
                return self._discovery[1]
        doc = self._fetch("GET", self.cfg.issuer + "/.well-known/openid-configuration")
        if not isinstance(doc, dict) or not doc.get("issuer"):
            raise Refused("the issuer's discovery document did not answer")
        if doc["issuer"].rstrip("/") != self.cfg.issuer:
            raise Refused(f"the issuer names itself {doc['issuer']}, not {self.cfg.issuer}")
        with self._lock:
            self._discovery = (now + 3600, doc)
        return doc

    def _keys(self, force: bool = False) -> dict:
        now = time.time()
        with self._lock:
            if self._jwks and self._jwks[0] > now and not force:
                return self._jwks[1]
            if force and self._jwks and now - self._jwks_refetched < 30:
                return self._jwks[1]  # an unknown kid does not get to make us fetch on every call
            self._jwks_refetched = now
        uri = self.discovery().get("jwks_uri")
        if not uri:
            raise Refused("the issuer publishes no jwks_uri")
        doc = self._fetch("GET", uri)
        keys = {k.get("kid", ""): k for k in (doc or {}).get("keys", []) if k.get("kty") == "RSA"}
        with self._lock:
            self._jwks = (now + 300, keys)
        return keys

    def _secret(self) -> str:
        if self.cfg.secret:
            return self.cfg.secret
        if not self.cfg.secret_file:
            return ""
        try:
            with open(self.cfg.secret_file, encoding="utf-8") as fh:
                return fh.read().strip()
        except OSError:
            return ""

    # ── the three questions ─────────────────────────────────────────────────────
    @staticmethod
    def looks_like_jwt(token: str) -> bool:
        return token.count(".") == 2 and token.startswith("ey")

    def _verify_jwt(self, token: str) -> dict:
        try:
            h64, p64, s64 = token.split(".")
            header = json.loads(b64url_decode(h64))
            claims = json.loads(b64url_decode(p64))
            sig = b64url_decode(s64)
        except Exception:  # noqa: BLE001
            raise Refused("the token is not a well-formed JWT")
        alg = header.get("alg", "")
        if alg not in _DIGEST_INFO:
            raise Refused(f"the token is signed with {alg or 'nothing'}; the door accepts RS256/RS384/RS512")
        kid = header.get("kid", "")
        keys = self._keys()
        key = keys.get(kid) or (next(iter(keys.values())) if not kid and len(keys) == 1 else None)
        if key is None:
            keys = self._keys(force=True)
            key = keys.get(kid)
        if key is None:
            raise Refused("the token's signing key is not one the issuer publishes")
        n = int.from_bytes(b64url_decode(key["n"]), "big")
        e = int.from_bytes(b64url_decode(key["e"]), "big")
        if not rsa_verify(alg, n, e, f"{h64}.{p64}".encode(), sig):
            raise Refused("the token's signature does not verify")
        if str(claims.get("iss", "")).rstrip("/") != self.cfg.issuer:
            raise Refused(f"the token was issued by {claims.get('iss')!r}, not this door's issuer")
        now = time.time()
        if "exp" in claims and float(claims["exp"]) < now - 30:
            raise Refused("the token has expired")
        if "nbf" in claims and float(claims["nbf"]) > now + 30:
            raise Refused("the token is not valid yet")
        return claims

    def _introspect(self, token: str) -> dict:
        endpoint = self.discovery().get("introspection_endpoint")
        if not endpoint:
            raise Refused("the issuer offers no introspection endpoint")
        cid, secret = self.cfg.client_id, self._secret()
        if not (cid and secret):
            raise Refused("the door has no introspection credentials (--oauth-client-id and --oauth-secret-file)")
        basic = base64.b64encode(f"{urllib.parse.quote(cid)}:{urllib.parse.quote(secret)}".encode()).decode()
        doc = self._fetch("POST", endpoint, form={"token": token, "token_type_hint": "access_token"},
                          headers={"Authorization": f"Basic {basic}"})
        if not isinstance(doc, dict) or not doc.get("active"):
            raise Refused("the issuer says the token is not active")
        if "exp" in doc and float(doc["exp"]) < time.time() - 30:
            raise Refused("the token has expired")
        if doc.get("iss") and str(doc["iss"]).rstrip("/") != self.cfg.issuer:
            raise Refused(f"the token was issued by {doc['iss']!r}, not this door's issuer")
        return doc

    def _audience_ok(self, claims: dict) -> tuple[bool, str]:
        aud = claims.get("aud")
        auds = list(aud) if isinstance(aud, list) else ([aud] if aud else [])
        for extra in (claims.get("client_id"), claims.get("azp")):
            if extra:
                auds.append(extra)
        wanted = set(self.cfg.audiences)
        if self.cfg.resource:
            wanted.add(self.cfg.resource)
        if not wanted:
            return False, "the door names no audience (--oauth-audience), so it can accept no token"
        if wanted.intersection(str(a) for a in auds):
            return True, ""
        shown = ",".join(sorted({str(a) for a in auds})) or "nothing"
        return False, f"the token was issued to {shown}, not to this door"

    def _userinfo(self, token: str) -> dict:
        endpoint = self.discovery().get("userinfo_endpoint")
        if not endpoint:
            return {}
        try:
            doc = self._fetch("GET", endpoint, headers={"Authorization": f"Bearer {token}"})
        except urllib.error.HTTPError as exc:
            if exc.code in (401, 403):
                raise Refused("the issuer's userinfo refused the token")
            return {}
        except Exception:  # noqa: BLE001 — the token itself was verified; its own claims carry us
            return {}
        return doc if isinstance(doc, dict) else {}

    def _local_groups(self, keys) -> list[str]:
        if not self.cfg.groups_file:
            return []
        out: list[str] = []
        wanted = {str(k).lower() for k in keys if k}
        try:
            with open(self.cfg.groups_file, encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    who, _, rest = line.partition(" ")
                    if who.lower() in wanted:
                        out += [g.strip() for g in rest.split(",") if g.strip()]
        except OSError:
            pass
        return out

    def identify(self, token: str) -> dict:
        """token → {"subject", "sub", "groups", "places", "may_write", "client"} or raise Refused."""
        key = hashlib.sha256(token.encode()).hexdigest()
        now = time.time()
        with self._lock:
            hit = self._cache.get(key)
            if hit and hit[0] > now:
                if isinstance(hit[1], Refused):
                    raise hit[1]
                return hit[1]
        try:
            ident, exp = self._identify(token)
        except Refused as r:
            with self._lock:
                self._cache[key] = (now + 10, r)
            raise
        except Exception as exc:  # noqa: BLE001 — an issuer that cannot answer admits nobody
            raise Refused(f"the issuer could not be asked ({exc.__class__.__name__})")
        until = min(now + self.cfg.cache_ttl, exp) if exp else now + self.cfg.cache_ttl
        with self._lock:
            self._cache[key] = (until, ident)
            if len(self._cache) > 4096:
                for k in [k for k, v in self._cache.items() if v[0] <= now]:
                    self._cache.pop(k, None)
        return ident

    def _identify(self, token: str):
        mode = self.cfg.mode
        if mode == "jwt" or (mode == "auto" and self.looks_like_jwt(token)):
            claims = self._verify_jwt(token)
        elif mode in ("introspect", "auto"):
            claims = self._introspect(token)
        else:
            raise Refused(f"unknown --oauth-mode {mode}")
        named = claims.get("preferred_username") or claims.get("username") or claims.get("email") or claims.get("sub")
        ok, why = self._audience_ok(claims)
        if not ok:
            raise Refused(why, subject=str(named or ""))
        info = self._userinfo(token)
        merged = dict(claims)
        merged.update({k: v for k, v in info.items() if v not in (None, "")})
        subject = str(merged.get("preferred_username") or merged.get("email") or merged.get("sub") or "").strip()
        if not subject:
            raise Refused("the token names nobody (no preferred_username, email or sub)")
        groups = merged.get(self.cfg.groups_claim) or []
        if isinstance(groups, str):
            groups = [g for g in groups.split(",") if g.strip()]
        groups = list(groups) + self._local_groups([subject, merged.get("email"), merged.get("sub")])
        places, may_write = scope_from_groups(groups, self.cfg.all_group, self.cfg.write_group,
                                              self.cfg.place_prefix)
        aud = claims.get("aud")
        client = claims.get("client_id") or claims.get("azp") or (aud if isinstance(aud, str) else "")
        ident = {"subject": subject, "sub": str(merged.get("sub", "")), "groups": groups, "places": places,
                 "may_write": may_write, "client": str(client or "")}
        exp = float(claims["exp"]) if "exp" in claims else 0.0
        return ident, exp


class OAuth(ResourceServer):
    """The reviewer's shape of the same resource server — one class, the names his tested diff uses.

        OAuth(issuer, resource, introspect_client, introspect_secret, allowed_clients,
              write_group='gimle-write', place_prefix='gimle-place-', all_group='gimle-all', ttl=60)

    `allowed_clients` are the issuer's client ids whose tokens the door accepts; a token issued to any other
    client of the same issuer is refused. `introspect_secret` is the secret's value (the door reads it from
    /etc/gimle/oauth-introspect-secret). With an introspection client the mode is `auto` — a JWT is checked
    against the JWKS, anything else is introspected — so Dex and Authelia both fit.
    """

    def __init__(self, issuer: str, resource: str = "", introspect_client: str = "", introspect_secret: str = "",
                 allowed_clients=(), write_group: str = GROUP_WRITE, place_prefix: str = GROUP_PLACE,
                 all_group: str = GROUP_ALL, ttl: int = 60, mode: str = "auto", groups_file: str = "",
                 groups_claim: str = "groups", fetch=None):
        super().__init__(OAuthConfig(
            issuer=issuer, resource=resource, audiences=list(allowed_clients or []), mode=mode,
            client_id=introspect_client, secret=introspect_secret, groups_file=groups_file,
            groups_claim=groups_claim, cache_ttl=ttl, all_group=all_group, write_group=write_group,
            place_prefix=place_prefix), fetch=fetch)
        self.issuer = self.cfg.issuer
        self.resource = resource
        self.allowed_clients = self.cfg.audiences
        self.write_group, self.place_prefix, self.all_group, self.ttl = write_group, place_prefix, all_group, ttl


def _http(method: str, url: str, form=None, headers=None, timeout: float = 8.0):
    data = urllib.parse.urlencode(form).encode() if form is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=dict(headers or {}))
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/x-www-form-urlencoded")
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310 — the issuer URL is the operator's flag
        return json.loads(resp.read() or b"{}")


def public_origin(headers, fallback_host: str) -> str:
    """The origin a client used to reach the door (the tunnel sets X-Forwarded-*; loopback does not)."""
    proto = (headers.get("X-Forwarded-Proto") or "").split(",")[0].strip() or "http"
    host = (headers.get("X-Forwarded-Host") or headers.get("Host") or fallback_host).split(",")[0].strip()
    return f"{proto}://{host}"
