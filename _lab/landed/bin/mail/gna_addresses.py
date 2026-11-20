"""Gná's register: the addresses the house USES, and whether mail can reach them.

  addresses.sh                the register, TOON
  addresses.sh --check        exit nonzero when a declared address cannot receive
  gna_addresses.py honesty    the desk's honesty line, JSON (deliverable · forwarded · unreadable)
  gna_addresses.py probe --domain zerwiz.org --json
  gna_addresses.py await --account A --to ADDR [--since ISO] [--timeout 300]
  gna_addresses.py --self-test

THE LAW THIS FILE EXISTS FOR (plan 116 §15): on 2026-10-24 zerwiz.org published **no MX at
all**, so every @zerwiz.org address the house uses — gimle@, snotra@, reply+*, bounce+* — was
undeliverable, while five documents across the house assumed mail arrived. Nothing measured
it. A house address that cannot receive is reported `undeliverable` here; it is never
assumed good, and an address whose DNS could not be read is `unmeasured`, not `fine`.

Three facts per address, measured or declared, never guessed:
  mx       measured over DNS (a Null MX is a deliberate refusal, RFC 7505)
  route    DECLARED in hodd/memory/mail/accounts.yaml (routing lives in a dashboard, not in DNS)
  arrived  MEASURED — a proof line written by bin/mail/inbound-test.sh when a test message
           actually lands. Until one does, a routed address is `unproven`, not `deliverable`.

Rule 07: no hardcoded host. The resolver is $GNA_DNS_SERVER when set, else /etc/resolv.conf.
Rule 04: the register itself is the home's (accounts.yaml); this file only reads it.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import socket
import struct
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gna_store

ARRIVALS = gna_store.STATE_DIR / "mail" / "inbound-arrivals.jsonl"
ALIAS_CACHE = gna_store.STATE_DIR / "mail" / "alias-probe.json"

MX_TYPE = 15
ROUTES = ("explicit", "catch-all", "none")
ROLES = ("inbound", "outbound-only", "both")
# The ONLY place a DNS record type number is written down (Rule 07).
DNS_TIMEOUT = float(os.environ.get("GNA_DNS_TIMEOUT", "4"))


# --------------------------------------------------------------------------- the register


def registry() -> list[dict]:
    """The addresses the house uses, from the home's accounts.yaml `house:` block.

    A row is either a bare address (`- gimle@zerwiz.org`, the 2026-10-23 shape) or a
    mapping carrying what only a human can declare: its route and where it forwards.
    Both shapes are read, because an older home on another seat is still a valid home
    (Rule 25: probe, never assume the new shape arrived)."""
    doc = gna_store.document()
    rows: list[dict] = []
    seen: set[str] = set()
    for item in doc.get("house") or []:
        if isinstance(item, dict):
            address = str(item.get("address") or item.get("id") or "").strip().lower()
            route = str(item.get("route") or "none").strip().lower()
            forward_to = str(item.get("forward_to") or "").strip().lower()
            purpose = str(item.get("purpose") or "").strip()
            role = str(item.get("role") or "both").strip().lower()
            alias_of = str(item.get("alias_of") or "").strip().lower()
            acceptance = bool(item.get("acceptance"))
        else:
            address, route, forward_to, purpose = str(item).strip().lower(), "none", "", ""
            role, alias_of, acceptance = "both", "", False
        if not address or "@" not in address or address in seen:
            continue
        seen.add(address)
        rows.append({
            "address": address,
            "domain": address.rsplit("@", 1)[1].strip(),
            "route": route if route in ROUTES else "none",
            "forward_to": forward_to,
            "purpose": purpose,
            "role": role if role in ROLES else "both",
            "alias_of": alias_of,
            "acceptance": acceptance,
            "wildcard": "*" in address or address.split("@", 1)[0].startswith(("reply+", "bounce+")),
        })
    return rows


def expected(domain: str) -> dict:
    """What the home declares a domain SHOULD publish, so a skip can name what is missing."""
    doc = gna_store.document()
    block = (doc.get("domains") or {}).get(domain)
    return block if isinstance(block, dict) else {}


def readable_accounts() -> dict[str, dict]:
    """Accounts the desk can actually read — one transport each (a Google grant or IMAP)."""
    out: dict[str, dict] = {}
    for key, row in gna_store.declared_accounts().items():
        if not isinstance(row, dict):
            continue
        transport = str(row.get("transport") or "google").strip().lower()
        known = transport in ("google", "gmail") or (transport == "imap" and bool(row.get("imap")))
        out[key] = {"transport": transport, "readable": known, "status": str(row.get("status") or "")}
    return out


def arrivals() -> dict[str, dict]:
    """The latest PROVEN arrival per address. An unwritten ledger is an empty proof, not a pass."""
    latest: dict[str, dict] = {}
    try:
        lines = ARRIVALS.read_text(encoding="utf-8").splitlines()
    except OSError:
        return latest
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if row.get("result") != "arrived":
            continue
        key = str(row.get("to") or "").lower()
        if key:
            latest[key] = row
    return latest


def append_arrival(proof: dict) -> str:
    ARRIVALS.parent.mkdir(parents=True, exist_ok=True)
    proof = dict(proof)
    proof.setdefault("at", now_iso())
    proof.setdefault("result", "arrived")
    with ARRIVALS.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(proof, ensure_ascii=False) + "\n")
    return str(ARRIVALS)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


# --------------------------------------------------------------------------- DNS, by hand


def _nameservers() -> list[tuple[str, int]]:
    override = os.environ.get("GNA_DNS_SERVER", "").strip()
    if override:
        return [_host_port(override, 53)]
    if os.environ.get("GNA_DNS_OFFLINE", "").strip():
        return []
    servers: list[tuple[str, int]] = []
    try:
        text = Path("/etc/resolv.conf").read_text(encoding="utf-8")
    except OSError:
        text = ""
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] == "nameserver":
            servers.append(_host_port(parts[1], 53))
    return servers


def _host_port(value: str, default_port: int) -> tuple[str, int]:
    host, _, port = value.partition(":")
    try:
        return host.strip("[]"), int(port) if port else default_port
    except ValueError:
        return host, default_port


def _encode_name(name: str) -> bytes:
    out = b""
    for label in name.strip(".").split("."):
        if not label:
            continue
        out += bytes([len(label)]) + label.encode("idna") if label.isascii() else bytes([len(label)]) + label.encode()
    return out + b"\x00"


def _read_name(buf: bytes, offset: int) -> tuple[str, int]:
    labels: list[str] = []
    jumped = False
    end = offset
    hops = 0
    while True:
        if offset >= len(buf):
            raise ValueError("dns: name runs past the packet")
        length = buf[offset]
        if length & 0xC0 == 0xC0:
            if offset + 1 >= len(buf):
                raise ValueError("dns: truncated pointer")
            pointer = ((length & 0x3F) << 8) | buf[offset + 1]
            if not jumped:
                end = offset + 2
                jumped = True
            hops += 1
            if hops > 16:
                raise ValueError("dns: compression loop")
            offset = pointer
            continue
        if length == 0:
            if not jumped:
                end = offset + 1
            break
        labels.append(buf[offset + 1: offset + 1 + length].decode("utf-8", "replace"))
        offset += 1 + length
    return ".".join(labels), end


def _query(domain: str, qtype: int, server: tuple[str, int]) -> tuple[int, list]:
    """One UDP query, no libraries. Returns (rcode, answers)."""
    ident = random.randrange(0, 0xFFFF)
    packet = struct.pack(">HHHHHH", ident, 0x0100, 1, 0, 0, 0) + _encode_name(domain) + struct.pack(">HH", qtype, 1)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(DNS_TIMEOUT)
    try:
        sock.sendto(packet, server)
        buf, _ = sock.recvfrom(4096)
    finally:
        sock.close()
    if len(buf) < 12:
        raise ValueError("dns: short answer")
    rid, flags, qdcount, ancount, _, _ = struct.unpack(">HHHHHH", buf[:12])
    if rid != ident:
        raise ValueError("dns: answer id does not match the question")
    rcode = flags & 0x000F
    offset = 12
    for _ in range(qdcount):
        _, offset = _read_name(buf, offset)
        offset += 4
    answers: list = []
    for _ in range(ancount):
        _, offset = _read_name(buf, offset)
        if offset + 10 > len(buf):
            break
        rtype, rclass, _ttl, rdlength = struct.unpack(">HHIH", buf[offset: offset + 10])
        offset += 10
        rdata = buf[offset: offset + rdlength]
        offset += rdlength
        if rclass != 1:
            continue
        if rtype == MX_TYPE and len(rdata) >= 3:
            preference = struct.unpack(">H", rdata[:2])[0]
            exchange, _ = _read_name(buf, offset - rdlength + 2)
            answers.append((preference, exchange))
        elif rtype == qtype and qtype == 1 and len(rdata) == 4:
            answers.append(".".join(str(b) for b in rdata))
    return rcode, answers


def mx_state(domain: str) -> dict:
    """Does the domain publish MX? present · absent · null · unmeasured."""
    if not domain:
        return {"state": "absent", "mx": [], "note": "no domain in the address"}
    servers = _nameservers()
    if not servers:
        return {"state": "unmeasured", "mx": [], "note": "no resolver to ask (GNA_DNS_OFFLINE is set)"}
    errors: list[str] = []
    for server in servers:
        try:
            rcode, answers = _query(domain, MX_TYPE, server)
        except (OSError, ValueError) as exc:
            errors.append(f"{server[0]}:{server[1]} {exc}")
            continue
        if rcode == 0:
            if not answers:
                return {"state": "absent", "mx": [],
                        "note": f"{domain} publishes no MX record — nothing can be delivered to it"}
            if all(pref == 0 and host in ("", ".") for pref, host in answers):
                return {"state": "null", "mx": ["0 ."],
                        "note": f"{domain} publishes a Null MX (RFC 7505) — it refuses all mail"}
            hosts = sorted({host.lower() for _, host in answers})
            return {"state": "present", "mx": [f"{p} {h}" for p, h in sorted(answers)], "hosts": hosts}
        if rcode == 3:
            return {"state": "absent", "mx": [], "note": f"{domain} does not exist (NXDOMAIN)"}
        errors.append(f"{server[0]}:{server[1]} rcode {rcode}")
    return {"state": "unmeasured", "mx": [], "error": "; ".join(errors) or "no answer"}


# --------------------------------------------------------------------------- alias proof


def alias_cache(fresh: bool = False) -> dict:
    """The cached measurement of which Workspace aliases exist on the readable account.

    Measured through the account's own `sendAs` settings — READ ONLY, no message is sent
    and no address is added. §16 corrects §15: way-of.com already receives mail, so the
    inbound answer for a house identity is an ALIAS on the account we can read; whether
    that alias exists is a fact, and an unmeasured alias is not an existing one."""
    try:
        cached = json.loads(ALIAS_CACHE.read_text(encoding="utf-8"))
        if isinstance(cached, dict):
            declared = {r["address"] for r in registry() if r["alias_of"]}
            covered = set((cached.get("results") or {}).keys())
            # A cache that does not cover every declared alias is STALE, not empty:
            # an address added since the last probe would otherwise read as unmeasured.
            if not fresh and cached.get("results") is not None and not (declared - covered):
                return cached
    except (OSError, ValueError):
        pass
    results: dict[str, dict] = {}
    targets: dict[str, list[str]] = {}
    for row in registry():
        if row["alias_of"]:
            targets.setdefault(row["alias_of"], []).append(row["address"])
    for owner, wanted in targets.items():
        state, present, detail = probe_sendas(owner)
        for address in wanted:
            if state != "present":
                results[address] = {"state": state, "detail": detail, "owner": owner}
            elif address in present:
                results[address] = {"state": "present", "detail": f"listed in {owner}'s sendAs settings", "owner": owner}
            else:
                results[address] = {
                    "state": "missing", "owner": owner,
                    "detail": f"{owner} can send as {', '.join(sorted(present)) or 'nothing else'} — "
                              f"add {address} as an alias in the Workspace console (Directory > Users > "
                              f"{owner.split('@')[0]} > Aliases), then re-run bin/mail/addresses.sh --check",
                }
    cache = {"at": now_iso(), "results": results}
    try:
        ALIAS_CACHE.parent.mkdir(parents=True, exist_ok=True)
        ALIAS_CACHE.write_text(json.dumps(cache, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    except OSError:
        pass  # a cache that cannot be written still answers this run
    return cache


def probe_sendas(owner: str) -> tuple[str, set[str], str]:
    """(state, addresses the account may send as, detail). Read-only settings call."""
    import gna_import

    row = gna_store.declared_accounts().get(owner)
    if not row:
        return "unmeasured", set(), f"{owner} is not a declared account, so no grant can list its aliases"
    transport = str(row.get("transport") or "google").strip().lower()
    if transport not in ("google", "gmail"):
        return "unmeasured", set(), f"{owner} is read over {transport}; its aliases cannot be listed here"
    try:
        token = gna_import.token_for(row)
        answer = gna_import.api(token, "/users/me/settings/sendAs")
    except SystemExit as exc:
        return "unmeasured", set(), str(exc)
    except Exception as exc:  # a probe that fails is reported, never rendered as "no alias"
        return "unmeasured", set(), f"{type(exc).__name__}: {exc}"
    present = {str(a.get("sendAsEmail") or "").strip().lower() for a in answer.get("sendAs") or []}
    present.discard("")
    if not present:
        return "unmeasured", set(), "the account listed no sendAs address at all"
    return "present", present, "settings listed"


# --------------------------------------------------------------------------- the verdict


def register(fresh_aliases: bool = False) -> list[dict]:
    """One row per declared address: what is measured, what is declared, what that means."""
    proven = arrivals()
    readable = readable_accounts()
    aliases = alias_cache(fresh=fresh_aliases).get("results") or {}
    cache: dict[str, dict] = {}
    rows: list[dict] = []
    for item in registry():
        domain = item["domain"]
        if domain not in cache:
            cache[domain] = mx_state(domain)
        mx = cache[domain]
        arrival = proven.get(item["address"])
        alias = aliases.get(item["address"]) or {}
        row = dict(item)
        row["mx"] = mx["state"]
        row["mx_records"] = mx.get("mx", [])
        row["alias"] = str(alias.get("state") or "")
        row["arrived"] = (arrival or {}).get("at") or ""
        row["forwarded_to"] = item["forward_to"] or "nowhere"
        row["unreadable"] = not _is_readable(item["forward_to"], readable)
        row.update(_verdict(item, mx, arrival, alias))
        rows.append(row)
    return rows


def _is_readable(address: str, readable: dict[str, dict]) -> bool:
    if not address:
        return False
    row = readable.get(address.lower())
    return bool(row and row.get("readable"))


def _inbound_twin(item: dict) -> str:
    """Where a sender-only address's mail actually lands, when the registry names it."""
    local = item["address"].split("@", 1)[0]
    for row in registry():
        if row["address"] == item["address"]:
            continue
        if row["role"] in ("inbound", "both") and row["address"].split("@", 1)[0].split("+", 1)[0] == local.split("+", 1)[0]:
            return row["address"]
    return ""


