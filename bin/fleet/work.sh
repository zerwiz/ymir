#!/usr/bin/env bash
# work.sh — `ymir work`: the one door to the work road (plan 365). The engine is work.py.
exec python3 "$(dirname "${BASH_SOURCE[0]}")/work.py" "$@"
