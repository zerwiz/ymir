#!/usr/bin/env bash
# stop.sh — lower the window (its unit if it raised it, else its own start.sh --stop).
systemctl --user stop ymir-rodd.service >/dev/null 2>&1 || true
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/start.sh" --stop
