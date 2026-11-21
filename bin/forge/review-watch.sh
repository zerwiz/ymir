#!/usr/bin/env bash
# review-watch.sh — the missing trigger: a PR that arrives is a question the owner is asked.
#
# WHY (plan 206 §10.2, the Allfather's question): *"why isn't the heart reviewing all prs that
# come in on the ymir repo and merging them."* The review SPINE already exists
# (`bin/agents/eindri-review-spawn.sh`) and the judge is real — but the spine's only trigger is
# an errand's own terminal `done`. **Nothing watched the repository**, so a PR opened by another
# hand, or by an agent that never called `acclaim`, was never seen. This is that watch.
#
# WHAT IT DOES, one pass:
#   1 · list the open PRs of the named repos (never guessed: --repo, else YMIR_REVIEW_REPOS,
#       else the one documented default);
#   2 · for each PR not already judged at THIS head, raise ONE ask through `bin/seat/lock-ask.sh`
#       — the owner's own queue — naming the PR, its head, its CI and its mergeability;
#   3 · mark the (PR, head) so a second pass in the same minute raises nothing (the flood brake);
#   4 · `--judge <n>` seats the judge for that PR through the spine, which is the owner's answer.
#
# WHAT IT NEVER DOES: merge, push, comment on GitHub, or decide. A watch that decided would be a
# gate with no judge in it.
#
# Usage:
#   review-watch.sh [--repo owner/repo ...] [--dry-run] [--json] [--all]
#   review-watch.sh --judge <n> [--repo owner/repo]      # the owner's answer: seat the judge
#   review-watch.sh --status                             # what the watch sees, and what it raised
#   review-watch.sh --install-timer [--interval 10min]    # the clock: a user timer, every 10 minutes
#   review-watch.sh --timer-status | --uninstall-timer
#   review-watch.sh --keeper [--repo owner/repo ...] [--dry-run]
#        THE KEEPER'S ROAD (RULES/08, 2026-11-21): every open PR in the house's repositories (the
#        registry's git{} blocks) with no verdict for its CURRENT head gets the judge — ONE judge at a
#        time on this machine (the fleet runbook: the heart runs one Eindri); while a judge is in
#        flight the next PR is handed to a developer seat over the arm wire. Each pass first carries
#        out the verdicts already written (bin/forge/judge-merge.sh sweep): APPROVE merges at once.
#        On the heart the keeper is the default road (YMIR_REVIEW_KEEPER=auto|1|0).
#
# Exit: 0 judged · 1 a fault (named) · 2 usage · 3 refused (no identity / no owner).
set -u
VERSION="1.0.0"
SELF="$(basename "$0")"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
STATE=""; hoard_state_dir STATE 2>/dev/null || true
[ -n "$STATE" ] || { printf 'review-watch: the state dir is unresolved\n' >&2; exit 1; }

LOCK_ASK="$ROOT/bin/seat/lock-ask.sh"
SPINE="$ROOT/bin/agents/eindri-review-spawn.sh"
# Rule 07: the repos are configuration with ONE documented default.
DEFAULT_REPOS="${YMIR_REVIEW_REPOS:-zerwiz/ymir}"

die()    { printf 'review-watch: %s\n' "$*" >&2; exit 1; }
usage()  { printf 'review-watch: %s\n' "$*" >&2; exit 2; }
refuse() { printf 'review-watch: REFUSED — %s\n' "$*" >&2; exit 3; }

REPOS=(); DRY=0 JSON=0 ALL=0 JUDGE=""; STATUS_ONLY=0; KEEPER_FLAG=0
TIMER_ACTION=""; TIMER_INTERVAL="3min"
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPOS+=("${2:-}"); shift 2 ;;
    --repo=*) REPOS+=("${1#--repo=}"); shift ;;
    --judge) JUDGE="${2:-}"; shift 2 ;;
    --judge=*) JUDGE="${1#--judge=}"; shift ;;
    --dry-run) DRY=1; shift ;;
    --json) JSON=1; shift ;;
    --all) ALL=1; shift ;;
    --keeper) KEEPER_FLAG=1; shift ;;
    --status) STATUS_ONLY=1; shift ;;
    --install-timer) TIMER_ACTION=install; shift ;;
    --uninstall-timer) TIMER_ACTION=uninstall; shift ;;
    --timer-status) TIMER_ACTION=status; shift ;;
    --interval) TIMER_INTERVAL="${2:-10min}"; shift 2 ;;
    --interval=*) TIMER_INTERVAL="${1#--interval=}"; shift ;;
    -*) usage "unknown flag $1" ;;
    *) usage "unexpected argument $1" ;;
  esac
