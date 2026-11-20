#!/usr/bin/env bash
# telegram.sh — the door to Skírnir's own bot (the adapter lives in telegram.py).
exec python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/telegram.py" "$@"
