#!/usr/bin/env bash
# project-and-publish.sh — project the meeting record, then hand it to the desk on the server.
#
#   project-and-publish.sh [--dry-run]
#
# The record lives in the hoard; the desk runs on the server. This is the one job that carries the first to
# the second, and it is idempotent: the projector rewrites `meetings.json` from the record each time, and
# `places.json` is only created when absent (never overwritten — a membership map is not a projection).
#
# Env: YMIR_HOME (required) · GIMLE_DESK_SSH and GIMLE_DESK_DIR, or the same two keys in
#      `$YMIR_HOME/config/gimle-desktop.env`. A seat with neither reports SKIP — it never guesses.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$ROOT/bin/gimle"
out="$(mktemp -d)"; trap 'rm -rf "$out"' EXIT
dry=0; [ "${1-}" = "--dry-run" ] && dry=1
python3 "$HERE/project.py" --out "$out" ${dry:+} || exit 1
# The desk's host and directory are the operator's own (Rule 25): read them, never assume them.
# `$YMIR_HOME/config/gimle-desktop.env` holds `GIMLE_DESK_SSH` and `GIMLE_DESK_DIR`.
conf="${YMIR_HOME:-}/config/gimle-desktop.env"
[ -r "$conf" ] && . "$conf"
target="${GIMLE_DESK_SSH:-}"
remote="${GIMLE_DESK_DIR:-}"
if [ -z "$target" ] || [ -z "$remote" ]; then
  printf 'SKIP\tthe desk is not configured\tset GIMLE_DESK_SSH and GIMLE_DESK_DIR in %s\n' "$conf"
  exit 0
fi
if [ "$dry" = 1 ]; then
  printf 'would publish\t%s/meetings.json\t%s/places.json\n' "$out" "$out"
  exit 0
fi
scp -q "$out/meetings.json" "$target:$remote/meetings.json" || { printf 'publish failed\t%s\n' "$target"; exit 1; }
if ! ssh -o BatchMode=yes "$target" "test -f $remote/places.json"; then
  scp -q "$out/places.json" "$target:$remote/places.json" || true
fi
printf 'published\t%s:%s\n' "$target" "$remote"