done
# ── is this pass the keeper's? (RULES/08, 2026-11-21) ───────────────────────────────────────────
machine_roles() {
  bash "$ROOT/bin/fleet/topology.sh" --json 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print(",".join(d.get("roles") or []))' 2>/dev/null || true
}
KEEPER=0
case "${YMIR_REVIEW_KEEPER:-auto}" in
  1|on) KEEPER=1 ;;
  0|off) KEEPER=0 ;;
  *) case ",$(machine_roles)," in *,heart,*) KEEPER=1 ;; esac ;;
esac
[ "$KEEPER_FLAG" = 1 ] && KEEPER=1
[ -n "$JUDGE" ] || [ -n "$TIMER_ACTION" ] && KEEPER=0
if [ "${#REPOS[@]}" -eq 0 ] && [ "$KEEPER" = 1 ] && [ -z "${YMIR_REVIEW_REPOS:-}" ]; then
  # the keeper watches only the KEPT repositories: owned by the operator's own login (read from the
  # home), or marked `git.keep: true` in the registry. A registry row may name an upstream the house
  # merely tracks; the keeper never judges, comments or merges there (review of #863, 2026-11-21).
  mapfile -t REPOS < <(python3 "$ROOT/bin/forge/warden-policy.py" kept 2>/dev/null | sed -n 's/^  "\(.*\)"$/\1/p')
  [ "${#REPOS[@]}" -gt 0 ] || die "no repository is kept (warden-policy.py kept: none owned by the operator's login, none marked git.keep: true) — the keeper has nothing it may watch"
fi
if [ "$KEEPER" = 1 ]; then
  # an explicit --repo or YMIR_REVIEW_REPOS is filtered by the same law: a repository that is not kept
  # is dropped by name, never watched
  _kept=()
  for _r in "${REPOS[@]}"; do
    [ -n "$_r" ] || continue
    if python3 "$ROOT/bin/forge/warden-policy.py" keeps "$_r" >/dev/null 2>&1; then _kept+=("$_r")
    else printf 'review-watch: %s is not kept (not the operator'"'"'s own, not git.keep: true) — the keeper leaves it alone\n' "$_r" >&2; fi
  done
  REPOS=("${_kept[@]}"); unset _kept _r
  [ "${#REPOS[@]}" -gt 0 ] || die "no kept repository is left to watch"
fi
if [ "${#REPOS[@]}" -eq 0 ]; then
  # shellcheck disable=SC2206
  IFS=', ' read -r -a REPOS <<<"$DEFAULT_REPOS"
fi

command -v gh >/dev/null 2>&1 || refuse "gh is not on PATH here — a watch with no GitHub door sees nothing, and must not say 'nothing to do'"
# plan 290 §3 — the shared law every outward door keeps (bin/forge/warden-lib.sh): this machine must
# NAME the door, every repository must be the operator's, and the hand must be the identity it names.
. "$ROOT/bin/forge/warden-lib.sh"
warden_begin review-watch || die "this machine cannot be named from the fleet registry"
warden_require_door || exit 3
WARDEN_REPOS="${REPOS[*]}"
warden_require_repos "${REPOS[@]}" || exit 3
warden_require_identity || exit 3
if ! gh auth status >/dev/null 2>&1; then
  refuse "this seat has NO working GitHub identity (gh auth status failed) — the watch cannot read a PR, so it refuses rather than reporting an empty repository"
fi


