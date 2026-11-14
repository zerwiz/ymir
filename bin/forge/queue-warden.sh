#!/usr/bin/env bash
# queue-warden.sh — PR HYGIENE: five open at most, the stale ones named, a conflicting branch
# re-cut onto main under a NEW name and pushed to nobody's branch.
#
# IT NEVER MERGES. It never force-pushes, never commits with --no-verify, never closes another
# hand's work, and never writes to GitHub as a person.
#
# WHY (plan 290, 2026-11-14 11:38 CET — the heart's ruling): a dev machine's clock was deciding
# what reached main, under the operator's own GitHub login, with the whole-tree gate red and
# untested major bumps next in its queue. The record of what this door used to do, and why it
# stopped, is docs/fixes/forge/2026-11-14-the-warden-stopped-merging.md (RULES/06, RULES/11).
#
# Usage
#   queue-warden.sh run [--dry-run] [--pr N] [--cap N] [--stale-hours H] [--no-recut]
#   queue-warden.sh status                       # the policy it resolved, and the clock's state
#   queue-warden.sh --install-timer [--start]    # seat the unit; start it only if asked
#   queue-warden.sh --uninstall-timer | --timer-status
#   queue-warden.sh --version | --help
#
# The policy lives in the operator's home, one file per machine (plan 290 §3):
#   $YMIR_HOME/config/machines/<machine>/wardens.yaml
#     queue-warden:
#       max_open_prs: 5        # the cap this warden reports against
#       stale_hours: 48        # a PR older than this is flagged, never closed
#       identity: <name>       # the machine's own identity — never a person's login
#       token_ref: <VAULT_KEY> # the vault key holding THAT identity's token
# A missing file is not a fault: the defaults below stand and the warden says so.
set -u
VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"

usage() { sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; }

CMD="run"; DRY=0; PR_ONLY=""; CAP=""; STALE_HOURS=""; RECUT=1; START_TIMER=0; TIMER_ACTION=""
while [ $# -gt 0 ]; do
  case "$1" in
    run) CMD="run"; shift ;;
    status) CMD="status"; shift ;;
    --dry-run) DRY=1; shift ;;
    --pr) PR_ONLY="${2:-}"; shift 2 ;;
    --pr=*) PR_ONLY="${1#--pr=}"; shift ;;
    --cap) CAP="${2:-}"; shift 2 ;;
    --cap=*) CAP="${1#--cap=}"; shift ;;
    --stale-hours) STALE_HOURS="${2:-}"; shift 2 ;;
    --stale-hours=*) STALE_HOURS="${1#--stale-hours=}"; shift ;;
    --no-recut) RECUT=0; shift ;;
    --install-timer) TIMER_ACTION=install; shift ;;
    --start) START_TIMER=1; shift ;;
    --uninstall-timer) TIMER_ACTION=uninstall; shift ;;
    --timer-status) TIMER_ACTION=status; shift ;;
    -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'queue-warden: unknown argument %s (try --help)\n' "$1" >&2; exit 2 ;;
  esac
done

# ── the home, and the machine this warden belongs to ─────────────────────────────────────────
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
HOME_DIR=""; ymir_home_root HOME_DIR 2>/dev/null || true
STATE=""; hoard_state_dir STATE 2>/dev/null || true
[ -n "$HOME_DIR" ] && [ -n "$STATE" ] || { printf 'queue-warden: home/state unresolved — a warden with no record must not act\n' >&2; exit 1; }
MACHINE="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
[ -n "$MACHINE" ] || MACHINE="unknown"

