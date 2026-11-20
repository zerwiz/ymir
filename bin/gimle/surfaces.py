#!/usr/bin/env python3
"""surfaces.py — the operator's PUBLIC SURFACES, asked of his home and never spelled here.

WHY (2026-11-20). The Allfather: *"replace the literal <the domain> hostnames in the repo with configuration read
from the home."* The public tree carried his domain literally in code, in an example env file and in test
fixtures — sixty-odd places — and a public repository that names the operator's real hosts is the leak RULES/04
exists to stop. There is already ONE registry of the house's services, with one `public_url` per service:
`<home>/hodd/identity/services.yaml`, written by the operator and read by the tunnel round. This door is the
reader, so a program asks *which surface* and never *which address*.

  surfaces.py --get <id>        the public_url for that service (exit 3 when it is not declared)
  surfaces.py --list            `id<TAB>url` for every service that declares one
  surfaces.py --json            the whole map as JSON

Configuration (Rule 07):
  YMIR_HOME                    the home; resolved through bin/vault/hodd.sh when it is unset
  YMIR_SERVICES_REGISTRY       another registry file (a test fence, another house)

Exit: 0 answered · 3 the service declares no public_url (or does not exist) · 2 usage or no registry.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def registry_path() -> str:
    explicit = os.environ.get("YMIR_SERVICES_REGISTRY", "").strip()
    if explicit:
        return explicit
    home = os.environ.get("YMIR_HOME", "").strip()
    if not home:
        try:
            out = subprocess.run(["bash", os.path.join(ROOT, "bin", "vault", "hodd.sh"), "path"],
                                 capture_output=True, text=True, timeout=20)
            if out.returncode == 0 and out.stdout.strip():
                home = os.path.dirname(out.stdout.strip())
        except Exception:
            home = ""
    if not home:
        return ""
    return os.path.join(home, "hodd", "identity", "services.yaml")


def load() -> dict[str, str]:
    path = registry_path()
    if not path or not os.path.isfile(path):
        return {}
    try:
        import yaml
        doc = yaml.safe_load(open(path, encoding="utf-8")) or {}
    except Exception:
        return {}
    out: dict[str, str] = {}
    for row in doc.get("services") or []:
        if not isinstance(row, dict):
            continue
        sid, url = row.get("id"), row.get("public_url")
        if sid and url:
            out[str(sid)] = str(url).rstrip("/")
    return out


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if argv else 2
    verb = argv[0]
    surfaces = load()
    if verb == "--get":
        if len(argv) < 2:
            print("error: --get needs a service id", file=sys.stderr)
            return 2
        sid = argv[1]
        if not registry_path() or not os.path.isfile(registry_path()):
            print(f"surfaces: no registry at {registry_path() or '<no home>'} — the home names the house's surfaces",
                  file=sys.stderr)
            return 2
        if sid in surfaces:
            print(surfaces[sid])
            return 0
        print(f"surfaces: service '{sid}' declares no public_url in {registry_path()}", file=sys.stderr)
        return 3
    if verb == "--list":
        for sid in sorted(surfaces):
            print(f"{sid}\t{surfaces[sid]}")
        return 0
    if verb == "--json":
        print(json.dumps(surfaces, indent=2, sort_keys=True))
        return 0
    print(f"error: unknown verb {verb} (--get | --list | --json)", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
