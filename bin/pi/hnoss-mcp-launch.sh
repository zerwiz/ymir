#!/bin/sh
# Seated by bin/pi/hnoss-ensure.sh — the shipped launcher is the source
# of truth; this path exists only so an older config keeps working.
exec "/home/heimdall/ymir/bin/pi/hnoss-mcp-launch.sh" "$@"