# ── the policy: the operator's home first, then the documented defaults ──────────────────────
WARDENS="$HOME_DIR/config/machines/$MACHINE/wardens.yaml"
policy_get() {  # <key> — a scalar under the `queue-warden:` block; empty when absent
  [ -r "$WARDENS" ] || return 0
  awk -v k="$1" '
    /^[^[:space:]#]/ { blk = ($1 == "queue-warden:") ; next }
    blk && $1 == k":" {
      v = $0; sub(/^[^:]*:[[:space:]]*/, "", v); sub(/[[:space:]]+#.*$/, "", v); print v; exit
    }' "$WARDENS" 2>/dev/null | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}
[ -n "$CAP" ] || CAP="$(policy_get max_open_prs)"
[ -n "$CAP" ] || CAP=5
[ -n "$STALE_HOURS" ] || STALE_HOURS="$(policy_get stale_hours)"
[ -n "$STALE_HOURS" ] || STALE_HOURS=48
IDENTITY="$(policy_get identity)"; [ -n "$IDENTITY" ] || IDENTITY="unnamed"
TOKEN_REF="$(policy_get token_ref)"

# ── the identity (plan 290 rule 4) ───────────────────────────────────────────────────────────
# The warden WRITES under the machine's own identity or not at all. A person's login on this box
# is never its hand: if the home names no credential, the re-cut is made locally and the push is
# recorded as owed — never done as whoever happens to be logged in.
MACHINE_TOKEN=""
if [ -n "$TOKEN_REF" ] && [ -r "$ROOT/bin/vault/hodd.sh" ]; then
  MACHINE_TOKEN="$(bash "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null | python3 -c '
import shlex, sys
want = sys.argv[1]
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("export "):
        continue
    name, _, value = line[len("export "):].partition("=")
    if name != want:
        continue
    try:
        print(shlex.split(value)[0] if value.strip() else "")
    except ValueError:
        print(value.strip().strip("\""))
    break' "$TOKEN_REF" 2>/dev/null || true)"
fi
CREDENTIAL="absent"
[ -n "$MACHINE_TOKEN" ] && CREDENTIAL="machine"
[ -n "$TOKEN_REF" ] || TOKEN_REF="-"

# ── the clock (a user timer; seated only when asked, started only when asked) ────────────────
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE="queue-warden.service"; TIMER="queue-warden.timer"
if [ -n "$TIMER_ACTION" ]; then
  case "$TIMER_ACTION" in
    install)
      # the unit is the register's (.agents/config/units.yaml: queue-warden) and the one writer
      # renders it against the PINNED runtime, never the tree this door ran from (plan 269)
      bash "$ROOT/bin/engine/units.sh" write queue-warden --no-restart >/dev/null \
        || { printf 'queue-warden: units.sh could not write the unit\n' >&2; exit 1; }
      systemctl --user daemon-reload 2>/dev/null || true
      # SEATING IS NOT STARTING. A warden's clock is a decision the operator (or the heart) makes
      # for this machine (plan 290 rule 1); `--start` is that decision and nothing else is.
      if [ "$START_TIMER" = 1 ]; then
        systemctl --user enable --now "$TIMER" 2>&1 | tail -2 || true
        STARTED="started (--start)"
      else
        systemctl --user disable "$TIMER" >/dev/null 2>&1 || true
        STARTED="seated, stopped — pass --start to run it"
      fi
      printf 'timer[4]{unit,interval,state,why}\n  "%s","10min","%s","%s"\n' "$UNIT_DIR/$TIMER" "$STARTED" \
        "$(systemctl --user is-active "$TIMER" 2>/dev/null | head -1 || true)"
      exit 0 ;;
    uninstall)
      systemctl --user disable --now "$TIMER" >/dev/null 2>&1 || true
      rm -f "$UNIT_DIR/$SERVICE" "$UNIT_DIR/$TIMER"
      systemctl --user daemon-reload 2>/dev/null || true
      printf 'timer[2]{unit,state}\n  "%s","removed"\n' "$UNIT_DIR/$TIMER"
      exit 0 ;;
    status)
      printf 'timer[3]{unit,active,enabled}\n  "%s","%s","%s"\n' "$UNIT_DIR/$TIMER" \
        "$(systemctl --user is-active "$TIMER" 2>/dev/null | head -1 || true)" \
        "$(systemctl --user is-enabled "$TIMER" 2>/dev/null | head -1 || true)"
      exit 0 ;;
  esac
fi

timer_state() {
  local a e
  a="$(systemctl --user is-active "$TIMER" 2>/dev/null | head -1 || true)"
  e="$(systemctl --user is-enabled "$TIMER" 2>/dev/null | head -1 || true)"
  printf '%s/%s' "${a:-absent}" "${e:-absent}"
}

if [ "$CMD" = "status" ]; then
  printf 'queue-warden[9]{host,identity,credential,cap,stale_hours,recut,policy_from,timer,merges}\n'
  printf '  "%s","%s","%s","%s","%s","%s","%s","%s","never"\n' "$MACHINE" "$IDENTITY" "$CREDENTIAL" "$CAP" \
    "$STALE_HOURS" "$([ "$RECUT" = 1 ] && echo on || echo off)" \
    "$([ -r "$WARDENS" ] && echo "home/config/machines/$MACHINE/wardens.yaml" || echo defaults)" \
    "$(timer_state)"
  exit 0
fi