def _verdict(item: dict, mx: dict, arrival: dict | None, alias: dict) -> dict:
    if mx["state"] == "unmeasured":
        return {"deliverable": "no", "state": "unmeasured",
                "reason": "the DNS could not be read — unmeasured is never assumed good: "
                          + str(mx.get("error") or mx.get("note") or "")}
    if mx["state"] in ("absent", "null"):
        if item["role"] == "outbound-only":
            twin = _inbound_twin(item)
            where = f"; inbound arrives at {twin}" if twin else "; no inbound twin is declared"
            return {"deliverable": "no", "state": "outbound-only",
                    "reason": f"{item['domain']} publishes no MX — this address can SEND and cannot receive, "
                              "which is the declared design (plan 116 §16)" + where}
        return {"deliverable": "no", "state": "undeliverable",
                "reason": mx.get("note") or f"no MX for {item['domain']}"}
    if item["alias_of"]:
        state = str(alias.get("state") or "unmeasured")
        if state == "unmeasured":
            return {"deliverable": "no", "state": "unmeasured",
                    "reason": "the Workspace alias could not be measured: "
                              + str(alias.get("detail") or "no grant could list sendAs")}
        if state != "present":
            return {"deliverable": "no", "state": "undeliverable",
                    "reason": "alias-missing — " + str(alias.get("detail") or "the alias is not on the account")}
    if item["route"] == "none":
        return {"deliverable": "no", "state": "undeliverable",
                "reason": f"{item['domain']} publishes MX but the registry declares route 'none' — "
                          "no explicit row and no catch-all, so nothing is forwarded"}
    if arrival:
        return {"deliverable": "yes", "state": "deliverable",
                "reason": f"MX present · route {item['route']} · a test message arrived {arrival.get('at')}"}
    return {"deliverable": "unproven", "state": "unproven",
            "reason": f"MX present · route {item['route']} · no test message has arrived yet, "
                      "so this is declared, not proven (bin/mail/inbound-test.sh proves it)"}


