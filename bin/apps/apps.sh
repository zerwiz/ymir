#!/usr/bin/env bash
# apps.sh — one door over every app: list · install · update · check · rollback · remove.
# The logic is bin/apps/apps.py (stdlib Python); this is its door. `apps.sh help` for the verbs.
#
# The long verbs (install · update · rollback) clone, install and build — an hour a person watches.
# They run under the terminal cloth (bin/desktop/ymir-style.sh): a rune turning, one ending line,
# the noisy output kept in a log. apps.py's own rows still reach stdout, unchanged and complete.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$HERE/apps.py"
case "${1:-}" in
  install|update|rollback)
    _cloth_u="$-"; . "$HERE/../desktop/ymir-style.sh"; style_init; case "$_cloth_u" in *u*) ;; *) set +u ;; esac
    style_title "apps" "$1 ${2:---all}"
    style_step --data "$1 ${*:2}" -- python3 "$PY" "$@"; rc=$?
    [ "$rc" -eq 0 ] && style_next "ymir apps list — every app and where it lives" "ymir apps check — is each one current?"
    exit "$rc" ;;
  *) exec python3 "$PY" "$@" ;;
esac
