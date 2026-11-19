#!/usr/bin/env bash
# stop.sh — close the Sessrúmnir this release opened.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/start.sh" --stop