# --------------------------------------------------------------------------- the acceptance plan


def plan(target: str, sender: str = "", allow_same_domain: bool = False) -> dict:
    """Can a test message from OUTSIDE reach this address — and if not, what is missing?

    This is the decision the acceptance test (`bin/mail/inbound-test.sh`) makes before it
    sends anything: a test that sends into a dead domain proves nothing and looks like a
    pass, so the door ASKS first and skips with a reason. Exit contract: 0 ready, 3 skip."""
    rows = {row["address"]: row for row in register()}
    if not target:
        accepted = [row for row in rows.values() if row["acceptance"]]
        chosen = accepted[0] if accepted else next(
            (row for row in rows.values() if row["role"] in ("inbound", "both")), None)
        if not chosen:
            return {"verdict": "skip", "reason": "not-declared",
                    "detail": "the register declares no inbound address — nothing to mail",
                    "target": "", "missing": []}
        target = chosen["address"]
    row = rows.get(target)
    if not row:
        return {"verdict": "skip", "reason": "not-declared", "target": target,
                "detail": f"{target} is not declared in the home's accounts.yaml, so the house does not "
                          "promise to receive it — declare it before testing it",
                "missing": []}
    domain = row["domain"]
    mx = mx_state(domain)
    declared = expected(domain)
    sender = sender or row["forward_to"] if row["forward_to"] != "nowhere" else sender
    base = {
        "target": target,
        "domain": domain,
        "mx": mx,
        "expected": declared,
        "route": row["route"],
        "alias": row["alias"],
        "sender": sender,
        "missing": [],
    }
    if mx["state"] == "unmeasured":
        base.update(verdict="skip", reason="unmeasured",
                    detail=f"the DNS could not be read: {mx.get('error') or mx.get('note')}")
        return base
    if mx["state"] in ("absent", "null"):
        missing = list(declared.get("expect_mx") or [])
        twin = _inbound_twin(row)
        base.update(verdict="skip", reason="no-mx" if mx["state"] == "absent" else "null-mx",
                    detail=(f"{domain} publishes no MX record, so NOTHING sent to {target} can arrive"
                            if mx["state"] == "absent" else
                            f"{domain} publishes a Null MX and refuses all mail") +
                           (f"; the declared inbound twin is {twin}" if twin else ""),
                    missing=missing)
        return base
    if row["alias_of"]:
        state = str(row["alias"] or "unmeasured")
        if state == "missing":
            base.update(verdict="skip", reason="alias-missing", missing=[f"alias {target} on {row['alias_of']}"],
                        detail=f"alias-missing — add {target} in the Workspace console "
                               f"(Directory > Users > {row['alias_of'].split('@')[0]} > Aliases)")
            return base
        if state == "unmeasured":
            base.update(verdict="skip", reason="alias-unmeasured",
                        detail=f"the alias could not be measured (bin/mail/addresses.sh --aliases): {target}")
            return base
    if row["route"] == "none":
        base.update(verdict="skip", reason="not-routed",
                    detail=f"{domain} publishes MX but the registry declares no route for {target}",
                    missing=[f"a routing row for {target}"])
        return base
    if not sender:
        base.update(verdict="skip", reason="no-sender",
                    detail="no readable account to send from — declare one, or pass --from",
                    missing=["a declared account with a grant or an imap block"])
        return base
    accounts = gna_store.declared_accounts()
    sender_key = sender.strip().lower()
    if sender_key not in accounts:
        base.update(verdict="skip", reason="sender-not-declared",
                    detail=f"{sender} is not a declared account, so the house cannot send from it",
                    missing=[f"a grant or imap block for {sender}"])
        return base
    if sender_key.rsplit("@", 1)[-1] == domain and not allow_same_domain:
        base.update(verdict="skip", reason="not-outside",
                    detail=f"{sender} is on {domain} — a message from inside the domain proves nothing "
                           "about mail from outside it; pass --from an address on another domain, or "
                           "--allow-same-domain to prove only that the address routes into the inbox",
                    missing=[])
        return base
    transport = transport_of_account(sender_key)
    same_domain = sender_key.rsplit("@", 1)[-1] == domain
    base.update(verdict="ready", reason="ready", detail=(
        f"MX present on {domain} · route {row['route']} · alias {row['alias'] or 'not needed'} · "
        f"sender {sender} read over {transport}"
        + (" — SAME DOMAIN: this proves the address routes into the inbox, not that outside mail "
           "reaches it" if same_domain else " — sender is on another domain, so this is an outside send")),
        same_domain=same_domain, missing=[])
    return base


