#!/usr/bin/env python3
"""mcp-config-seat.py — seat ONE MCP server set into every harness on this host.

The law (the Allfather, 2026-11-10): *engram is Kaia's engine only.* Every harness —
pi, opencode, claude, cursor, codex, hermes — reaches memory through the WELL DOOR
(this body's gateway, ``http://127.0.0.1:<port>/mcp/well``), never through a direct
``engram-mcp --db <store>`` stdio server. A direct server writes into the seat's own
file, bypasses the gateway journal, and never reaches the heart.

And the widening, same day: every harness carries the SAME set as pi's
``~/.pi/agent/mcp-adapter.json`` (minus engram), generated from that one source in
each harness's own format — never a second hand-kept list per harness.

What it does, per harness present on this host (a harness that is absent is a clean
skip, RULES/25):

  * pi       rewrites ``mcp-adapter.json`` + ``mcp.json`` (the two names pi and Ymir read)
             with the direct engram dropped and the record doors on the gateway
  * opencode ``~/.config/opencode/opencode.json`` and the repo's ``opencode.json``, ``mcp{}``
  * claude   user scope, through ``claude mcp add-json/remove --scope user`` — never by
             editing ``~/.claude.json`` behind the CLI's back
  * cursor   ``~/.cursor/mcp.json``
  * codex    ``~/.codex/config.toml``, inside ONE marked block this door owns
  * hermes   prunes the direct engram from ``~/.hermes/config.yaml``; the adds are
             ``bin/seat/hermes-seat.sh``'s, which mirrors the same pi source

Out of the set for every harness, pi included: the direct engram, and the retired names
``gmail``, ``drive``, ``docs`` (the Allfather, 2026-11-10; ``YMIR_MCP_RETIRED`` replaces the list).
They are removed where found and never seated.

It is a NAMED merge: only the server names in the set (and the stale engram) are
touched; every other server the operator seated stays. A file it changes is backed up
first (``<file>.bak-<UTC stamp>``).

Secrets by reference only: a server whose spec carries a literal secret (an inline
``clientSecret``, a token in ``env`` or ``headers``) is NOT copied to another harness —
it is named in the output so the operator can move it to a reference. A value that is
a reference (``$VAR``, ``${VAR}``, ``{env:VAR}``) is fine.

Usage (through the shell face):
  bin/bridge/mcp-config.sh seat            seat every harness present
  bin/bridge/mcp-config.sh seat --check    report what would change; change nothing (exit 1 if drift)
  bin/bridge/mcp-config.sh harness <name>  print the set in one harness's format (pi|opencode|claude|cursor|codex)
"""
from __future__ import annotations

