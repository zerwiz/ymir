#!/usr/bin/env python3
"""gjallarhorn-publish — put an app on a public name BEHIND the hall's login, by config alone.

The halls are local and a tunnel never dials one (plan 275 item 30). This door is the one narrow way an operator
chooses to reach an app from outside: the name goes to a small gated edge on loopback, the edge asks the hall's
login (Gimlé) who is calling, and only the people the app's own rule names reach the app. Nothing is published
without that guard in front, and the door proves the guard before it touches DNS.

Every value comes from the operator's home, never from this repository:

  $YMIR_HOME/config/machines/<machine>/publish.yaml   (or $YMIR_PUBLISH_CONFIG)

    gate: https://hall.example.org          # the hall's login; unsigned browsers are sent here
    edge_port: 8795                         # loopback port of this machine's gated edge
    tunnel:
      config: ~/path/to/cloudflared.yml     # the cloudflared config whose ingress is extended
      name: my-tunnel                       # tunnel name or id, for the DNS route
      restart: "docker restart my-tunnel"   # optional: how this machine reloads the tunnel
    apps:
      - name: notes
        host: notes-host-a.example.org
        upstream: http://127.0.0.1:9000
        allow: [operator, ada@example.org]  # `operator` = the address in hodd/identity/operator.yaml

Usage:
  gjallarhorn-publish.sh plan | check | apply [--dry-run] | status | rules [--all] [--out FILE]
"""
from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.parse

try:
    import yaml
except ImportError:  # the door says so rather than guessing a format
    sys.exit("error: PyYAML is needed to read publish.yaml (pip install pyyaml)")

# The halls: the edge port may never be one of them (the edge is its own, gated door).
HALL_PORTS = {3888, 3889, 4322, 4602, 4603, 8437, 8787, 3891}
BEGIN = "  # ymir-publish begin (managed by gjallarhorn-publish.sh; edit publish.yaml instead)"
END = "  # ymir-publish end"
EDGE_NAME = "ymir-publish-edge"
CHALLENGE = ("302", "303", "401", "403")


def home() -> str:
    return os.environ.get("YMIR_HOME") or os.path.expanduser("~/Documents/ymirhome")


def machine() -> str:
    return os.environ.get("YMIR_MACHINE") or socket.gethostname().split(".")[0]


def config_path() -> str:
    return os.path.expanduser(os.environ.get("YMIR_PUBLISH_CONFIG") or
                              os.path.join(home(), "config", "machines", machine(), "publish.yaml"))


def state_dir() -> str:
    d = os.environ.get("YMIR_STATE_DIR") or os.path.join(home(), "state")
    p = os.path.join(d, "publish")
    os.makedirs(p, exist_ok=True)
    return p