def transport_of_account(account: str) -> str:
    row = gna_store.declared_accounts().get(account) or {}
    return str(row.get("transport") or "google").strip().lower()


def toon_plan(doc: dict) -> str:
    """The skip-with-reason a human reads: exactly what is missing, never a pass."""
    lines = [f"plan[1]{{target,domain,mx,route,alias,sender,verdict,reason}}:"]
    values = (doc.get("target"), doc.get("domain"), (doc.get("mx") or {}).get("state"),
              doc.get("route"), doc.get("alias") or "not needed", doc.get("sender"),
              doc.get("verdict"), doc.get("reason"))
    lines.append("  " + ",".join(_q(value) for value in values))
    if doc["verdict"] != "ready":
        lines.append(f"skip[1]{{reason,detail}}:")
        lines.append("  " + ",".join(_q(doc.get("reason")) for _ in (0,)) + "," + _q(doc.get("detail")))
        missing = doc.get("missing") or []
        if missing:
            lines.append(f"missing[{len(missing)}]{{record}}:")
            for item in missing:
                lines.append("  " + _q(item))
        lines.append("result: SKIP — this is exit 3, never a pass")
        lines.append("help: plan 116 §15.2 (Cloudflare routing) and §16 (Workspace aliases) hold the values")
    else:
        lines.append("result: READY — the door will send from outside and wait for the arrival proof")
    return "\n".join(lines)


