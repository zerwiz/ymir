#!/usr/bin/env bash
# apps.sh — one door over every app: list · install · update · check · rollback · remove.
# The logic is bin/apps/apps.py (stdlib Python); this is its door. `apps.sh help` for the verbs.
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apps.py" "$@"