import copy
import datetime as _dt
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HOME = os.path.expanduser("~")
STAMP = _dt.datetime.now(_dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
CODEX_BEGIN = "# >>> ymir mcp (bin/bridge/mcp-config.sh seat) — generated, do not hand-edit >>>"
CODEX_END = "# <<< ymir mcp <<<"
RECORD_DOORS = ("well", "bolthorn", "skuld")
# Out of the set for EVERY harness, pi included (the Allfather, 2026-11-10): removed where found,
# never seated. YMIR_MCP_RETIRED (comma-separated) replaces the list.
RETIRED = tuple(n.strip() for n in os.environ.get("YMIR_MCP_RETIRED", "gmail,drive,docs").split(",") if n.strip())
SECRET_KEY = re.compile(r"(secret|token|passw|api[_-]?key|authorization|bearer|cookie)", re.I)
REFERENCE = re.compile(r"^\s*(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|\{env:[A-Za-z_][A-Za-z0-9_]*\})\s*$")

rows: list[tuple[str, str, str]] = []
drift = 0


def say(harness: str, state: str, detail: str) -> None:
    rows.append((harness, state, detail.replace('"', "'")))


def load_json(path: str, default):
    try:
        with open(path) as fh:
            return json.load(fh)
    except Exception:
        return default


def backup(path: str) -> None:
    if os.path.exists(path):
        shutil.copy2(path, f"{path}.bak-{STAMP}")


def write_json(path: str, doc) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".seat.tmp"
    with open(tmp, "w") as fh:
        json.dump(doc, fh, indent=2)
        fh.write("\n")
    os.replace(tmp, path)


def have(cmd: str) -> bool:
    return shutil.which(cmd) is not None


# ── the one set ───────────────────────────────────────────────────────────────

def is_direct_engram(name: str, spec) -> bool:
    """A harness-facing engram: the name `engram`, or any stdio that runs engram-mcp.
    The well door (a URL on the gateway) replaces both."""
    if name == "engram":
        return True
    if not isinstance(spec, dict):
        return False
    cmd = spec.get("command")
    parts = cmd if isinstance(cmd, list) else [cmd or ""]
    parts = [str(p) for p in parts] + [str(a) for a in (spec.get("args") or [])]
    return any(os.path.basename(p).startswith("engram-mcp") for p in parts)


def is_out(name: str, spec) -> bool:
    """Out of every harness: a direct engram, or a retired name."""
    return is_direct_engram(name, spec) or name in RETIRED


def dropped_text(names: list[str], specs: dict) -> str:
    """Name what was taken out, keeping 'direct engram' for the engram alone (the installer counts it)."""
    eng = [n for n in names if is_direct_engram(n, specs.get(n))]
    ret = [n for n in names if n not in eng]
    parts = ([f"direct engram: {', '.join(eng)}"] if eng else []) + ([f"retired: {', '.join(ret)}"] if ret else [])
    return "; ".join(parts)


def inline_secrets(spec, path: str = "") -> list[str]:
    found: list[str] = []
    if isinstance(spec, dict):
        for k, v in spec.items():
            here = f"{path}.{k}" if path else k
            if isinstance(v, str) and SECRET_KEY.search(k) and v and not REFERENCE.match(v):
                found.append(here)
            elif isinstance(v, (dict, list)):
                found += inline_secrets(v, here)
    elif isinstance(spec, list):
        for i, v in enumerate(spec):
            found += inline_secrets(v, f"{path}[{i}]")
    return found


def canonical(gateway_port: str, source: str) -> dict:
    """pi's set — the one source — with the direct engram dropped and the record
    doors pointed at this body's gateway."""
    base = f"http://127.0.0.1:{gateway_port}/mcp"
    src = load_json(source, {}) if source else {}
    servers = copy.deepcopy(src.get("mcpServers") or src.get("servers") or {})
    servers = {n: s for n, s in servers.items() if not is_out(n, s)}
    for door in RECORD_DOORS:
        servers[door] = {"url": f"{base}/{door}"}
    servers.setdefault("firecrawl", {"command": "npx", "args": ["-y", "firecrawl-mcp"],
                                     "env": {"FIRECRAWL_API_URL": "http://localhost:3002"}})
    return servers


def portable(servers: dict, with_ymir: bool) -> tuple[dict, list[str]]:
    """The set another harness receives: no literal secret travels."""
    out, held = {}, []
    for name, spec in servers.items():
        bad = inline_secrets(spec)
        if bad:
            held.append(f"{name} ({', '.join(bad)})")
            continue
        out[name] = spec
    if with_ymir and "ymir" not in out:
        out["ymir"] = {"command": "python3", "args": [os.path.join(stable_root(), "bin", "mcp", "ymir-mcp.py")]}
    return out, held


def stable_root() -> str:
    """The checkout a harness should keep pointing at: the pinned runtime when one is
    recorded, else the MAIN checkout — never a Yggdrasil worktree that is reaped later."""
    pinned = os.environ.get("YMIR_RUNTIME_DIR", "")
    if pinned and os.path.isfile(os.path.join(pinned, "bin", "mcp", "ymir-mcp.py")):
        return pinned
    try:
        common = subprocess.run(["git", "-C", ROOT, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                                capture_output=True, text=True, timeout=10).stdout.strip()
        main = os.path.dirname(common) if common.endswith("/.git") else ""
        if main and os.path.isfile(os.path.join(main, "bin", "mcp", "ymir-mcp.py")):
            return main
    except Exception:
        pass
    return ROOT


# ── per-harness formats ───────────────────────────────────────────────────────

def fmt_pi(spec: dict) -> dict:
    if "url" in spec:
        return {"url": spec["url"], **({"headers": spec["headers"]} if spec.get("headers") else {})}
    e = {"command": spec.get("command"), "args": list(spec.get("args") or [])}
    if spec.get("env"):
        e["env"] = dict(spec["env"])
    return e


def fmt_opencode(spec: dict) -> dict:
    if "url" in spec:
        e = {"type": "remote", "url": spec["url"], "enabled": True}
        if spec.get("headers"):
            e["headers"] = dict(spec["headers"])
        return e
    return {"type": "local", "command": [spec.get("command"), *(spec.get("args") or [])],
            "environment": dict(spec.get("env") or {}), "enabled": True}


def fmt_claude(spec: dict) -> dict:
    if "url" in spec:
        e = {"type": "http", "url": spec["url"]}
        if spec.get("headers"):
            e["headers"] = dict(spec["headers"])
        return e
    return {"type": "stdio", "command": spec.get("command"), "args": list(spec.get("args") or []),
            "env": dict(spec.get("env") or {})}


def toml_str(v: str) -> str:
    return json.dumps(v, ensure_ascii=False)


def fmt_codex(name: str, spec: dict) -> str:
    lines = [f"[mcp_servers.{name}]"]
    if "url" in spec:
        lines.append(f"url = {toml_str(spec['url'])}")
    else:
        lines.append(f"command = {toml_str(str(spec.get('command')))}")
        lines.append("args = [" + ", ".join(toml_str(str(a)) for a in (spec.get("args") or [])) + "]")
        if spec.get("env"):
            lines.append("env = { " + ", ".join(f"{toml_str(k)} = {toml_str(str(v))}"
                                                 for k, v in spec["env"].items()) + " }")
    return "\n".join(lines)


# ── the seats ─────────────────────────────────────────────────────────────────

def seat_json_map(harness: str, path: str, key: str, want: dict, fmt, check: bool,
                  create: bool) -> None:
    """A named merge into a JSON file's server map (pi, opencode, cursor)."""
    global drift
    if not os.path.exists(path) and not create:
        say(harness, "skip", f"no {path}")
        return
    doc = load_json(path, None)
    if doc is None and os.path.exists(path):
        say(harness, "fail", f"{path} does not parse — left untouched")
        drift += 1
        return
    doc = doc or {}
    cur = doc.get(key) if isinstance(doc.get(key), dict) else {}
    new = dict(cur)
    stale = [n for n, s in cur.items() if is_out(n, s)]
    for n in stale:
        del new[n]
    for n, s in want.items():
        new[n] = fmt(s)
    if new == cur:
        say(harness, "current", f"{path}: {len(want)} server(s) of the set, engram-free")
        return
    changed = sorted(n for n in set(new) | set(cur) if new.get(n) != cur.get(n))
    if check:
        drift += 1
        say(harness, "stale", f"{path}: would change {', '.join(changed)}"
            + (f" (drops {dropped_text(stale, cur)})" if stale else ""))
        return
    backup(path)
    doc[key] = new
    write_json(path, doc)
    say(harness, "seated", f"{path}: {', '.join(changed)}"
        + (f" · dropped {dropped_text(stale, cur)}" if stale else ""))


def seat_pi(want: dict, check: bool, source: str) -> None:
    if not have("pi") and not os.path.exists(source):
        say("pi", "absent", "no pi on this host")
        return
    d = os.path.dirname(source)
    for p in (os.path.join(d, "mcp-adapter.json"), os.path.join(d, "mcp.json")):
        # pi IS the source: its own specs are kept whole (an oauth block stays where the
        # operator put it); only the engram and the retired names are dropped and the
        # record doors re-pointed.
        seat_json_map("pi", p, "mcpServers", want, lambda s: s, check, create=True)


def seat_opencode(want: dict, check: bool) -> None:
    glob = os.path.join(HOME, ".config", "opencode", "opencode.json")
    if not have("opencode") and not os.path.exists(glob):
        say("opencode", "absent", "no opencode on this host")
        return
    seat_json_map("opencode", glob, "mcp", want, fmt_opencode, check, create=have("opencode"))
    repo = os.path.join(ROOT, "opencode.json")
    if os.path.exists(repo):
        seat_json_map("opencode", repo, "mcp", want, fmt_opencode, check, create=False)


def seat_cursor(want: dict, check: bool) -> None:
    d = os.path.join(HOME, ".cursor")
    if not (have("cursor-agent") or have("cursor") or os.path.isdir(d)):
        say("cursor", "absent", "no cursor on this host")
        return
    seat_json_map("cursor", os.path.join(d, "mcp.json"), "mcpServers", want, fmt_pi, check, create=True)


def seat_claude(want: dict, check: bool) -> None:
    """User scope through the CLI: `claude mcp add-json --scope user`. Never a blind edit
    of ~/.claude.json, which the running app rewrites."""
    global drift
    if not have("claude"):
        say("claude", "absent", "no claude on this host")
        return
    state = load_json(os.path.join(HOME, ".claude.json"), {})
    cur = state.get("mcpServers") or {}
    stale = [n for n, s in cur.items() if is_out(n, s)]
    pending = [n for n, s in want.items() if cur.get(n) != fmt_claude(s)]
    # Local (per-project) engram entries are the operator's file to mend; name them.
    local = sorted({n for p in (state.get("projects") or {}).values()
                    for n, s in ((p or {}).get("mcpServers") or {}).items() if is_direct_engram(n, s)})
    if local:
        say("claude", "note", "a project-scoped direct engram remains — claude mcp remove --scope local engram, in that project")
    if not pending and not stale:
        say("claude", "current", f"user scope carries the {len(want)} server(s) of the set, engram-free")
        return
    if check:
        drift += 1
        say("claude", "stale", f"user scope would change {', '.join(sorted(pending + stale))}"
            + (f" (drops {dropped_text(stale, cur)})" if stale else ""))
        return
    backup(os.path.join(HOME, ".claude.json"))
    done, failed = [], []
    for n in stale:
        r = subprocess.run(["claude", "mcp", "remove", "--scope", "user", n], capture_output=True, text=True)
        (done if r.returncode == 0 else failed).append(f"-{n}")
    for n in pending:
        if n in cur:
            subprocess.run(["claude", "mcp", "remove", "--scope", "user", n], capture_output=True, text=True)
        r = subprocess.run(["claude", "mcp", "add-json", "--scope", "user", n, json.dumps(fmt_claude(want[n]))],
                           capture_output=True, text=True)
        (done if r.returncode == 0 else failed).append(n)
    if failed:
        drift += 1
        say("claude", "fail", f"claude mcp refused: {', '.join(failed)}")
    say("claude", "seated", f"user scope: {', '.join(done) or 'nothing'}")


def codex_strip_tables(text: str, names: set[str]) -> tuple[str, list[str]]:
    """Remove [mcp_servers.<name>] (and its sub-tables) for the named servers."""
    out, dropped, skip = [], [], False
    hdr = re.compile(r"^\s*\[+\s*([^\]]+?)\s*\]+\s*$")
    for line in text.splitlines(keepends=True):
        m = hdr.match(line)
        if m:
            parts = m.group(1).split(".")
            skip = len(parts) >= 2 and parts[0] == "mcp_servers" and parts[1].strip('"') in names
            if skip and len(parts) == 2:
                dropped.append(parts[1].strip('"'))
        if not skip:
            out.append(line)
    return "".join(out), dropped


def seat_codex(want: dict, check: bool) -> None:
    global drift
    if not have("codex"):
        say("codex", "absent", "no codex on this host")
        return
    path = os.path.join(HOME, ".codex", "config.toml")
    text = open(path).read() if os.path.exists(path) else ""
    # take our own block out, then read what the operator owns
    pat = re.compile(re.escape(CODEX_BEGIN) + r".*?" + re.escape(CODEX_END) + r"\n?", re.S)
    outside = pat.sub("", text)
    try:
        import tomllib
        theirs = (tomllib.loads(outside).get("mcp_servers") or {})
    except Exception:
        theirs = {}
    engram_names = {n for n, s in theirs.items() if is_out(n, s)}
    outside, dropped = codex_strip_tables(outside, engram_names)
    # the codex plugin already serves the ymir doors; a second `ymir` table would shadow it
    mine = {n: s for n, s in want.items() if n not in theirs and n != "ymir"}
    kept = sorted(n for n in want if n in theirs and n not in engram_names)
    block = ""
    if mine:
        block = CODEX_BEGIN + "\n" + "\n\n".join(fmt_codex(n, s) for n, s in sorted(mine.items())) + "\n" + CODEX_END + "\n"
    new = outside.rstrip("\n") + ("\n\n" + block if block else "\n")
    if new == text or new.rstrip("\n") == text.rstrip("\n"):
        say("codex", "current", f"{path}: {len(mine)} server(s) in the managed block"
            + (f" · yours kept: {', '.join(kept)}" if kept else ""))
        return
    if check:
        drift += 1
        say("codex", "stale", f"{path}: the managed block would be rewritten"
            + (f" (drops {dropped_text(dropped, theirs)})" if dropped else ""))
        return
    backup(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write(new)
    say("codex", "seated", f"{path}: {len(mine)} server(s) in the managed block"
        + (f" · dropped {dropped_text(dropped, theirs)}" if dropped else "")
        + (f" · yours kept: {', '.join(kept)}" if kept else ""))


def seat_hermes(check: bool) -> None:
    global drift
    path = os.environ.get("HERMES_CONFIG") or os.path.join(HOME, ".hermes", "config.yaml")
    if not have("hermes") and not os.path.exists(path):
        say("hermes", "absent", "no hermes on this host")
        return
    if not os.path.exists(path):
        say("hermes", "skip", f"no {path} (bin/seat/hermes-seat.sh seats it)")
        return
    try:
        import yaml
    except Exception:
        say("hermes", "skip", "PyYAML missing — cannot read the hermes config")
        return
    doc = yaml.safe_load(open(path)) or {}
    srv = doc.get("mcp_servers") or {}
    stale = [n for n, s in srv.items() if is_out(n, s)]
    if not stale:
        say("hermes", "current", "engram-free (adds: bin/seat/hermes-seat.sh, from the same pi source)")
        return
    if check:
        drift += 1
        say("hermes", "stale", f"would drop {dropped_text(stale, srv)}")
        return
    backup(path)
    for n in stale:
        del srv[n]
    tmp = path + ".seat.tmp"
    with open(tmp, "w") as fh:
        yaml.safe_dump(doc, fh, sort_keys=False)
    os.replace(tmp, path)
    say("hermes", "seated", f"dropped {dropped_text(stale, srv)}")


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print("usage: mcp-config-seat.py <gateway-port> <pi-source> seat [--check] | pi [--check] | harness <name>", file=sys.stderr)
        return 2
    port, source, action, rest = argv[0], argv[1], argv[2], argv[3:]
    full = canonical(port, source)
    if action == "harness":
        name = rest[0] if rest else "pi"
        if name == "pi":
            print(json.dumps({"mcpServers": {n: fmt_pi(s) for n, s in full.items()}}, indent=2))
            return 0
        want, _ = portable(full, with_ymir=True)
        if name == "opencode":
            print(json.dumps({"mcp": {n: fmt_opencode(s) for n, s in want.items()}}, indent=2))
        elif name == "claude":
            print(json.dumps({"mcpServers": {n: fmt_claude(s) for n, s in want.items()}}, indent=2))
        elif name == "cursor":
            print(json.dumps({"mcpServers": {n: fmt_pi(s) for n, s in want.items()}}, indent=2))
        elif name == "codex":
            print("\n\n".join(fmt_codex(n, s) for n, s in sorted(want.items()) if n != "ymir"))
        else:
            print(f"error: unknown harness {name} (pi|opencode|claude|cursor|codex)", file=sys.stderr)
            return 2
        return 0
    check = "--check" in rest
    if action == "claude":
        # The Claude half alone, for callers that name it (`harness-extensions-install.sh`,
        # migration `0018-the-home-pulls-first`). It is the SAME law as `seat`: the set with
        # no direct engram, seated through `claude mcp --scope user`.
        want, held = portable(full, with_ymir=True)
        seat_claude(want, check)
        for h, st, dt in rows:
            print(f'  "{h}","{st}","{dt}"')
        if held:
            say("secrets", "held", "not copied to Claude (a literal secret in the spec): " + "; ".join(held))
        return 1 if check and drift else 0
    if action == "pi":
        # `mcp-config.sh write`: the pi half alone, plus the resolved rail as advisory
        # metadata under `ymir` (harnesses read `mcpServers` and ignore it).
        seat_pi(full, check, source)
        rail = os.environ.get("YMIR_MCP_RAIL_JSON", "")
        if rail and not check:
            d = os.path.dirname(source)
            for p in (os.path.join(d, "mcp-adapter.json"), os.path.join(d, "mcp.json")):
                doc = load_json(p, None)
                if isinstance(doc, dict) and doc.get("ymir") != json.loads(rail):
                    doc["ymir"] = json.loads(rail)
                    write_json(p, doc)
        for h, st, dt in rows:
            print(f'  "{h}","{st}","{dt}"')
        return 1 if check and drift else 0
    if action != "seat":
        print(f"error: unknown action {action}", file=sys.stderr)
        return 2
    want, held = portable(full, with_ymir=True)
    seat_pi(full, check, source)
    seat_opencode(want, check)
    seat_claude(want, check)
    seat_cursor(want, check)
    seat_codex(want, check)
    seat_hermes(check)
    if held:
        say("secrets", "held", "not copied to other harnesses (a literal secret in the spec; move it to a reference): "
            + "; ".join(held))
    print(f"mcp_seat[{len(rows)}]{{harness,state,detail}}:")
    for h, s, d in rows:
        print(f'  "{h}","{s}","{d}"')
    if check and drift:
        print("help: bin/bridge/mcp-config.sh seat (a named merge; every changed file is backed up first)")
        return 1
    return 1 if any(s == "fail" for _, s, _ in rows) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
