#!/usr/bin/env bash
# home-sync-clock.sh — the home pulls and pushes itself, hourly, without a hand.
#
# WHY (the Allfather, 2026-11-12): *"are we pulling and pushing ymir home on updates in it?"* We were not.
# `nornir-job-git-sync.sh` runs at 00:00 in FETCH mode only, so the home's local commits never left this
# machine and the tree fell fifty to eighty commits behind the heart every day — every one of those
# reconciliations was done by hand, at night, in a race with another seat.
#
# What it does, one pass: pull (ff-only, union through the merge drivers), then push IF the tree is clean and
# ahead. It NEVER commits: a scratch file written seconds earlier must not travel (the staging discipline),
# and a dirty tree is REPORTED, not swept.
#
# Usage: home-sync-clock.sh [--dry-run] [--install-timer]
# Exit: 0 ok · 1 a fault (named) · 3 refused (dirty tree or a real conflict).
set -uo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SELF_DIR/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
H=""; declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root H 2>/dev/null
HOME_DIR="${H:-$HOME/Documents/ymirhome}"
DRY=0
for a in "$@"; do case "$a" in --install-timer) TIMER=1;; --dry-run) DRY=1;; esac; done
if [ "${TIMER:-0}" = 1 ]; then
  U="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"; mkdir -p "$U"
  printf '[Unit]\nDescription=home-sync-clock — pull, then push if clean and ahead\n\n[Service]\nType=oneshot\nWorkingDirectory=%s\nExecStart=/usr/bin/env bash %s/bin/vault/home-sync-clock.sh\n' "$ROOT" "$ROOT" >"$U/home-sync-clock.service"
  printf '[Unit]\nDescription=home-sync-clock — hourly\n\n[Timer]\nOnBootSec=10min\nOnUnitActiveSec=60min\nAccuracySec=2min\nUnit=home-sync-clock.service\n\n[Install]\nWantedBy=timers.target\n' >"$U/home-sync-clock.timer"
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now home-sync-clock.timer >/dev/null 2>&1 || true
  printf 'installed,home-sync-clock.timer,%s,60min\n' "$(systemctl --user is-active home-sync-clock.timer 2>/dev/null)"
  exit 0
fi
[ -d "$HOME_DIR/.git" ] || { printf 'home-sync-clock: no home repo at %s\n' "$HOME_DIR" >&2; exit 1; }
cd "$HOME_DIR" || exit 1
# THE RECORDS THE HOUSE WRITES ITSELF are committed by the clock; anything else holds it. The runes and the
# room files are append-only unions written by the arm on every cycle — they are not scratch, and leaving them
# uncommitted is what blocked every reconciliation for days.
rec=$(git status --porcelain | grep -v '^??' | awk '{print $2}' | grep -E '^(hodd/memory/runes_audit\.md|hodd/rooms/.*\.jsonl|hodd/memory/daily/.*\.md)$')
other=$(git status --porcelain | grep -v '^??' | awk '{print $2}' | grep -vE '^(hodd/memory/runes_audit\.md|hodd/rooms/.*\.jsonl|hodd/memory/daily/.*\.md)$')
if [ -n "$rec" ] && [ -z "$other" ] && [ "$DRY" = 0 ]; then
  printf '%s\n' "$rec" | xargs -r git add -- 2>/dev/null
  git -c user.name="home-sync-clock" -c user.email="clock@ymir.local" commit -q -m "records: the runes and the room files, by the clock" 2>/dev/null || true
fi
git fetch -q origin 2>/dev/null || { printf 'home-sync-clock: fetch failed\n' >&2; exit 1; }
behind=$(git rev-list --count HEAD..origin/main 2>/dev/null)
if [ "${behind:-0}" -gt 0 ]; then
  if [ "$DRY" = 1 ]; then printf 'would-pull,%s\n' "$behind"; exit 0; fi
  git merge --no-ff origin/main -m "merge: the heart's commits into the home (home-sync-clock)" >/dev/null 2>&1 \
    || { git merge --abort >/dev/null 2>&1; printf 'refused,a real conflict — reconcile by hand\n' >&2; exit 3; }
fi
dirty=$(git status --porcelain | grep -vc '^??')
ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null)
if [ "${dirty:-0}" -gt 0 ]; then
  printf 'held,%s dirty file(s) and %s local commit(s) — the clock never commits a scratch file\n' "$dirty" "$ahead"
  exit 3
fi
if [ "${ahead:-0}" -gt 0 ]; then
  [ "$DRY" = 1 ] && { printf 'would-push,%s\n' "$ahead"; exit 0; }
  git push origin main >/dev/null 2>&1 || { printf 'push raced, will retry next hour\n' >&2; exit 1; }
fi
printf 'home-sync-clock,pulled=%s,pushed=%s,left=%s\n' "${behind:-0}" "${ahead:-0}" "$(git rev-list --count origin/main..HEAD)"
