#!/usr/bin/env bash
# stop.sh — lower the hall server this release raised.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/start.sh" --stop