def load(path: str) -> dict:
    with open(path, encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def operator_emails() -> list[str]:
    try:
        d = load(os.path.join(home(), "hodd", "identity", "operator.yaml"))
    except OSError:
        return []
    out: list = []
    for key in ("email", "emails"):
        v = d.get(key)
        out += [v] if isinstance(v, str) else list(v or [])
    return [e.strip().lower() for e in out if isinstance(e, str) and "@" in e]


def allowed(app: dict) -> list[str]:
    out: list[str] = []
    for a in app.get("allow") or []:
        a = str(a).strip().lower()
        out += operator_emails() if a == "operator" else [a]
    return sorted(set(x for x in out if "@" in x))


def problems(cfg: dict) -> list[str]:
    bad: list[str] = []
    gate = urllib.parse.urlsplit(str(cfg.get("gate") or ""))
    if gate.scheme != "https" or not gate.hostname:
        bad.append("gate: must be the hall's https address (the login every name asks)")
    port = cfg.get("edge_port")
    if not isinstance(port, int) or not 1024 <= port <= 65535:
        bad.append("edge_port: a loopback port between 1024 and 65535")
    elif port in HALL_PORTS:
        bad.append(f"edge_port: {port} is a hall port; the edge is its own door")
    tun = cfg.get("tunnel") or {}
    if not tun.get("config"):
        bad.append("tunnel.config: the cloudflared config to extend")
    if not tun.get("name"):
        bad.append("tunnel.name: the tunnel name or id, for the DNS route")
    apps = cfg.get("apps") or []
    if not apps:
        bad.append("apps: nothing to publish")
    seen: set[str] = set()
    for i, app in enumerate(apps):
        label = app.get("name") or f"#{i + 1}"
        host = str(app.get("host") or "").lower()
        if not re.fullmatch(r"[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+", host):
            bad.append(f"{label}: host is not a hostname")
        if host in seen:
            bad.append(f"{label}: host {host} appears twice")
        seen.add(host)
        up = urllib.parse.urlsplit(str(app.get("upstream") or ""))
        if up.scheme not in ("http", "https") or not up.hostname:
            bad.append(f"{label}: upstream must be an http(s) address")
        if not allowed(app):
            bad.append(f"{label}: allow names nobody — an app is never published open (RULES/24)")
    return bad


def matcher(host: str) -> str:
    return re.sub(r"[^a-z0-9]", "_", host.lower())


def caddyfile(cfg: dict) -> str:
    gate = str(cfg["gate"]).rstrip("/")
    out = ["{", "\tadmin off", "\tauto_https off", "}", "",
           f"http://:{cfg['edge_port']} {{", "\tbind 127.0.0.1", ""]
    for app in cfg["apps"]:
        host = app["host"].lower()
        out += [f"\t@{matcher(host)} host {host}",
                f"\thandle @{matcher(host)} {{",
                f"\t\tforward_auth {gate} {{",
                f"\t\t\turi /oidc/authz?app={host}",
                "\t\t\theader_up X-Forwarded-Host {host}",
                "\t\t\theader_up X-Forwarded-Proto https",
                "\t\t\tcopy_headers Remote-User Remote-Email Remote-Name",
                "\t\t}",
                f"\t\treverse_proxy {app['upstream']}",
                "\t}", ""]
    out += ["\thandle {", '\t\trespond "not found" 404', "\t}", "}", ""]
    return "\n".join(out)


def ingress_block(cfg: dict) -> str:
    lines = [BEGIN]
    for app in cfg["apps"]:
        lines += [f"  - hostname: {app['host'].lower()}", f"    service: http://127.0.0.1:{cfg['edge_port']}"]
    lines.append(END)
    return "\n".join(lines) + "\n"


def with_block(text: str, block: str) -> str:
    """The tunnel config with our managed block in it exactly once, ahead of the catch-all rule."""
    text = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", "", text, flags=re.S)
    lines = text.splitlines(keepends=True)
    for i in range(len(lines) - 1, -1, -1):
        if re.match(r"^\s*-\s*service:", lines[i]):
            return "".join(lines[:i]) + block + "".join(lines[i:])
    raise SystemExit("error: the tunnel config has no catch-all `- service:` rule to place the block before")


def rules_text(cfgs: list[dict]) -> str:
    out = ["# app-rules — rendered by gjallarhorn-publish.sh from each machine's publish.yaml. Do not edit by hand.",
           "# One line per app: host: address, address. The hall's login reads it (OIDC_APP_RULES)."]
    for cfg in cfgs:
        for app in cfg.get("apps") or []:
            out.append(f"{app['host'].lower()}: {', '.join(allowed(app))}")
    return "\n".join(out) + "\n"


def run(cmd, **kw):
    return subprocess.run(cmd, shell=isinstance(cmd, str), text=True, capture_output=True, **kw)


def edge_up(cfg: dict, caddy_path: str) -> None:
    if shutil.which("caddy"):
        pidf = os.path.join(state_dir(), "edge.pid")
        if os.path.exists(pidf):
            try:
                os.kill(int(open(pidf).read().strip()), 15)
                time.sleep(1)
            except (OSError, ValueError):
                pass
        p = subprocess.Popen(["caddy", "run", "--config", caddy_path, "--adapter", "caddyfile"],
                             stdin=subprocess.DEVNULL, stdout=open(os.path.join(state_dir(), "edge.log"), "ab"),
                             stderr=subprocess.STDOUT, start_new_session=True)
        open(pidf, "w").write(str(p.pid))
    elif shutil.which("docker"):
        image = (cfg.get("edge") or {}).get("image", "caddy:2-alpine")
        run(["docker", "rm", "-f", EDGE_NAME])
        r = run(["docker", "run", "-d", "--name", EDGE_NAME, "--restart", "unless-stopped", "--network", "host",
                 "-v", f"{caddy_path}:/etc/caddy/Caddyfile:ro", image])
        if r.returncode:
            raise SystemExit("error: the edge did not start: " + r.stderr.strip())
    else:
        raise SystemExit("error: the edge needs `caddy` or `docker` on this machine")
    for _ in range(40):
        try:
            socket.create_connection(("127.0.0.1", cfg["edge_port"]), timeout=0.3).close()
            return
        except OSError:
            time.sleep(0.25)
    raise SystemExit("error: the edge did not answer on its port")


def ask_edge(cfg: dict, host: str) -> str:
    r = run(["curl", "-s", "-m", "20", "-o", "/dev/null", "-w", "%{http_code}", "-H", "Accept: text/html",
             "-H", f"Host: {host}", f"http://127.0.0.1:{cfg['edge_port']}/"])
    return r.stdout.strip() or "down"


def probe_local(cfg: dict) -> list[str]:
    """Ask the edge, as an unsigned browser, for every name. Anything but a challenge is a failure."""
    return [f"{a['host']}: the edge answered {ask_edge(cfg, a['host'])} to an unsigned browser"
            for a in cfg["apps"] if ask_edge(cfg, a["host"]) not in CHALLENGE]


def apply(cfg: dict, dry: bool) -> int:
    tun = cfg["tunnel"]
    tpath = os.path.expanduser(str(tun["config"]))
    caddy_path = os.path.join(state_dir(), "Caddyfile")
    print(f"publish[{len(cfg['apps']) + 2}]{{step,detail}}:")
    print(f'  "edge","Caddyfile {caddy_path}, forward-auth to the hall for {len(cfg["apps"])} name(s)"')
    print(f'  "tunnel","ingress block in {tpath}"')
    for app in cfg["apps"]:
        print(f'  "dns","route {app["host"]} to tunnel {tun["name"]}"')
    if dry:
        print('  "dry-run","nothing was written or started"')
        return 0
    with open(caddy_path, "w", encoding="utf-8") as fh:
        fh.write(caddyfile(cfg))
    edge_up(cfg, caddy_path)
    bad = probe_local(cfg)          # the guard is proven BEFORE the tunnel or DNS learns of the names
    if bad:
        print("error: the guard did not hold; nothing was published:", file=sys.stderr)
        for b in bad:
            print("  " + b, file=sys.stderr)
        return 1
    print('  "proof","the edge challenges an unsigned browser for every name"')
    text = open(tpath, encoding="utf-8").read()
    new = with_block(text, ingress_block(cfg))
    if new != text:
        shutil.copy2(tpath, f"{tpath}.bak-publish-{dt.datetime.now():%Y%m%d-%H%M%S}")
        open(tpath, "w", encoding="utf-8").write(new)
        if tun.get("restart"):
            r = run(str(tun["restart"]))
            if r.returncode:
                print("error: the tunnel did not restart: " + r.stderr.strip(), file=sys.stderr)
                return 1
            print('  "tunnel","restarted"')
        else:
            print('  "tunnel","config written; restart it yourself (tunnel.restart is not set)"')
    for app in cfg["apps"]:
        r = run(["cloudflared", "tunnel", "route", "dns", "--overwrite-dns", str(tun["name"]), app["host"]])
        tail = (r.stdout + r.stderr).strip().splitlines()
        print(f'  "dns","{app["host"]}: {tail[-1] if tail else r.returncode}"')
        if r.returncode:
            return 1
    return 0


def status(cfg: dict) -> int:
    print("publish_status[%d]{host,edge,outside}:" % len(cfg["apps"]))
    code = 0
    for app in cfg["apps"]:
        e = ask_edge(cfg, app["host"])
        o = run(["curl", "-s", "-m", "20", "-o", "/dev/null", "-w", "%{http_code}", "-H", "Accept: text/html",
                 f"https://{app['host']}/"]).stdout.strip() or "none"
        code |= 0 if (e in CHALLENGE and o in CHALLENGE) else 1
        print(f'  "{app["host"]}","{e}","{o}"')
    return code


def emit(text: str, out: str | None) -> None:
    if out:
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(text)
    else:
        sys.stdout.write(text)


def main() -> int:
    ap = argparse.ArgumentParser(prog="gjallarhorn-publish.sh")
    ap.add_argument("cmd", choices=["plan", "check", "apply", "status", "rules"])
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--all", action="store_true", help="rules: every machine's publish.yaml, not only this one")
    ap.add_argument("--out")
    a = ap.parse_args()

    if a.cmd == "rules" and a.all:
        base = os.path.join(home(), "config", "machines")
        cfgs = [load(os.path.join(base, m, "publish.yaml")) for m in sorted(os.listdir(base))
                if os.path.exists(os.path.join(base, m, "publish.yaml"))]
        emit(rules_text(cfgs), a.out)
        return 0

    path = config_path()
    if not os.path.exists(path):
        print(f"error: no publish config at {path}\nhelp: docs/features/publish-an-app-behind-the-login.md", file=sys.stderr)
        return 1
    cfg = load(path)
    bad = problems(cfg)
    if bad:
        print("error: publish.yaml is not safe to apply:", file=sys.stderr)
        for b in bad:
            print("  " + b, file=sys.stderr)
        return 1
    if a.cmd == "check":
        print(f'publish_check[1]{{config,apps,verdict}}:\n  "{path}",{len(cfg["apps"])},"ok — every app has a gate and a named audience"')
    elif a.cmd == "plan":
        print(caddyfile(cfg))
        print(ingress_block(cfg))
        for app in cfg["apps"]:
            print(f"dns: {app['host']} -> tunnel {cfg['tunnel']['name']}; audience: {len(allowed(app))} address(es)")
    elif a.cmd == "rules":
        emit(rules_text([cfg]), a.out)
    elif a.cmd == "apply":
        return apply(cfg, a.dry_run)
    else:
        return status(cfg)
    return 0


if __name__ == "__main__":
    sys.exit(main())