# ── the reading: gh is a LENS here, never a hand ─────────────────────────────────────────────
command -v gh >/dev/null 2>&1 || { printf 'queue-warden: gh missing — a warden that cannot read a PR says nothing\n' >&2; exit 1; }
if [ "$CREDENTIAL" = "machine" ]; then
  export GH_TOKEN="$MACHINE_TOKEN"
fi
if ! gh auth status >/dev/null 2>&1; then
  printf 'queue-warden: no GitHub door on this machine (gh auth status failed) — refusing rather than reporting nothing\n' >&2
  exit 1
fi
READ_AS="$(gh api user -q .login 2>/dev/null || echo unknown)"
[ "$CREDENTIAL" = "machine" ] && READ_AS="$IDENTITY ($READ_AS)"

# ── the notices (append-only; a notice is never a close) ─────────────────────────────────────
NOTICES="$STATE/queue-warden.notices.log"
STATUS="$STATE/queue-warden.status"
mkdir -p "$STATE" 2>/dev/null || true
STAMP_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
notices=()
notice() {  # <pr> <branch> <kind> <action>
  notices+=("$1|$2|$3|$4")
  printf '%s\t%s\t%s\t%s\t%s\n' "$STAMP_ISO" "$1" "$2" "$3" "$4" >>"$NOTICES" 2>/dev/null || true
}

# ── the re-cut: a NEW branch off the PR's head, rebased onto main, never their branch ────────
# A rebase rewrites history, so it is done on a name nobody owns yet. Their branch is read, never
# written: no force, no --no-verify, no `git add -A`. The push happens only under the machine's own
# identity; without one the re-cut is made and the push is recorded as owed.
recut_one() {  # <pr> <branch>
  local n="$1" branch="$2" slug new wt ok=1 err
  slug="$(printf '%s' "$branch" | tr -c 'a-zA-Z0-9._-' '-' | sed -e 's/^-*//' -e 's/-*$//')"
  new="rehygiene/${n}-${slug}-onto-main-$(date -u +%Y%m%d)"
  if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$new"; then
    notice "$n" "$branch" "recut" "already re-cut today as $new"
    return 0
  fi
  if [ "$DRY" = 1 ]; then
    recut_made=$((recut_made + 1))
    notice "$n" "$branch" "recut" "dry-run: would rebase origin/$branch onto origin/main as $new"
    return 0
  fi
  wt="$ROOT/.yggdrasil/qw-recut-$n"
  if [ -e "$wt" ]; then
    notice "$n" "$branch" "recut" "not re-cut — $wt already stands; this warden never clears another hand's tree"
    return 0
  fi
  if ! git -C "$ROOT" fetch origin --prune >/dev/null 2>&1; then
    notice "$n" "$branch" "recut" "not re-cut — origin could not be fetched"
    return 0
  fi
  if ! git -C "$ROOT" worktree add "$wt" --detach "origin/$branch" >/dev/null 2>&1; then
    notice "$n" "$branch" "recut" "not re-cut — the branch could not be seated in a worktree"
    return 0
  fi
  if git -C "$wt" switch -c "$new" >/dev/null 2>&1; then
    if ! err="$(git -C "$wt" rebase origin/main 2>&1)"; then
      git -C "$wt" rebase --abort >/dev/null 2>&1 || true
      ok=0
    fi
  else
    ok=0; err="the new branch could not be cut"
  fi
  git -C "$ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true
  if [ "$ok" != 1 ]; then
    notice "$n" "$branch" "recut" "not re-cut — two hands disagree in the same file ($(printf '%s' "$err" | grep -m1 -E '^CONFLICT|fatal:|error:' | cut -c1-90))"
    return 0
  fi
  recut_made=$((recut_made + 1))
  if [ "$CREDENTIAL" != "machine" ]; then
    notice "$n" "$branch" "recut" "re-cut locally as $new — push owed: git push origin $new (the home names no machine identity)"
    return 0
  fi
  if err="$(git -C "$ROOT" push origin "refs/heads/$new:refs/heads/$new" 2>&1)"; then
    recut_pushed=$((recut_pushed + 1))
    notice "$n" "$branch" "recut" "re-cut onto main and pushed as $new — open a PR from it when the helm says so"
  else
    notice "$n" "$branch" "recut" "re-cut locally as $new but the push was refused by the wards: $(printf '%s' "$err" | grep -m1 -E 'refus|reject|error|denied' | cut -c1-90)"
  fi
  return 0
}