# --------------------------------------------------------------------------- honesty for the desk


def honesty() -> dict:
    """The desk's line, per address: deliverable · forwarded · unreadable.

    The desk renders this beside an empty queue so a reader can tell "no mail" from
    "no mail could have arrived, and nobody could have read it if it had" (plan 116
    §15.3.3)."""
    rows = register()
    lines = []
    for row in rows:
        deliverable = {"yes": "deliverable", "unproven": "declared", "no": "undeliverable"}.get(
            row["deliverable"], "undeliverable")
        if row["state"] == "outbound-only":
            deliverable = "outbound-only"
        elif row["state"] == "unmeasured":
            deliverable = "unmeasured"
        lines.append({
            "address": row["address"],
            "domain": row["domain"],
            "role": row["role"],
            "deliverable": deliverable,
            "forwarded": row["forwarded_to"],
            "unreadable": "yes" if row["unreadable"] else "no",
            "readable": not row["unreadable"],
            "arrived": row["arrived"],
            "route": row["route"],
            "mx": row["mx"],
            "alias": row["alias"],
            "acceptance": row["acceptance"],
            "reason": row["reason"],
        })
    counts: dict[str, int] = {}
    for line in lines:
        counts[line["deliverable"]] = counts.get(line["deliverable"], 0) + 1
    return {"addresses": lines, "counts": counts, "measured_at": now_iso(),
            "ledger": str(ARRIVALS), "ledger_exists": ARRIVALS.exists()}


# --------------------------------------------------------------------------- TOON


def _q(value) -> str:
    return '"' + str(value).replace('"', "'").replace("\n", " ") + '"'


def toon(rows: list[dict]) -> str:
    out = [f"addresses[{len(rows)}]{{address,domain,role,mx,alias,route,forwarded_to,arrived,deliverable,state,reason}}:"]
    for row in rows:
        out.append("  " + ",".join(_q(row[k]) for k in (
            "address", "domain", "role", "mx", "alias", "route", "forwarded_to", "arrived",
            "deliverable", "state", "reason")))
    return "\n".join(out)


