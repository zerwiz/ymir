#!/usr/bin/env python3
"""a2a.py — the repository's own card in the constellation.  Standard library only.

A repository that answers for its areas has something to say to a peer: *these are the areas I hold,
these are the ones nobody holds, and here is how to ask me about one.* That is an A2A agent card, and
it is generated from the same shelf the gate reads — never written twice.

  a2a.py card [--url URL]      print (or with --write, write) .well-known/agent-card.json from areas/
  a2a.py check                validate the card: protocol, name, url, one skill per HELD area, no secrets
  a2a.py skills               what this repository would answer for, and whether it is held

THE LAW THE CARD OBEYS (RULES/24, RULES/39, plan 61):
  - a card publishes an address that ANSWERS, or publishes none — never `127.0.0.1` dressed as a host;
  - a card carries metadata only: no secret, no token, no personal data, no client's name;
  - a skill is a thing a peer may ask for and a grant may refuse — the card is an invitation to ask,
    never a grant. `constellation_ask` still refuses without a per-pair grant.
Exit: 0 ok · 1 a fault · 2 usage.
"""
import json
import os
import re
import sys

ROOT = os.environ.get("AREAS_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARD = os.path.join(ROOT, ".well-known", "agent-card.json")
PROTOCOL_V10 = "1.0"
PROTOCOL_V03 = "0.3.0"
SECRETISH = re.compile(r"(sk-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{12,}|"
                       r"-----BEGIN [A-Z ]*PRIVATE KEY-----|password\s*[:=]|api[_-]?key\s*[:=])", re.I)

sys.path.insert(0, os.path.join(ROOT, "scripts"))
try:
    from areas import declarations, canon  # the same reader the gate uses: one truth
except Exception:  # the door may be run where areas.py sits beside it
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from areas import declarations, canon


def held_areas():
    decl = declarations()
    out = []
    for a in canon().get("areas") or []:
        d, _ = decl.get(a["id"], ({}, ""))
        state = (d.get("state") or "unheld").strip()
        out.append((a, state, (d.get("keeper") or "unclaimed").strip()))
    return out


def repo_name():
    name = os.path.basename(ROOT.rstrip("/")) or "repository"
    return name.lower().replace(" ", "-")


def build(url=None):
    """The card the A2A specification asks for (v1.0 required fields, v0.3 compatibility kept).

    MEASURED 2026-11-08 against the Linux Foundation spec and the 1.0/0.3 releases:
      - v0.3.0 moved the well-known URI to `/.well-known/agent-card.json` and added `signatures`;
      - v1.0 requires name · description · version · supportedInterfaces · capabilities ·
        defaultInputModes · defaultOutputModes · skills; provider · documentationUrl · iconUrl ·
        securitySchemes · securityRequirements · signatures are optional;
      - an AgentSkill carries id · name · description · tags · examples (· input/output modes).
    We emit BOTH `url` (the v0.3 field every deployed card still uses) and `supportedInterfaces`
    (v1.0), so one card is readable by either generation of client. `version` is the version of THIS
    agent's record (the shelf), never the protocol's.
    """
    areas = held_areas()
    skills = []
    for a, state, keeper in areas:
        if state != "held":
            continue
        skills.append({
            "id": "area-" + a["id"],
            "name": a["name"][:60],
            "description": a["question"],
            "tags": ["area", a["id"], "held"],
            "examples": [f"what does {repo_name()} answer for {a['name']}?"],
        })
    address = url or ""
    card = {
        "protocolVersion": PROTOCOL_V10,
        "name": repo_name()[:60],
        "description": (f"{repo_name()} answers for {len(areas)} areas; {len(skills)} are held. "
                        "Ask for one by its area skill. A grant is required and is never implied by this card."),
        "version": "1." + str(len(skills)) + ".0",
        "url": address,
        "supportedInterfaces": [
            {"url": address, "protocolBinding": "JSONRPC", "protocolVersion": PROTOCOL_V10},
            {"url": address, "protocolBinding": "JSONRPC", "protocolVersion": PROTOCOL_V03},
        ] if address else [],
        "capabilities": {"streaming": False, "pushNotifications": False, "extendedAgentCard": False},
        "defaultInputModes": ["text/plain"],
        "defaultOutputModes": ["text/plain"],
        "securitySchemes": {
            "grant": {
                "type": "http",
                "scheme": "bearer",
                "bearerFormat": "JWT",
                "description": "a per-pair, per-skill grant with an expiry; the card never implies one",
            }
        },
        "securityRequirements": [{"grant": []}],
        "skills": skills,
    }
    return card


def check():
    faults = []
    if not os.path.exists(CARD):
        return ["no card at .well-known/agent-card.json — generate one: bash scripts/a2a.sh card --write"]
    try:
        card = json.load(open(CARD))
    except Exception as e:
        return [f"the card does not parse — {e}"]
    # v1.0 required fields, by name, so a missing one is named rather than described
    for field in ("name", "description", "version", "capabilities", "defaultInputModes",
                  "defaultOutputModes", "skills"):
        if not card.get(field):
            faults.append(f"required field `{field}` is missing or empty (A2A 1.0 AgentCard)")
    if len(str(card.get("name") or "")) > 60:
        faults.append("`name` is over 60 characters — clients show it in a list")
    # UNPUBLISHED IS HONEST, LOOPBACK IS NOT: a repository that serves nothing names no address, and
    # that is a printed state rather than a fault. What is refused is an address that cannot answer.
    unpublished = not card.get("supportedInterfaces") and not (card.get("url") or "").strip()
    for iface in card.get("supportedInterfaces") or []:
        u = (iface.get("url") or "").strip()
        if not u:
            faults.append("a `supportedInterfaces` entry has no url")
        elif re.match(r"^(https?://)?(127\.0\.0\.1|localhost)", u):
            faults.append("`supportedInterfaces` publishes loopback — a card must publish the address "
                          "that answers, or none (the fleet's 2026-11-05 lesson)")
        if iface.get("protocolVersion") not in (PROTOCOL_V10, PROTOCOL_V03):
            faults.append(f"unsupported protocolVersion {iface.get('protocolVersion')!r}")
    skills = card.get("skills") or []
    if not skills:
        faults.append("no `skills` — a card with no skill is a name, not a peer")
    have = {s.get("id") for s in skills}
    for a, state, _keeper in held_areas():
        if state == "held" and "area-" + a["id"] not in have:
            faults.append(f"{a['id']} is held in areas/ but not offered as a skill on the card")
    for s in skills:
        for field in ("id", "name", "description"):
            if not str(s.get(field) or "").strip():
                faults.append(f"skill {s.get('id') or '(no id)'} has no `{field}`")
    if not card.get("securitySchemes") and not card.get("securityRequirements"):
        faults.append("no `securitySchemes`/`securityRequirements` — a card that promises anonymity "
                      "is a lie about this house")
    blob = json.dumps(card)
    if SECRETISH.search(blob):
        faults.append("something in the card looks like a credential — a card is metadata, never a secret")
    if re.search(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", blob):
        faults.append("the card carries a mailbox — publish a channel, never a person's address")
    return faults


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    verb = argv[0]
    if verb == "card":
        url = None
        if "--url" in argv:
            url = argv[argv.index("--url") + 1]
        card = build(url)
        if "--write" in argv:
            os.makedirs(os.path.dirname(CARD), exist_ok=True)
            if os.path.exists(CARD):
                old = json.load(open(CARD))
                # a URL a human published by hand is never overwritten by a generator
                card["url"] = card["url"] or old.get("url", "")
                card["name"] = old.get("name") or card["name"]
            json.dump(card, open(CARD, "w"), indent=2)
            open(CARD, "a").write("\n")
            print(f"card: wrote {os.path.relpath(CARD, ROOT)} — {len(card['skills'])} held area skill(s)")
        else:
            print(json.dumps(card, indent=2))
        return 0
    if verb == "skills":
        rows = held_areas()
        held = [a for a, s, _ in rows if s == "held"]
        print(f'skills[{len(held)}]{{area,state,keeper}}:')
        for a, state, keeper in rows:
            print(f'  "{a["id"]}","{state}","{keeper}"')
        return 0
    if verb == "check":
        faults = check()
        if faults:
            print(f"a2a refused: {len(faults)} fault(s) in the card\n", file=sys.stderr)
            for f in faults:
                print(f"  {f}", file=sys.stderr)
            return 1
        card = json.load(open(CARD))
        if not card.get("supportedInterfaces") and not (card.get("url") or "").strip():
            print("a2a: the card is valid and UNPUBLISHED — it names no address, so no peer can dial it yet. "
                  "publish one: bash scripts/a2a.sh card --url https://… --write")
        else:
            print("a2a: the card answers a2a 1.0 and 0.3, offers one skill per held area, carries no secret, "
                  "and requires a grant")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
