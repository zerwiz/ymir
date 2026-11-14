#!/usr/bin/env bash
# ship-watch.sh — the delivery loop: settle branches, then ship proved PRs.
set -u
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
HOME_DIR=""; ymir_home_root HOME_DIR 2>/dev/null || true
STATE=""; hoard_state_dir STATE 2>/dev/null || true
[ -n "$HOME_DIR" ] && [ -n "$STATE" ] || { printf 'ship-watch: home/state unresolved\n' >&2; exit 1; }
PROJECTS="$HOME_DIR/hodd/identity/projects.yaml"
SHIP="$ROOT/bin/forge/ship.sh"
DRY=0; JSON=0
while [ $# -gt 0 ]; do case "$1" in --dry-run) DRY=1; shift ;; --json) JSON=1; shift ;; -*) shift ;; *) shift ;; esac; done
# plan 290 §3 — the shared law every outward door keeps (bin/forge/warden-lib.sh).
. "$ROOT/bin/forge/warden-lib.sh"
warden_begin ship-watch || exit 1
command -v gh >/dev/null 2>&1 || { printf 'ship-watch: gh missing\n' >&2; exit 1; }

# seal-hold brake
TIMER_ACTION=""
# re-parse timer flags
for a in "$@"; do case "$a" in --install-timer) TIMER_ACTION=install;; --uninstall-timer) TIMER_ACTION=uninstall;; --timer-status) TIMER_ACTION=status;; esac; done
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE="ship-watch.service"; TIMER="ship-watch.timer"
if [ -n "$TIMER_ACTION" ]; then
  case "$TIMER_ACTION" in
    install)
      # plan 290 rule 1: seating is the operator's decision for THIS machine, not the door's.
      warden_seat_allowed ship-watch || exit 3
      # the unit is the register's (config/units.yaml: ship-watch) and the one writer renders it against the
      # PINNED runtime, never the tree this door ran from (plan 269)
      bash "$ROOT/bin/engine/units.sh" write ship-watch --no-restart >/dev/null || { printf 'ship: units.sh could not write the unit\n' >&2; exit 1; }
      systemctl --user daemon-reload 2>/dev/null || true
      systemctl --user enable --now "$TIMER" 2>&1 | tail -2 || true
      printf 'timer[3]{unit,interval,state}:\n  "%s","%s","%s"\n' "$UNIT_DIR/$TIMER" "5min" "$(systemctl --user is-active "$TIMER" 2>/dev/null | head -1 || true)"
      exit 0 ;;
    uninstall)
      systemctl --user disable --now "$TIMER" >/dev/null 2>&1 || true
      rm -f "$UNIT_DIR/$SERVICE" "$UNIT_DIR/$TIMER"
      systemctl --user daemon-reload 2>/dev/null || true
      printf 'timer[2]{unit,state}:\n  "%s","removed"\n' "$UNIT_DIR/$TIMER"
      exit 0 ;;
    status)
      printf 'timer[3]{unit,active,next}:\n  "%s","%s","%s"\n' "$UNIT_DIR/$TIMER" "$(systemctl --user is-active "$TIMER" 2>/dev/null | head -1 || true)" ""
      exit 0 ;;
  esac
fi

if [ -f "$STATE/.seal-hold" ]; then
  printf 'ship-watch[1]{status}:\n  "seal-hold present — nothing merged"\n'
  exit 0
fi

# 1 · this machine must NAME the door · 2 · only the operator's own repositories · 3 · its own identity
warden_require_door || exit 3
warden_require_identity || exit 3

# list reviewer-merges projects
mapfile -t REPOS < <(python3 - "$PROJECTS" <<'PY'
import sys,yaml
try:
    cfg=yaml.safe_load(open(sys.argv[1])) or {}
except Exception:
    cfg={}
for p in (cfg.get("projects") or []):
    g=p.get("git") or {}
    if (p.get("delivery") or "operator-merges")=="reviewer-merges":
        owner=g.get("owner") or ""
        repo=g.get("repo") or ""
        if owner and repo:
            print(f"{owner}/{repo}")
PY
)

for repo in "${REPOS[@]}"; do
  [ -n "$repo" ] || continue
  warden_require_repos "$repo" || continue
  prs="$(gh pr list -R "$repo" --state open --limit 100 --json number,headRefOid,mergeable,isDraft,statusCheckRollup 2>/dev/null)" || continue
  [ -n "$prs" ] || prs="[]"
  python3 - "$prs" <<'PY' | while IFS=$'\t' read -r num head mergeable draft ci; do
import json,sys
prs=json.loads(sys.argv[1])
for p in prs:
    checks=p.get("statusCheckRollup") or []
    concl=[c.get("conclusion") or c.get("state") or "?" for c in checks]
    if not concl: ci="none"
    elif any(c in ("FAILURE","ERROR","CANCELLED","TIMED_OUT") for c in concl): ci="red"
    elif any(c in ("PENDING","IN_PROGRESS","QUEUED","") for c in concl): ci="pending"
    else: ci="green"
    print("\t".join([str(p.get("number")),p.get("headRefOid") or "",p.get("mergeable") or "UNKNOWN","true" if p.get("isDraft") else "false",ci]))
PY
    [ -n "$num" ] || continue
    # verdict file
    vfile="$STATE/eindri-reports/pr-$num-review.md"
    verdict=""; reviewed=""
    if [ -r "$vfile" ]; then verdict="$(head -1 "$vfile" | tr -d '\r')"; reviewed="$(grep -oE '\b[0-9a-f]{40}\b' "$vfile" | head -1)"; fi
    # decide
    action="waited for a verdict"
    if [ "$mergeable" = "BEHIND" ]; then action="rebased"; fi
    if [ "$mergeable" = "DIRTY" ]; then action="conflicts settled"; fi
    # ship if proved — and a ship that merges needs the THREE yeses of plan 290 rule 5: the door's
    # `merge: on`, the heart's own machine, and bin/forge/merge-verdict.sh saying yes for this PR.
    if [ "$draft" != "true" ] && [ "$mergeable" = "MERGEABLE" ] && { [ "$ci" = "green" ] || [ "$ci" = "none" ]; } && [ -n "$verdict" ] && [[ "$verdict" == PASS* ]] && { [ -z "$reviewed" ] || [ "$reviewed" = "$head" ]; }; then
      if [ "$DRY" = 1 ]; then
        action="would merge"
      elif ! warden_merge_allowed "$num"; then
        action="refused — merge not allowed here (see above)"
        warden_runes refused "refused to merge PR $num on $repo — the three yeses of plan 290 rule 5 were not all present" >/dev/null || true
      else
        WARDEN_REPOS="$repo"
        "$SHIP" "$num" --repo "$repo" >/dev/null 2>&1 && action="merged" || action="refused"
        case "$action" in
          merged) warden_runes merged "merged PR $num on $repo at ${head:0:12} — ci $ci, verdict PASS, merge-verdict yes" >/dev/null || true ;;
          *) warden_runes refused "bin/forge/ship.sh refused PR $num on $repo" >/dev/null || true ;;
        esac
      fi
    fi
    printf 'ship-watch[4]{pr,action,sha,reason}:\n  "%s","%s","%s","%s"\n' "$num" "$action" "${head:0:12}" "$verdict"
  done
done
exit 0