def toon_honesty(doc: dict) -> str:
    lines = doc["addresses"]
    out = [f"honesty[{len(lines)}]{{address,deliverable,forwarded,unreadable,arrived}}:"]
    for line in lines:
        out.append("  " + ",".join(_q(line[k]) for k in (
            "address", "deliverable", "forwarded", "unreadable", "arrived")))
    out.append("counts{deliverable,declared,outbound_only,unmeasured,undeliverable}:")
    out.append("  " + ",".join(_q(doc["counts"].get(k, 0)) for k in
                               ("deliverable", "declared", "outbound-only", "unmeasured", "undeliverable")))
    return "\n".join(out)


# --------------------------------------------------------------------------- arrival proof


def await_arrival(account: str, to_address: str, since: str = "", timeout: float = 300.0,
                  poll: float = 10.0) -> dict:
    """Poll the readable account until a message addressed to `to_address` arrives.

    The To: header is returned VERBATIM: the acceptance question is not only "did it
    arrive" but "did it arrive still addressed to the address we used" (§15.3.4)."""
    import gna_import  # imported here: the readers live with the importer, not here

    deadline = time.monotonic() + max(timeout, 0.0)
    last_error = ""
    while True:
        try:
            found = gna_import.search_address(account, to_address, days=2)
        except SystemExit as exc:
            last_error = str(exc)
            found = []
        except Exception as exc:  # a reader that fails is reported, never rendered as "no mail"
            last_error = f"{type(exc).__name__}: {exc}"
            found = []
        for record in found:
            to_header = _to_header(record)
            if to_address.lower() not in to_header.lower():
                continue
            received = record.get("received_at") or ""
            if since and received and received < since:
                continue
            proof = {
                "to": to_address.lower(),
                "to_header": to_header,
                "from": (record.get("from") or {}).get("email", ""),
                "account": account,
                "message_id": record.get("id"),
                "subject": record.get("subject"),
                "received_at": received,
                "via": "inbound-test",
            }
            proof["result"] = "arrived"
            proof["ledger"] = append_arrival(proof)
            return proof
        if time.monotonic() >= deadline:
            return {"result": "timeout", "to": to_address.lower(), "account": account,
                    "waited_seconds": timeout, "last_error": last_error}
        time.sleep(min(poll, max(0.0, deadline - time.monotonic())))


def _to_header(record: dict) -> str:
    if record.get("to_header"):
        return str(record["to_header"])
    parts = []
    for entry in record.get("to") or []:
        name, email = (entry.get("name") or ""), (entry.get("email") or "")
        parts.append(f"{name} <{email}>" if name else email)
    return ", ".join(parts)


# --------------------------------------------------------------------------- self-test