# ── the open PRs ─────────────────────────────────────────────────────────────────────────────
rows="$(gh pr list --state open --limit 100 \
  --json number,headRefName,createdAt,mergeable,isDraft,author \
  --template '{{range .}}{{.number}}{{"\t"}}{{.headRefName}}{{"\t"}}{{.createdAt}}{{"\t"}}{{.mergeable}}{{"\t"}}{{.isDraft}}{{"\t"}}{{.author.login}}{{"\n"}}{{end}}' 2>/dev/null)" \
  || { printf 'queue-warden: gh pr list failed — nothing read, so nothing claimed\n' >&2; exit 1; }
[ -n "$PR_ONLY" ] && rows="$(printf '%s\n' "$rows" | awk -F'\t' -v n="$PR_ONLY" '$1 == n')"

now_epoch="$(date -u +%s)"
age_hours() {  # <iso>
  local e
  e="$(date -u -d "$1" +%s 2>/dev/null)" || { printf '0'; return; }
  printf '%s' "$(( (now_epoch - e) / 3600 ))"
}

open=0; stale=0; conflicting=0; recut_made=0; recut_pushed=0; blocked=0
declare -a order=()
while IFS=$'\t' read -r num branch created mergeable draft author; do
  [ -n "${num:-}" ] || continue
  open=$((open + 1))
  age="$(age_hours "$created")"
  order+=("$age|$num|$branch")
  [ "$draft" = "true" ] && { notice "$num" "$branch" "draft" "left alone — a draft is not asked for"; continue; }
  if [ "$mergeable" = "CONFLICTING" ]; then
    conflicting=$((conflicting + 1))
    case "$branch" in
      main|master|rehygiene/*)
        notice "$num" "$branch" "conflicting" "not re-cut — a protected or already-re-cut branch" ;;
      dependabot/*)
        notice "$num" "$branch" "conflicting" "not re-cut — a bot's branch is the bot's to tend" ;;
      *)
        case "$author" in
          *"[bot]")
            notice "$num" "$branch" "conflicting" "not re-cut — a bot's branch is the bot's to tend" ;;
          *)
            if [ "$RECUT" = 1 ]; then
              recut_one "$num" "$branch"
            else
              notice "$num" "$branch" "conflicting" "re-cut skipped (--no-recut); rebase onto origin/main is owed"
            fi ;;
        esac ;;
    esac
  fi
  if [ "$age" -ge "$STALE_HOURS" ]; then
    stale=$((stale + 1))
    notice "$num" "$branch" "stale" "open ${age}h — flagged; the helm decides, this warden never closes"
  fi
done <<<"$rows"

# ── the cap: reported, never enforced by closing another hand's work ─────────────────────────
over=0
[ "$open" -gt "$CAP" ] && over=$((open - CAP))
if [ "$over" -gt 0 ]; then
  while IFS='|' read -r age num branch; do
    [ -n "${num:-}" ] || continue
    notice "$num" "$branch" "over-cap" "open ${age}h — ${over} beyond the cap of ${CAP}; review it, do not merge it blind"
  done < <(printf '%s\n' "${order[@]}" | sort -t'|' -k1,1nr | head -n "$over")
fi

# ── the pass, written down ───────────────────────────────────────────────────────────────────
{
  printf 'stamp\t%s\n' "$STAMP_ISO"
  printf 'host\t%s\n' "$MACHINE"
  printf 'identity\t%s\n' "$IDENTITY"
  printf 'credential\t%s\n' "$CREDENTIAL"
  printf 'read_as\t%s\n' "$READ_AS"
  printf 'cap\t%s\n' "$CAP"
  printf 'open\t%s\n' "$open"
  printf 'merges\t0\n'
} >"$STATUS" 2>/dev/null || true

printf 'warden-pass[10]{host,read_as,credential,identity,cap,open,over_cap,stale,conflicting,merges}\n'
printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s","0"\n' "$MACHINE" "$READ_AS" "$CREDENTIAL" "$IDENTITY" \
  "$CAP" "$open" "$over" "$stale" "$conflicting"
if [ "${#notices[@]}" -gt 0 ]; then
  printf 'notice[4]{pr,branch,kind,action}\n'
  for n in "${notices[@]}"; do
    IFS='|' read -r p b k a <<<"$n"
    printf '  "%s","%s","%s","%s"\n' "$p" "$b" "$k" "$a"
  done
fi
printf 'recut[3]{made,pushed_with_machine_identity,notes}\n'
printf '  "%s","%s","%s"\n' "$recut_made" "$recut_pushed" "${#notices[@]}"
[ "$DRY" = 1 ] && printf 'dry-run: nothing written to GitHub, nothing merged, no branch touched\n'
exit 0
