#!/usr/bin/env bash
# gjallarhorn-publish.sh — put an app on a public name BEHIND the hall's login, by config alone.
#
#   bin/forge/gjallarhorn-publish.sh plan              # what would be written, nothing changed
#   bin/forge/gjallarhorn-publish.sh check             # refuses an app with no gate or nobody named
#   bin/forge/gjallarhorn-publish.sh apply [--dry-run] # edge, tunnel ingress, DNS; proves the guard first
#   bin/forge/gjallarhorn-publish.sh status            # edge and outside answers per name
#   bin/forge/gjallarhorn-publish.sh rules [--all]     # the hall's per-app rules file, from publish.yaml
#
# Names, upstreams, the hall and the audience are read from the operator's home
# (config/machines/<machine>/publish.yaml); none is written in this repository.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ] && [ -r "$SCRIPT_DIR/../vault/hoard-lib.sh" ]; then
  . "$SCRIPT_DIR/../vault/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1
fi
type ymir_home_root >/dev/null 2>&1 && ymir_home_root YMIR_HOME
type hoard_state_dir >/dev/null 2>&1 && hoard_state_dir YMIR_STATE_DIR
export YMIR_HOME YMIR_STATE_DIR
case "${1-}" in -h|--help|"") sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
exec python3 "$SCRIPT_DIR/gjallarhorn-publish.py" "$@"