def self_test() -> int:
    """Prove the parser and the verdicts offline, with a fixture resolver on loopback.

    Nothing here touches the network: the fixture answers MX for one zone, NXDOMAIN for
    another, a Null MX for a third, and nothing at all for a fourth."""
    import threading

    zone = {
        b"good.example": [(10, "mx1.good.example")],
        b"null.example": [(0, "")],
        b"lone.example": [(5, "mx.lone.example")],
    }

    class Fixture(threading.Thread):
        daemon = True

        def __init__(self) -> None:
            super().__init__()
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.sock.bind(("127.0.0.1", 0))
            self.sock.settimeout(0.3)
            self.stop = False
            self.port = self.sock.getsockname()[1]

        def run(self) -> None:
            while not self.stop:
                try:
                    packet, peer = self.sock.recvfrom(2048)
                except socket.timeout:
                    continue
                except OSError:
                    return
                ident = packet[:2]
                name, _ = _read_name(packet, 12)
                answers = zone.get(name.encode())
                flags = 0x8180
                count = len(answers or [])
                if answers is None:
                    name_in_zone = any(name.encode().endswith(k) for k in zone)
                    flags = 0x8180 if name_in_zone else 0x8183
                    count = 0
                body = struct.pack(">HHHHHH", struct.unpack(">H", ident)[0], flags, 1, count, 0, 0)
                body += _encode_name(name) + struct.pack(">HH", MX_TYPE, 1)
                for pref, host in answers or []:
                    rdata = struct.pack(">H", pref) + (_encode_name(host) if host else b"\x00")
                    body += b"\xc0\x0c" + struct.pack(">HHIH", MX_TYPE, 1, 60, len(rdata)) + rdata
                self.sock.sendto(body, peer)

    fixture = Fixture()
    fixture.start()
    checks: list[tuple[str, bool, str]] = []
    saved = {k: os.environ.get(k) for k in ("GNA_DNS_SERVER", "GNA_DNS_OFFLINE", "YMIR_HOME")}
    try:
        os.environ["GNA_DNS_SERVER"] = f"127.0.0.1:{fixture.port}"
        os.environ.pop("GNA_DNS_OFFLINE", None)
        mx = mx_state("good.example")
        checks.append(("a published MX is present", mx["state"] == "present", str(mx)))
        mx = mx_state("nothing.example")
        checks.append(("a domain with no MX is absent", mx["state"] == "absent", str(mx)))
        mx = mx_state("null.example")
        checks.append(("a Null MX is a refusal, not deliverability", mx["state"] == "null", str(mx)))

        tmp = Path(os.environ.get("TMPDIR", "/tmp")) / f"gna-addresses-selftest-{os.getpid()}"
        (tmp / "hodd/memory/mail").mkdir(parents=True, exist_ok=True)
        (tmp / "hodd/state/mail").mkdir(parents=True, exist_ok=True)
        (tmp / "hodd/memory/mail/accounts.yaml").write_text(
            "accounts:\n  - id: reader@good.example\n    status: scoped\n"
            "house:\n  - address: gimle@nothing.example\n    route: catch-all\n    forward_to: reader@good.example\n"
            "  - address: snotra@good.example\n    route: none\n"
            "  - address: reply+*@good.example\n    route: explicit\n    forward_to: reader@good.example\n"
            "  - address: sender@nothing.example\n    role: outbound-only\n    route: none\n"
            "  - address: alias@good.example\n    role: inbound\n    route: explicit\n"
            "    forward_to: reader@good.example\n    alias_of: reader@good.example\n",
            encoding="utf-8",
        )
        (tmp / "hodd/state/mail/alias-probe.json").write_text(
            json.dumps({"at": now_iso(), "results": {"alias@good.example": {
                "state": "missing", "owner": "reader@good.example",
                "detail": "reader@good.example can send as reader@good.example"}}}),
            encoding="utf-8",
        )
        os.environ["YMIR_HOME"] = str(tmp)
        gna_store.HOME = tmp
        gna_store.MAIL_DIR = tmp / "hodd" / "memory" / "mail"
        gna_store.ACCOUNTS = gna_store.MAIL_DIR / "accounts.yaml"
        gna_store.STATE_DIR = tmp / "hodd" / "state"
        globals()["ARRIVALS"] = gna_store.STATE_DIR / "mail" / "inbound-arrivals.jsonl"
        globals()["ALIAS_CACHE"] = gna_store.STATE_DIR / "mail" / "alias-probe.json"
        rows = {r["address"]: r for r in register()}
        checks.append(("no MX means undeliverable", rows["gimle@nothing.example"]["state"] == "undeliverable",
                       rows["gimle@nothing.example"]["reason"]))
        checks.append(("MX with route none is undeliverable", rows["snotra@good.example"]["deliverable"] == "no",
                       rows["snotra@good.example"]["reason"]))
        checks.append(("MX and a route, unproven, is never called deliverable",
                       rows["reply+*@good.example"]["deliverable"] == "unproven",
                       rows["reply+*@good.example"]["reason"]))
        checks.append(("a declared sender-only address is outbound-only, not undeliverable",
                       rows["sender@nothing.example"]["state"] == "outbound-only",
                       rows["sender@nothing.example"]["reason"]))
        checks.append(("a missing Workspace alias is undeliverable, not unproven",
                       rows["alias@good.example"]["state"] == "undeliverable"
                       and "alias-missing" in rows["alias@good.example"]["reason"],
                       rows["alias@good.example"]["reason"]))
        append_arrival({"to": "reply+*@good.example", "to_header": "reply+7@good.example", "account": "reader@good.example"})
        rows = {r["address"]: r for r in register()}
        checks.append(("a proven arrival makes it deliverable",
                       rows["reply+*@good.example"]["deliverable"] == "yes",
                       rows["reply+*@good.example"]["reason"]))
        os.environ.pop("GNA_DNS_SERVER", None)
        os.environ["GNA_DNS_OFFLINE"] = "1"
        mx = mx_state("good.example")
        checks.append(("no resolver is unmeasured, never good", mx["state"] == "unmeasured", str(mx)))
        for path in sorted(tmp.rglob("*"), reverse=True):
            if path.is_file():
                path.unlink()
            elif path.is_dir():
                path.rmdir()
    finally:
        fixture.stop = True
        fixture.sock.close()
        for key, value in saved.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
    failures = [name for name, ok, _ in checks if not ok]
    for name, ok, detail in checks:
        print(f"{'PASS' if ok else 'FAIL'}  {name}")
        if not ok:
            print(f"      {detail}")
    print(f"self-test: {len(checks) - len(failures)}/{len(checks)} passed")
    return 1 if failures else 0


# --------------------------------------------------------------------------- CLI


