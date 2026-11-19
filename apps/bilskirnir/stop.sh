#!/usr/bin/env bash
# stop.sh — lower the hall this release raised (its own start.sh --stop).
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/start.sh" --stop