# ── the clock (plan 206 §6 M4) ───────────────────────────────────────────────────────────────
# A watch nobody runs is a watch that does not exist. The unit is a USER timer: no listener, no
# root, and it runs the same command a human runs — so a quiet hour is a quiet hour and not a
# stopped loop.
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE="review-watch.service"; TIMER="review-watch.timer"
if [ -n "$TIMER_ACTION" ]; then
  case "$TIMER_ACTION" in
    install)
      # plan 290 rule 1: seating is the operator's decision for THIS machine, not the door's.
      warden_seat_allowed review-watch || exit 3
      # the unit is the register's (config/units.yaml: review-watch) and the one writer renders it against the
      # PINNED runtime, never the tree this door ran from (plan 269)
      bash "$ROOT/bin/engine/units.sh" write review-watch --set "REVIEW_INTERVAL=$TIMER_INTERVAL" --no-restart >/dev/null || { printf 'review: units.sh could not write the unit\n' >&2; exit 1; }
      systemctl --user daemon-reload 2>/dev/null || true
      systemctl --user enable --now "$TIMER" 2>&1 | tail -2 || die "the timer could not be enabled — the unit is written at $UNIT_DIR/$TIMER"
      printf 'timer[3]{unit,interval,state}:\n  "%s","%s","%s"\n' "$UNIT_DIR/$TIMER" "$TIMER_INTERVAL" \
        "$(systemctl --user is-active "$TIMER" 2>/dev/null | head -1 || true)"
      exit 0 ;;
    uninstall)
      systemctl --user disable --now "$TIMER" >/dev/null 2>&1 || true
      rm -f "$UNIT_DIR/$SERVICE" "$UNIT_DIR/$TIMER"
      systemctl --user daemon-reload 2>/dev/null || true
      printf 'timer[2]{unit,state}:\n  "%s","removed"\n' "$UNIT_DIR/$TIMER"
      exit 0 ;;
    status)
      printf 'timer[3]{unit,active,next}:\n  "%s","%s","%s"\n' "$UNIT_DIR/$TIMER" \
        "$(systemctl --user is-active "$TIMER" 2>/dev/null | head -1 || true)" \
        "$(systemctl --user list-timers "$TIMER" --no-pager 2>/dev/null | sed -n '2p' | awk '{print $1, $2, $3}')"
      exit 0 ;;
  esac
fi

# ── the owner's answer: seat the judge ────────────────────────────────────────────────────────
if [ -n "$JUDGE" ]; then
  [ -x "$SPINE" ] || die "the review spine is missing at $SPINE"
  # The repo of the PR is resolved from the one repo that answers for it.
  url=""
  for r in "${REPOS[@]}"; do
    [ -n "$r" ] || continue
    if gh pr view "$JUDGE" -R "$r" --json number >/dev/null 2>&1; then
      url="https://github.com/$r/pull/$JUDGE"; break
    fi
  done
  [ -n "$url" ] || refuse "PR #$JUDGE is not readable in ${REPOS[*]} — nothing is seated for a PR that cannot be read"
  SEAT="$ROOT/bin/forge/review-seat.sh"
  if [ "$DRY" = 1 ]; then
    printf 'review-watch[3]{judge,road,would_run}:\n  "%s","%s","%s"\n' "$JUDGE" \
      "$([ -x "$SEAT" ] && echo "pi in herdr (review-seat.sh)" || echo "the spine (einherjar spawn)")" \
      "$([ -x "$SEAT" ] && echo "review-seat.sh ensure && review-seat.sh ask $JUDGE" || echo "$SPINE --pr $url")"
    exit 0
  fi
  # THE ALLFATHER'S ROAD (2026-11-06): *"make so we're using the pi harness in herdr for this work."*
  # The seated judge is a pi agent in a herdr pane on the review clone; the spine's einherjar spawn
  # is the fallback for a machine with no herdr seat.
  if [ -x "$SEAT" ] && [ "${HERDR_ENV:-}" = 1 ]; then
    "$SEAT" ensure >/dev/null 2>&1 || die "the review seat could not be raised — review-seat.sh ensure names why"
    exec "$SEAT" ask "$JUDGE" --wait
  fi
  exec "$SPINE" --pr "$url"
fi

# ── the keeper's pass: a judge for every head, one at a time, and the verdicts carried out ─────
if [ "$KEEPER" = 1 ]; then
  JM="$ROOT/bin/forge/judge-merge.sh"
  [ -x "$JM" ] && { "$JM" sweep $([ "$DRY" = 1 ] && echo --dry-run) || printf 'review-watch: the verdict sweep faulted — read judge-merge.sh sweep\n' >&2; }
  mkdir -p "$STATE/.reviewed" 2>/dev/null || true
  max_age="${YMIR_JUDGE_MAX_AGE:-7200}"
  # how many judges are in flight HERE: a judged record younger than max_age whose review has
  # not written a terminal line since it was seated
  inflight="$(python3 - "$STATE" "$max_age" <<'PY'
