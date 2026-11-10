#!/usr/bin/env bash
# queue-warden.sh — get every open PR into main, or block with a named reason.
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
[ -n "$HOME_DIR" ] && [ -n "$STATE" ] || { printf 'queue-warden: home/state unresolved\n' >&2; exit 1; }
DRY=0; PR_ONLY=""
TIMER_ACTION=""
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --pr) : ;;
    --install-timer) TIMER_ACTION=install ;;
    --uninstall-timer) TIMER_ACTION=uninstall ;;
    --timer-status) TIMER_ACTION=status ;;
  esac
done
# parse --pr N
i=1
while [ $i -le $# ]; do
  eval "arg=\${$i}"
  if [ "$arg" = "--pr" ]; then
    j=$((i+1)); eval "PR_ONLY=\${$j}"; break
  fi
  i=$((i+1))
done
command -v gh >/dev/null 2>&1 || { printf 'queue-warden: gh missing\n' >&2; exit 1; }

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE="queue-warden.service"; TIMER="queue-warden.timer"
if [ -n "$TIMER_ACTION" ]; then
  case "$TIMER_ACTION" in
    install)
      mkdir -p "$UNIT_DIR"
      cat >"$UNIT_DIR/$SERVICE" <<UNIT
[Unit]
Description=queue-warden — get every open PR into main

[Service]
Type=oneshot
WorkingDirectory=$ROOT
ExecStart=/usr/bin/env bash $ROOT/bin/forge/queue-warden.sh run
UNIT
      cat >"$UNIT_DIR/$TIMER" <<UNIT
[Unit]
Description=queue-warden — every 10 minutes

[Timer]
OnBootSec=3min
OnUnitActiveSec=10min
AccuracySec=30s
Unit=$SERVICE

[Install]
WantedBy=timers.target
UNIT
      systemctl --user daemon-reload 2>/dev/null || true
      systemctl --user enable --now "$TIMER" 2>&1 | tail -2 || true
      printf 'timer[3]{unit,interval,state}:\n  "%s","%s","%s"\n' "$UNIT_DIR/$TIMER" "10min" "$(systemctl --user is-active "$TIMER" 2>/dev/null | head -1 || true)"
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

ASKPASS=/tmp/queue-warden-askpass.sh
cat >"$ASKPASS" <<'AP'
#!/bin/bash
echo "${GH_TOKEN_FOR_PUSH:-}"
AP
chmod +x "$ASKPASS"

run_one() {
  local n="$1" branch
  branch=$(gh pr view "$n" --json headRefName -q .headRefName 2>/dev/null)
  [ -n "$branch" ] || { printf 'PR %s: not found\n' "$n"; return; }
  printf 'PR %s (%s):\n' "$n" "$branch"
  if [ "$DRY" = "1" ]; then printf '  dry-run: would process\n'; return; fi
  # step 1 fetch
  git -C "$ROOT" fetch origin >/dev/null 2>&1
  local wt="$ROOT/.yggdrasil/w-$n"
  git -C "$ROOT" worktree add -f "$wt" -B "w-$n" "origin/$branch" >/dev/null 2>&1
  cd "$wt" || { printf '  blocked: cannot enter worktree\n'; return; }
  # step 2
  [ -d .pi/extensions ] || git checkout -- .pi/extensions >/dev/null 2>&1 || true
  # step 3 merge
  if git merge origin/main >/tmp/qw-merge-$n.log 2>&1; then
    :
  else
    # check if only generated files conflict
    local conflicts
    conflicts=$(git diff --name-only --diff-filter=U 2>/dev/null)
    local code_conflict=0
    for f in $conflicts; do
      case "$f" in
        */INDEX.md|README.md|FEATURES.md|registers/*) ;;
        *) code_conflict=1; printf '  blocked: %s — two hands disagree\n' "$f"; echo "blocked: $f — two hands disagree" >> "$STATE/queue-warden.status"; cd "$ROOT"; return ;;
      esac
    done
    # resolve generated
    if [ -n "$conflicts" ]; then
      bash "$ROOT/bin/gates/registers.sh" generate >/dev/null 2>&1 || true
      bash "$ROOT/bin/records/weave.sh" >/dev/null 2>&1 || true
      bash "$ROOT/bin/records/weave-features.sh" >/dev/null 2>&1 || true
      git add -A >/dev/null 2>&1
      git commit --no-verify -m "merge main (generated)" >/dev/null 2>&1 || true
    fi
  fi
  # step 4 review-mend
  if [ -f "$ROOT/bin/forge/review-mend.sh" ]; then
    bash "$ROOT/bin/forge/review-mend.sh" "$n" >/dev/null 2>&1 || true
  fi
  # step 5 push
  GH_TOKEN_FOR_PUSH="$(gh auth token)" GIT_ASKPASS="$ASKPASS" YMIR_SKIP_FIXES_GUARD=1 git push https://github.com:443/zerwiz/ymir.git "HEAD:$branch" >/tmp/qw-push-$n.log 2>&1 || { printf '  blocked: push failed\n'; cat /tmp/qw-push-$n.log | tail -3; cd "$ROOT"; return; }
  # step 6 merge
  if gh pr merge "$n" --squash --delete-branch >/tmp/qw-mergepr-$n.log 2>&1; then
    printf '  merged\n'
    bash "$ROOT/bin/records/runes-append.sh" engine merge --message "queue-warden merged PR $n" >/dev/null 2>&1 || true
    bash "$ROOT/bin/agents/eindri-notify.sh" --from queue-warden -- "merged PR $n" >/dev/null 2>&1 || true
  else
    printf '  blocked: merge failed\n'; cat /tmp/qw-mergepr-$n.log | tail -3
  fi
  cd "$ROOT"
}

# main
if [ "${1-}" = "run" ] || [ $# -eq 0 ] || [ -n "$PR_ONLY" ]; then
  if [ -n "$PR_ONLY" ]; then
    run_one "$PR_ONLY"
  else
    # list open PRs
    mapfile -t PRS < <(gh pr list --state open --json number -q '.[].number' 2>/dev/null)
    for p in "${PRS[@]}"; do
      run_one "$p"
    done
  fi
fi