def main() -> int:
    ap = argparse.ArgumentParser(description="Gná's register of the addresses the house uses")
    ap.add_argument("action", nargs="?", default="list",
                    choices=["list", "check", "honesty", "probe", "mx", "await", "aliases", "plan"])
    ap.add_argument("--check", action="store_true", dest="check_flag")
    ap.add_argument("--fresh", action="store_true",
                    help="re-measure the Workspace aliases instead of reading the cache")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--domain")
    ap.add_argument("--mx-action", dest="mx_action", action="store_true")
    ap.add_argument("--account")
    ap.add_argument("--sender", default="")
    ap.add_argument("--allow-same-domain", action="store_true")
    ap.add_argument("--to")
    ap.add_argument("--since", default="")
    ap.add_argument("--timeout", type=float, default=300.0)
    ap.add_argument("--poll", type=float, default=10.0)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if args.action == "mx":
        # One domain's mail exchanger, for a door that is about to send to it. The send path asks
        # this before a letter leaves: a domain with no MX is a letter lost, not sent (2026-11-01).
        if not args.domain:
            print("mx needs --domain", file=sys.stderr)
            return 2
        mx = mx_state(args.domain)
        if args.json:
            print(json.dumps(mx, indent=1, ensure_ascii=False))
        else:
            hosts = ", ".join(mx.get("mx") or []) or mx.get("note", "")
            print(f"{mx['state']} — {args.domain}: {hosts}")
        return 0 if mx["state"] == "present" else 1

    if args.action == "probe":
        if not args.domain:
            print("probe needs --domain", file=sys.stderr)
            return 2
        mx = mx_state(args.domain)
        mx["expected"] = expected(args.domain)
        print(json.dumps(mx, indent=1, ensure_ascii=False) if args.json else
              f"probe[1]{{domain,state,mx}}:\n  {_q(args.domain)},{_q(mx['state'])},{_q(', '.join(mx.get('mx') or []))}")
        return 0 if mx["state"] != "unmeasured" else 4

    if args.action == "aliases":
        cache = alias_cache(fresh=True)
        results = cache.get("results") or {}
        if args.json:
            print(json.dumps(cache, indent=1, ensure_ascii=False))
        else:
            print(f"aliases[{len(results)}]{{address,state,owner,detail}}:")
            for address, row in sorted(results.items()):
                print(f"  {_q(address)},{_q(row.get('state'))},{_q(row.get('owner'))},{_q(row.get('detail'))}")
            if not results:
                print("  \"—\",\"none\",\"—\",\"the register declares no Workspace alias\"")
        return 0 if all(r.get("state") == "present" for r in results.values()) else 3

    if args.action == "plan":
        doc = plan(args.to or "", sender=args.sender, allow_same_domain=args.allow_same_domain)
        if args.json:
            print(json.dumps(doc, indent=1, ensure_ascii=False))
        else:
            print(toon_plan(doc))
        return 0 if doc["verdict"] == "ready" else 3

    if args.action == "await":
        if not (args.account and args.to):
            print("await needs --account and --to", file=sys.stderr)
            return 2
        proof = await_arrival(args.account, args.to, since=args.since, timeout=args.timeout, poll=args.poll)
        print(json.dumps(proof, indent=1, ensure_ascii=False))
        return 0 if proof.get("result") == "arrived" else 4

    try:
        if not gna_store.ACCOUNTS.exists():
            print(f"register[1]{{state,detail}}:\n  \"unreadable\",{_q('no ' + str(gna_store.ACCOUNTS))}")
            return 2
        rows = register(fresh_aliases=args.fresh or args.action == "check")
    except SystemExit as exc:
        print(f"register[1]{{state,detail}}:\n  \"unreadable\",{_q(exc)}")
        return 2

    if args.action == "honesty":
        doc = honesty()
        print(json.dumps(doc, indent=1, ensure_ascii=False) if args.json else toon_honesty(doc))
        return 0

    if not rows:
        print("addresses[0]{address}:\n")
        print("register: the house declares no address — an empty register cannot prove deliverability")
        return 2

    if args.json:
        print(json.dumps(rows, indent=1, ensure_ascii=False))
        if args.action == "check" or args.check_flag:
            return 1 if any(r["state"] in ("undeliverable", "unmeasured") for r in rows) else 0
        return 0

    print(toon(rows))
    if args.action == "check" or args.check_flag:
        undeliverable = [r for r in rows if r["state"] == "undeliverable"]
        unmeasured = [r for r in rows if r["state"] == "unmeasured"]
        unproven = [r for r in rows if r["state"] == "unproven"]
        outbound_only = [r for r in rows if r["state"] == "outbound-only"]
        if undeliverable:
            print(f"check[1]{{result,undeliverable,unproven,outbound_only}}:\n  "
                  f"\"FAIL\",{_q(len(undeliverable))},{_q(len(unproven))},{_q(len(outbound_only))}")
            for row in undeliverable:
                print(f"  undeliverable  {row['address']} — {row['reason']}")
            print("help: bin/mail/inbound-test.sh names the record that is missing; plan 116 §15.2 and §16 hold the values")
            return 1
        if unmeasured:
            print(f"check[1]{{result,unmeasured}}:\n  \"FAIL\",{_q(len(unmeasured))}")
            for row in unmeasured:
                print(f"  unmeasured     {row['address']} — {row['reason']}")
            return 1
        if unproven:
            print(f"check[1]{{result,unproven,outbound_only}}:\n  \"UNPROVEN\",{_q(len(unproven))},{_q(len(outbound_only))}")
            for row in unproven:
                print(f"  unproven       {row['address']} — {row['reason']}")
            print("help: bin/mail/inbound-test.sh proves one address end to end and writes the proof this reads")
            return 3
        print(f"check[1]{{result,deliverable,outbound_only}}:\n  "
              f"\"PASS\",{_q(len(rows) - len(outbound_only))},{_q(len(outbound_only))}")
        for row in outbound_only:
            print(f"  sender-only    {row['address']} — {row['reason']}")
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