import os, sys, time, glob
state, max_age = sys.argv[1], int(sys.argv[2])
n = 0
for side in glob.glob(os.path.join(state, ".reviewed", "*.judged")):
    try: seated = os.stat(side).st_mtime
    except OSError: continue
    if time.time() - seated > max_age: continue
    rid = os.path.basename(side)[:-len(".judged")]
    st = os.path.join(state, rid + ".status")
    done = False
    if os.path.exists(st) and os.stat(st).st_mtime >= seated:
        lines = [l for l in open(st, errors="replace").read().splitlines() if l.strip()]
        done = bool(lines) and lines[-1].split(":", 1)[0].strip() in ("done", "failed", "needs-decision")
    if not done: n += 1
print(n)
PY
)"
  _fleet=""; _fleet_home=""; ymir_home_root _fleet_home 2>/dev/null || true
  _fleet="${YMIR_FLEET_REGISTRY:-$_fleet_home/hodd/data/fleet.json}"
  # the developer seats a review may be handed to: the named one, else every `dev` host but this one
  if [ -n "${YMIR_REVIEW_HANDOFF_HOST:-}" ]; then
    IFS=', ' read -r -a dev_hosts <<<"$YMIR_REVIEW_HANDOFF_HOST"
  else
    mapfile -t dev_hosts < <(python3 - "$_fleet" "$(hostname -s 2>/dev/null)" <<'PY' 2>/dev/null
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: d = {}
for name, h in (d.get("hosts") or {}).items():
    if name != sys.argv[2] and "dev" in (h.get("roles") or []):
        print(name)
PY
)
  fi
  handoff_host="${dev_hosts[0]:-}"
  # can the judge sit HERE? The home names its harness (forseti: harness claude); a machine with no
  # such CLI (the heart has none) seats no judge and hands every review to a developer seat.
  judge_h="$(bash "$ROOT/bin/fleet/agents-config.sh" get forseti harness 2>/dev/null | head -n1)"
  judge_h="${YMIR_REVIEW_HARNESS:-${judge_h:-pi}}"
  seat_here=1
  command -v "$judge_h" >/dev/null 2>&1 || seat_here=0
  [ "${YMIR_REVIEW_SEAT_HERE:-auto}" = 0 ] && seat_here=0
  [ "${YMIR_REVIEW_SEAT_HERE:-auto}" = 1 ] && seat_here=1
  pr_key() {  # <owner/repo> <n> → pr-<owner>--<repo>-<n> (the spine's key, bin/agents/eindri-review-spawn.sh)
    local slug; slug="$(printf '%s' "$1" | tr 'A-Z' 'a-z')"
    printf 'pr-%s--%s-%s' "${slug%%/*}" "${slug#*/}" "$2"
  }
  hand_to() {  # <host> <line> — the arm wire AND a turn typed into the holder's herdr pane
    local h="$1" l="$2" road okw=0
    timeout 60 bash "${YMIR_ARM_SEND_DOOR:-$ROOT/bin/fleet/arm-send.sh}" "$h" "$l" >/dev/null 2>&1 && okw=1
    road="$(python3 - "$_fleet" "$h" <<'PY' 2>/dev/null
import json, sys
try: x = (json.load(open(sys.argv[1])).get("hosts") or {}).get(sys.argv[2]) or {}
except Exception: x = {}
if x.get("user") and x.get("tailnet"): print(f"{x['user']}@{x['tailnet']}")
PY
)"
    [ "${YMIR_NO_INJECT:-0}" = 1 ] && road=""   # a test types into nobody's pane
    if [ -n "$road" ] && timeout 60 ssh -o BatchMode=yes -o ConnectTimeout=6 "$road" \
        "d=\${YMIR_RUNTIME_DIR:-\$HOME/ymir-runtime}; [ -f \$d/bin/agents/eindri-notify.sh ] || d=\$HOME/ymir; cd \$d && bash bin/agents/eindri-notify.sh --from review-watch -- $(printf '%q' "$l")" \
        </dev/null >/dev/null 2>&1; then okw=1; fi
    [ "$okw" = 1 ]
  }
  clone_of() {  # <owner/repo> → the local clone the registry names for it (this tree for its own origin)
    local r="$1" mine
    mine="$(git -C "$ROOT" remote get-url origin 2>/dev/null | sed -E 's#\.git$##; s#^.*github\.com[:/]##' | tr 'A-Z' 'a-z')"
    if [ "$mine" = "$(printf '%s' "$r" | tr 'A-Z' 'a-z')" ]; then printf '%s\n' "${YMIR_REVIEW_PROJECT:-$ROOT}"; return; fi
    python3 - "${PROJECTS_YAML:-$_fleet_home/hodd/identity/projects.yaml}" "$r" "$_fleet_home" <<'PY' 2>/dev/null
import os, sys, yaml
path, want, home = sys.argv[1], sys.argv[2].lower(), sys.argv[3]
try: doc = yaml.safe_load(open(path)) or {}
except Exception: doc = {}
for row in doc.get("projects") or []:
    if not isinstance(row, dict): continue
    g = row.get("git") or {}
    if f"{g.get('owner','')}/{g.get('repo','')}".lower() != want: continue
    for key in ("local_clone", "repo"):
        v = row.get(key)
        if isinstance(v, str) and v:
            p = os.path.expanduser(os.path.expandvars(v.replace("$YMIR_HOME", home)))
            if os.path.isdir(os.path.join(p, ".git")) or os.path.isfile(os.path.join(p, ".git")):
                print(p); sys.exit(0)
PY
  }
  if [ "$seat_here" = 1 ]; then handed_max="${YMIR_REVIEW_HANDOFF_MAX:-1}"; else handed_max="${YMIR_REVIEW_HANDOFF_MAX:-3}"; fi
  handed=0; spawned=0; waiting=0; SEEN=0
  printf 'review-watch[keeper]{repos,inflight,judge_here,handoff}:\n  "%s","%s","%s","%s"\n' "${REPOS[*]}" "$inflight" \
    "$([ "$seat_here" = 1 ] && echo "yes ($judge_h)" || echo "no — no $judge_h CLI here")" "${dev_hosts[*]:-none}"
  for repo in "${REPOS[@]}"; do
    [ -n "$repo" ] || continue
    prs="$(gh pr list -R "$repo" --state open --limit 100 --json number,headRefOid,isDraft,url 2>/dev/null)" \
      || { printf 'review-watch: gh pr list failed for %s — skipped this pass, not called empty\n' "$repo" >&2; continue; }
    while IFS=$'\t' read -r num head url; do
      [ -n "$num" ] || continue
      SEEN=$((SEEN + 1))
      # the PR's one name on the review shelf carries its repository (pr-<owner>--<repo>-<n>), the
      # same key bin/agents/eindri-review-spawn.sh writes — PR #7 of two repositories is two PRs
      key="$(pr_key "$repo" "$num")"
      handed_mark="$STATE/.reviewed/handed-$key.$head"
      # a hand-off nobody acted on EXPIRES (review of #863): after YMIR_REVIEW_HANDOFF_TTL seconds
      # (default 1h) with no judge seated for the head, the marker is dropped and the head handed on
      # again — an unacted hand-off must never leave a head unjudged forever
      if [ -e "$handed_mark" ] && [ ! -e "$STATE/.reviewed/$key.$head" ] \
         && [ $(( $(date +%s) - $(stat -c %Y "$handed_mark" 2>/dev/null || echo 0) )) -ge "${YMIR_REVIEW_HANDOFF_TTL:-3600}" ]; then
        [ "$DRY" = 1 ] || rm -f "$handed_mark"
        printf '  "%s#%s","%s","the hand-off expired with no judge seated — handed on again"\n' "$repo" "$num" "${head:0:12}"
        [ "$DRY" = 1 ] && handed_mark="$handed_mark.expired-dry"
      fi
      # a verdict exists — or is coming — for this head: the spine's marker, any judged record, a handoff
      if [ -e "$STATE/.reviewed/$key.$head" ] || [ -e "$handed_mark" ] \
         || grep -lqs "^head=$head\$" "$STATE/.reviewed/"*.judged; then
        continue
      fi
      if [ "$seat_here" = 1 ] && [ "$inflight" -eq 0 ] && [ "$spawned" -eq 0 ]; then
        # the judge sits in a worktree of THAT repository's clone, never this one's (a judge of
        # another repo inside ymir's tree would fetch the wrong origin)
        proj="$(clone_of "$repo")"
        if [ -z "$proj" ]; then
          printf '  "%s#%s","%s","no local clone of %s is named in the registry (local_clone or repo) — cannot seat a judge here"\n' \
            "$repo" "$num" "${head:0:12}" "$repo"
          waiting=$((waiting + 1)); continue
        fi
        if [ "$DRY" = 1 ]; then
          printf '  "%s#%s","%s","would seat the judge: %s --pr %s --project %s"\n' "$repo" "$num" "${head:0:12}" "$SPINE" "$url" "$proj"
        elif "$SPINE" --pr "$url" --project "$proj" >/dev/null 2>&1; then
          printf '  "%s#%s","%s","the judge is seated"\n' "$repo" "$num" "${head:0:12}"
          warden_runes judge "seated the judge for $repo PR #$num at $head" >/dev/null 2>&1 || true
        else
          printf 'review-watch: the judge could not be seated for %s#%s — the next pass tries again\n' "$repo" "$num" >&2
        fi
        spawned=1; continue
      fi
      if [ "${#dev_hosts[@]}" -gt 0 ] && [ "$handed" -lt "$handed_max" ]; then
        handoff_host="${dev_hosts[$((handed % ${#dev_hosts[@]}))]}"
        # the line carries the repository and its clone, resolved from the registry (the home is the
        # fleet's, so the path is the receiving seat's too): a judge must sit in THAT repo's clone
        hproj="$(clone_of "$repo")"
        line="review PR $url ($repo) at head ${head:0:12} with the judge (harness $judge_h) in a herdr pane on your seat — $([ "$seat_here" = 1 ] && echo "the keeper's judge is busy" || echo "the keeper has no $judge_h CLI"): bin/agents/eindri-review-spawn.sh --pr $url${hproj:+ --project $hproj}"
        if [ "$DRY" = 1 ]; then
          printf '  "%s#%s","%s","would hand to %s"\n' "$repo" "$num" "${head:0:12}" "$handoff_host"
        elif hand_to "$handoff_host" "$line"; then
          printf 'handed to %s at %s\n' "$handoff_host" "$(date -u +%FT%TZ)" >"$handed_mark"
          printf '  "%s#%s","%s","handed to %s (arm wire and pane)"\n' "$repo" "$num" "${head:0:12}" "$handoff_host"
        else
          printf 'review-watch: the hand-off of %s#%s to %s did not land — it waits for the next pass\n' "$repo" "$num" "$handoff_host" >&2
        fi
        handed=$((handed + 1)); continue
      fi
      waiting=$((waiting + 1))
    done < <(printf '%s' "$prs" | python3 -c '
import json, sys
try: prs = json.load(sys.stdin)
except Exception: prs = []
for p in sorted(prs, key=lambda p: p.get("number") or 0):
    if p.get("isDraft"): continue
    print("\t".join([str(p.get("number")), p.get("headRefOid") or "", p.get("url") or ""]))
')
  done
  printf 'review-watch[keeper-pass]{seen,seated,handed,waiting}:\n  "%s","%s","%s","%s"\n' "$SEEN" "$spawned" "$handed" "$waiting"
  exit 0
fi

# ── one pass ──────────────────────────────────────────────────────────────────────────────────
RAISED=0; SEEN=0; SKIPPED=0
rows=()
for repo in "${REPOS[@]}"; do
  [ -n "$repo" ] || continue
  prs="$(gh pr list -R "$repo" --state open --limit 100 \
          --json number,title,headRefOid,mergeable,headRefName,isDraft,statusCheckRollup,author 2>/dev/null)" \
    || die "gh pr list failed for $repo — no PR list, no watch (a refusal, not an empty repo)"
  [ -n "$prs" ] || prs="[]"
  while IFS=$'\t' read -r num title head mergeable branch draft ci author; do
    [ -n "$num" ] || continue
    SEEN=$((SEEN + 1))
    marker="$STATE/.reviewed/raised-pr-$num.$head"
    if [ -f "$marker" ]; then SKIPPED=$((SKIPPED + 1)); continue; fi
    if [ "$draft" = "true" ]; then
      SKIPPED=$((SKIPPED + 1))
      rows+=("$(printf 'pr[6]{repo,n,head,state,why,raised}:\n  "%s","%s","%s","%s","%s","%s"' \
        "$repo" "$num" "${head:0:12}" "$mergeable" "draft — a draft is not offered for review" "no")")
      continue
    fi
    # ── a head that cannot merge is a SMITH's errand, in the code ─────────────────────────────
    # Plan 203 §4: the reviewer never edits, so a CONFLICTING head is a dead end for it. Before
    # this, the loop repeated "CONFLICTING" every ten minutes until a human noticed. The Allfather,
    # 2026-11-07: "this must be in the code to happen automatically." Gated by the same switch, so
    # a dev body never seats a smith on its own; a marker per head stops a re-seat every tick.
    if [ "$mergeable" = "CONFLICTING" ] && [ "${YMIR_REVIEW_SELF:-auto}" != 0 ] && [ "$DRY" != 1 ]; then
      smarker="$STATE/.reviewed/smithed-pr-$num.$head"
      if [ ! -f "$smarker" ]; then
        roles_c="$(bash "$ROOT/bin/fleet/topology.sh" --json 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print(",".join(d.get("roles") or []))' 2>/dev/null || true)"
        case ",$roles_c," in *,heart,*)
          errand="$(sed -e "s|@BRANCH@|${branch:-HEAD}|g" -e "s|@PR@|$num|g" -e "s|@REPO@|$ROOT|g" "$ROOT/bin/forge/conflict-errand.md" 2>/dev/null || true)"
          if [ -n "$errand" ] && [ -x "$ROOT/bin/seat/herdr-run.sh" ] \
             && bash "$ROOT/bin/seat/herdr-run.sh" eindri "conflict-smith-$num" -- "$errand" >/dev/null 2>&1; then
            mkdir -p "$STATE/.reviewed" 2>/dev/null || true
            : >"$smarker" 2>/dev/null || true
            rows+=("$(printf 'pr[6]{repo,n,head,state,why,raised}:\n  "%s","%s","%s","%s","%s","%s"' \
              "$repo" "$num" "${head:0:12}" "$mergeable" "conflicting — a smith was seated to clear it" "yes")")
            continue
          fi ;;
        esac
      fi
    fi
    question="PR #$num ($repo) is open at head ${head:0:12}: mergeable=$mergeable ci=$ci. May I judge it — run the rules floor and the gates here, and give a verdict?"
    if [ "$DRY" = 1 ]; then
      rows+=("$(printf 'pr[6]{repo,n,head,state,why,raised}:\n  "%s","%s","%s","%s","%s","%s"' \
        "$repo" "$num" "${head:0:12}" "$mergeable" "would ask the lock owner" "dry-run")")
      continue
    fi
    if [ -x "$LOCK_ASK" ] && out="$("$LOCK_ASK" ask "$question" --task "pr-$num.$head" --as review-watch 2>&1)"; then
      mkdir -p "$STATE/.reviewed" 2>/dev/null || true
      printf '%s\n' "$out" >"$marker" 2>/dev/null || true
      RAISED=$((RAISED + 1))
      # the first mergeable PR this pass raised — the one the seat will judge if it answers itself
      if [ -z "${FIRST_GOOD:-}" ] && [ "$mergeable" = "MERGEABLE" ]; then FIRST_GOOD="$num"; fi
      rows+=("$(printf 'pr[6]{repo,n,head,state,why,raised}:\n  "%s","%s","%s","%s","%s","%s"' \
        "$repo" "$num" "${head:0:12}" "$mergeable" "asked the lock owner" "yes")")
    else
      # A watch that cannot speak is a fault, said out loud — never a quiet pass.
      printf 'review-watch: the ask for %s #%s was REFUSED: %s\n' "$repo" "$num" "$(printf '%s' "${out:-no output}" | tail -1)" >&2
      rows+=("$(printf 'pr[6]{repo,n,head,state,why,raised}:\n  "%s","%s","%s","%s","%s","%s"' \
        "$repo" "$num" "${head:0:12}" "$mergeable" "the ask was refused" "no")")
    fi
  done < <(printf '%s' "$prs" | python3 -c '
import json, sys
try: prs = json.load(sys.stdin)
except Exception: prs = []
for p in prs:
    checks = p.get("statusCheckRollup") or []
    concl = [c.get("conclusion") or c.get("state") or "?" for c in checks]
    if not concl: ci = "none"
    elif any(c in ("FAILURE", "ERROR", "CANCELLED", "TIMED_OUT") for c in concl): ci = "red"
    elif any(c in ("PENDING", "IN_PROGRESS", "QUEUED", "") for c in concl): ci = "pending"
    else: ci = "green"
    author = (p.get("author") or {}).get("login") or "?"
    print("\t".join([str(p.get("number")), (p.get("title") or "")[:80].replace("\t", " "),
                     p.get("headRefOid") or "", p.get("mergeable") or "UNKNOWN",
                     p.get("headRefName") or "",
                     "true" if p.get("isDraft") else "false", ci, author]))
')
done

if [ "$JSON" = 1 ]; then
  python3 - "$RAISED" "$SEEN" "$SKIPPED" <<'PY'
import json, sys
print(json.dumps({"raised": int(sys.argv[1]), "seen": int(sys.argv[2]), "skipped": int(sys.argv[3])}))
PY
else
  printf 'review-watch[4]{repos,seen,raised,skipped}:\n  "%s","%s","%s","%s"\n' \
    "${REPOS[*]}" "$SEEN" "$RAISED" "$SKIPPED"
  for r in "${rows[@]}"; do printf '%s\n' "$r"; done
fi
[ "$RAISED" -gt 0 ] || [ "$ALL" = 1 ] || true
# 4 · every outward act is a Rune: machine, door, identity, repositories, and the verdict it rested on.
[ "$RAISED" -gt 0 ] && warden_runes asked "raised ${RAISED} ask(s) over ${SEEN} open PR(s) in ${REPOS[*]}" >/dev/null || true

# ── the heart answers its own ask (plan 206 §11.3 #2) ───────────────────────────────────────────
# A headless heart has no interactive primary to answer an ask; the SEAT PRIMARY IS THE REVIEWER.
# So when this machine's role is `heart` and the seat's primary is the reviewer figure, the watch
# answers the ask it just raised and RECORDS that the seat decided for itself — the exception is
# never silent, and it is off on any machine that is not the heart.
#   YMIR_REVIEW_SELF=1   force on   ·  0 force off   ·  auto (default) = heart + reviewer seat only
SELF_MODE="${YMIR_REVIEW_SELF:-auto}"
if [ "$DRY" != 1 ] && [ -z "$JUDGE" ] && [ -n "${FIRST_GOOD:-}" ] && [ "$SELF_MODE" != 0 ]; then
  self_ok=0
  if [ "$SELF_MODE" = 1 ]; then self_ok=1; else
    roles="$(bash "$ROOT/bin/fleet/topology.sh" --json 2>/dev/null       | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print(",".join(d.get("roles") or []))' 2>/dev/null || true)"
    me="$(bash "$ROOT/bin/agents/seat-identity.sh" "$(hostname -s 2>/dev/null || hostname)" 2>/dev/null | head -1 || true)"
    case ",$roles," in *,heart,*) [ "$me" = "forseti" ] && self_ok=1 ;; esac
  fi
  if [ "$self_ok" = 1 ]; then
    printf 'review-watch: the seat answers its own ask for #%s (role heart, primary %s) — recorded\n' \
      "$FIRST_GOOD" "$(bash "$ROOT/bin/agents/seat-identity.sh" "$(hostname -s)" 2>/dev/null | head -1)" >&2
    [ -x "$ROOT/bin/notify/send.sh" ] && bash "$ROOT/bin/notify/send.sh" --source engine --severity INFO \
      --key "review-watch:self-answer:$FIRST_GOOD" \
      --message "review-watch: the heart answered its own ask for PR #$FIRST_GOOD (plan 206 §11.3 #2 — role heart, seat primary is the reviewer). The seat decided for itself; this record is the exception made visible." >/dev/null 2>&1 || true
    SEAT="$ROOT/bin/forge/review-seat.sh"
    if [ -x "$SEAT" ]; then
      "$SEAT" ensure >/dev/null 2>&1 || die "the review seat could not be raised — review-seat.sh ensure names why"
      exec "$SEAT" ask "$FIRST_GOOD" --wait
    fi
  fi
fi
exit 0
