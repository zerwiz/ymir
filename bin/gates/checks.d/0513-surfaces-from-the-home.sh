#!/usr/bin/env bash
# surfaces-from-the-home — 2026-11-20: a program asks WHICH surface, never which address. The operator's public
# hostnames live in his own registry (hodd/identity/services.yaml) and reach code through one reader
# (bin/fleet/public-surfaces.py); a service that declares nothing is exit 3 and is named, never invented.
gate surfaces-from-the-home "the public surfaces are read from the operator's registry, a missing one is named, and no code file spells the domain" \
     bash -c 'python3 "$ROOT/bin/fleet/tests/test_public_surfaces.py" >/dev/null'
