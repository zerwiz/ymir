#!/usr/bin/env bash
# seat-reap.sh — the hand that closes a finished seat.
#
# The fault this door answers (measured 2026-11-10): `einherjar-spawn.sh
# launch_herdr` raises a herdr workspace `eindri-<id>` per errand, and NOTHING
# closed it. The arm's close hook and the review verdict never touched the
# workspace; `eindri-control.sh close` closes a pane and nothing called it on
# completion. A worker exits into a bare shell, herdr restores that shell after a
# restart, and the hall fills with dead `eindri-*` workspaces — nine of them while
# this was written, one of which was this worker's own.
#
# The Allfather's law is that this is figured out AUTOMATICALLY when the seat takes
# the arm — never by an operator remembering to tidy up:
#
#   seat-reap.sh <id>        close THIS errand's workspace, by the id recorded in
#                            state/<id>.meta (label `eindri-<id>` when an older
#                            record does not carry one)
#   seat-reap.sh --sweep     close every agentless `eindri-*` workspace whose
#                            errand is closed or has no live record
#   seat-reap.sh --list      what --sweep WOULD close, closing nothing
#   seat-reap.sh --install   seat the sweep on every harness this host runs
#   seat-reap.sh --check     is it seated? (exit 1 when a present harness is not)
#   seat-reap.sh --shell P   close the bare shell standing in worktree P (a dead
#                            seat keeps its tree `in-use` forever otherwise)
#   seat-reap.sh --verify    the two structural faults, reported and never mended
#                            (exit 1 when this seat is broken) — the verb install
#                            and Gróa call from their --check mode
#
# One reader for one question: whether an agent stands in a workspace is asked of
# bin/seat/herdr-agents.py (the ONE reader of `herdr agent list`, plan 189 §18.2),
# never re-parsed here. The close itself reuses the doors that already refuse a
# live seat — bin/seat/seats.sh close and `herdr workspace close` — so this file
# cannot become a second, looser closer.
#
# Refusals are the point. A workspace holding a LIVE agent is never touched; a
# dirty or unpushed WORKTREE is never touched (that is bin/forge/housekeeping.sh's
# judgement, and it is not repeated here — this door closes seats, it does not
# reclaim work).
#
# Env: BROKK_HOME / BROKK_STATE_OVERRIDE (siblings). Exit: 0 ok, 1 error, 2 usage.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"

# The errand records are written by einherjar-spawn.sh / eindri-arm.sh as
# ${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}. A digest passes the hoard's state
# dir, which on a tree-installed seat is EMPTY — so this door asks every shelf a
# record could be on rather than reading one and calling the errand recordless.
state_dirs() {
  local d seen=""
  for d in "${BROKK_STATE_OVERRIDE:-}" "$BROKK_HOME/state" "$ROOT/state"; do
    [ -n "$d" ] && [ -d "$d" ] || continue
    case " $seen " in *" $d "*) continue ;; esac
    seen="$seen $d"
    printf '%s\n' "$d"
  done
}

# record <id> <suffix> -> the first existing state file on any shelf, or nothing
record() {
  local id=$1 suffix=$2 d
  while IFS= read -r d; do
    [ -e "$d/$id.$suffix" ] && { printf '%s' "$d/$id.$suffix"; return 0; }
  done < <(state_dirs)
  return 1
}

meta_key() { # <id> <key>
  local f; f="$(record "$1" meta)" || return 1
  [ -n "$f" ] || return 1
  awk -F= -v k="$2" '$1==k{sub(/^[^=]*=/,""); print; exit}' "$f" 2>/dev/null
}

# ── the two readers of herdr, and nothing else ────────────────────────────────
HAVE_HERDR=0
command -v herdr >/dev/null 2>&1 && HAVE_HERDR=1

# ws_rows -> workspace_id<TAB>label<TAB>workspace_agent_status
ws_rows() {
  [ "$HAVE_HERDR" = 1 ] || return 1
  herdr workspace list 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    raise SystemExit(1)
for w in (d.get("result") or {}).get("workspaces") or []:
    print("%s\t%s\t%s" % (w.get("workspace_id") or "", w.get("label") or "", w.get("agent_status") or "unknown"))
' 2>/dev/null
}

# agents_json -> the agent list from the ONE door
agents_json() { python3 "$SCRIPT_DIR/herdr-agents.py" --json 2>/dev/null; }

# agent_in_workspace <ws> <worktree> -> 0 when an agent stands in it. The pane is
# the evidence, not the workspace's own `agent_status` roll-up.
agent_in_workspace() {
  local ws=$1 wt=${2:-} j
  j="$(agents_json)" || return 1
  [ -n "$j" ] || return 1
  # The JSON rides through a FILE: a heredoc owns stdin, so a pipe into it would
  # stream nothing and every seat would read as agentless (the same trap the seat
  # brief records from bin/seat/seats.sh, 2026-11-08).
  local tmp; tmp="$(mktemp 2>/dev/null)" || return 1
  printf '%s' "$j" >"$tmp"
  python3 - "$ws" "$wt" "$tmp" <<'PY' 2>/dev/null
import json,sys
ws, wt = sys.argv[1], (sys.argv[2] or "").rstrip("/")
try:
    agents = json.load(open(sys.argv[3]))
except Exception:
    raise SystemExit(1)
for a in agents or []:
    if (a.get("workspace_id") or "") == ws:
        raise SystemExit(0)
    fg = (a.get("foreground_cwd") or "").rstrip("/")
    cwd = (a.get("cwd") or "").rstrip("/")
    if wt and (fg == wt or cwd == wt):
        raise SystemExit(0)
raise SystemExit(1)
PY
  local rc=$?
  rm -f "$tmp"
  return $rc
}

pane_of() { # <ws> -> the first pane id in that workspace
  [ "$HAVE_HERDR" = 1 ] || return 1
  herdr pane list --workspace "$1" 2>/dev/null \
    | sed -n 's/.*"pane_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

# pane_at <abs-path> -> the pane whose shell is STANDING in that worktree and holds
# no agent. This is the second half of the 2026-11-10 fault: a dead Eindri's bare
# shell keeps its worktree `in-use` forever. Closing it is the first step of any
# reclaim, and it is asked of this door so nothing else parses `herdr pane list`.
pane_at() {
  [ "$HAVE_HERDR" = 1 ] || return 1
  local target tmp; target="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
  # The JSON rides a FILE: a heredoc owns stdin, so `herdr pane list | python3 - <<PY`
  # streams nothing and every path reads as unheld (the trap bin/seat/seats.sh records).
  tmp="$(mktemp 2>/dev/null)" || return 1
  herdr pane list >"$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  python3 - "$target" "$tmp" <<'PY' 2>/dev/null
import json,sys
target=sys.argv[1].rstrip("/")
try:
    d=json.load(open(sys.argv[2]))
except Exception:
    raise SystemExit(1)
for p in (d.get("result") or {}).get("panes") or []:
    cwd=(p.get("cwd") or "").rstrip("/")
    if cwd==target or cwd.startswith(target+"/"):
        print(p.get("pane_id") or "")
        raise SystemExit(0)
raise SystemExit(1)
PY
  local rc=$?
  rm -f "$tmp"
  return $rc
}

# ── the errand's own state: live, closed, or recordless ──────────────────────
# closed <id> -> 0 when the errand has reached a terminal word.
closed_errand() {
  local id=$1 f st verdict
  # A review verdict of `return` is NOT a closed errand: the work went back to the
  # worker, and closing its seat would bury a live errand. Only a terminal verdict
  # or a terminal status closes.
  f="$(record "$id" review)" && [ -n "$f" ] && {
    verdict="$(awk -F= '$1=="verdict"{print $2; exit}' "$f" 2>/dev/null)"
    case "$verdict" in pass|fail) return 0 ;; esac
  }
  f="$(record "$id" close)" && [ -n "$f" ] && return 0
  f="$(record "$id" status)" || return 1
  [ -n "$f" ] || return 1
  st="$(head -n1 "$f" 2>/dev/null | awk '{print $1}' | tr -d ':')"
  case "$st" in done|failed|needs-decision|accepted|returned|closed) return 0 ;; esac
  return 1
}

# stale <id> -> 0 when the record claims work but nobody has breathed in 2 hours
stale_errand() {
  local id=$1 f age now
  f="$(record "$id" status)" || return 1
  [ -n "$f" ] || return 1
  now=$(date +%s)
  age=$(( now - $(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo "$now") ))
  [ "$age" -gt "${SEAT_REAP_STALE_SECONDS:-7200}" ]
}

# ── the settling grace (the house law, tests/test_eindri_liveness_grace.sh) ───
# A recordless workspace is NOT a dead one: einherjar-spawn.sh raises the herdr
# workspace at launch_herdr and writes the first status only AFTER the seat is
# proved — up to the whole seat-settle wait (60 s) later. A sweep that closed a
# recordless workspace on sight would kill a seat that is still booting, which is
# exactly the false-death the liveness grace was written to stop (2026-11-06).
#
# The age is measured from the launch stamp the spawner writes beside the record
# (state/.<id>.launched), then from the meta's `launched`, then from the
# worktree's own mtime. When NO timestamp can be found the workspace is KEPT and
# said so: an unmeasurable seat is assumed live, because assuming dead is the
# irreversible direction.
grace_seconds() { printf '%s' "${YMIR_SEAT_SETTLE:-60}"; }

recordless_age() { # <id> -> age in seconds on stdout; 1 when no stamp exists
  local id=$1 d stamp launched wt now
  now=$(date +%s)
  while IFS= read -r d; do
    if [ -r "$d/.$id.launched" ]; then
      stamp="$(head -n1 "$d/.$id.launched" 2>/dev/null | tr -dc '0-9')"
      [ -n "$stamp" ] && { printf '%s' "$((now - stamp))"; return 0; }
    fi
  done < <(state_dirs)
  launched="$(meta_key "$id" launched 2>/dev/null || true)"
  case "$launched" in ''|*[!0-9]*) ;; *) printf '%s' "$((now - launched))"; return 0 ;; esac
  wt="$(meta_key "$id" worktree 2>/dev/null || true)"
  [ -n "$wt" ] || wt="$ROOT/.yggdrasil/$id"
  if [ -d "$wt" ]; then
    stamp=$(stat -c %Y "$wt" 2>/dev/null || stat -f %m "$wt" 2>/dev/null || true)
    case "$stamp" in ''|*[!0-9]*) ;; *) printf '%s' "$((now - stamp))"; return 0 ;; esac
  fi
  return 1
}

# ── one close ────────────────────────────────────────────────────────────────
# close_seat <id> <ws> <pane> <why> -> prints one TOON row; 0 closed, 1 refused/failed
close_seat() {
  local id=$1 ws=$2 pane=$3 why=$4 wt
  wt="$(meta_key "$id" worktree 2>/dev/null || true)"
  [ -n "$wt" ] || wt="$ROOT/.yggdrasil/$id"

  if agent_in_workspace "$ws" "$wt"; then
    printf '  "%s","%s","%s","refused: a live agent stands here"\n' "$id" "$ws" "$pane"
    return 1
  fi
  # The pane door refuses a live agent on its own reading — belt and braces,
  # because the agent list is a moment, and a close is forever.
  if [ -n "$pane" ] && [ -x "$SCRIPT_DIR/seats.sh" ]; then
    "$SCRIPT_DIR/seats.sh" close "$pane" >/dev/null 2>&1 || true
  fi
  if [ -n "$ws" ] && [ "$HAVE_HERDR" = 1 ]; then
    # A second liveness read immediately before the irreversible step.
    if agent_in_workspace "$ws" "$wt"; then
      printf '  "%s","%s","%s","refused: an agent appeared at the moment of closing"\n' "$id" "$ws" "$pane"
      return 1
    fi
    if herdr workspace close "$ws" >/dev/null 2>&1; then
      printf '  "%s","%s","%s","%s"\n' "$id" "$ws" "$pane" "$why"
      local d
      while IFS= read -r d; do
        printf 'closed=%s\nworkspace=%s\nwhy=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ws" "$why" >"$d/$id.seat-closed" 2>/dev/null || true
      done < <(state_dirs)
      return 0
    fi
    printf '  "%s","%s","%s","failed: herdr refused the workspace close"\n' "$id" "$ws" "$pane"
    return 1
  fi
  printf '  "%s","%s","%s","failed: no pane backend answered"\n' "$id" "$ws" "$pane"
  return 1
}

# resolve_workspace <id> -> ws id (recorded first, then by label)
resolve_workspace() {
  local id=$1 ws
  ws="$(meta_key "$id" workspace 2>/dev/null || true)"
  [ -n "$ws" ] && { printf '%s' "$ws"; return 0; }
  ws="$(ws_rows 2>/dev/null | awk -F'\t' -v l="eindri-$id" '$2==l{print $1; exit}')"
  [ -n "$ws" ] && { printf '%s' "$ws"; return 0; }
  return 1
}

reap_one() { # <id> -> prints rows; 0 closed
  local id=$1 ws pane why
  ws="$(resolve_workspace "$id")" || {
    printf '  "%s","","","no herdr workspace carries this errand"\n' "$id"
    return 1
  }
  pane="$(meta_key "$id" seat_pane 2>/dev/null || true)"
  [ -n "$pane" ] || pane="$(meta_key "$id" window 2>/dev/null || true)"
  [ -n "$pane" ] || pane="$(pane_of "$ws" 2>/dev/null || true)"
  why="closed"
  closed_errand "$id" || why="no live record"
  close_seat "$id" "$ws" "$pane" "$why"
}

# ── the sweep ────────────────────────────────────────────────────────────────
sweep() { # <do-it: 0|1>
  local do_it=$1 ws label id pane wt why n_closed=0 n_kept=0 n_ref=0
  local -a closed_rows=() kept_rows=() refused_rows=()

  [ "$HAVE_HERDR" = 1 ] || { printf 'seat-reap[1]{state}:\n  "no herdr on this host — no seat to close"\n'; return 0; }

  while IFS=$'\t' read -r ws label _st; do
    [ -n "$ws" ] || continue
    case "$label" in eindri-*) ;; *) continue ;; esac
    id="${label#eindri-}"
    # The main hall is never swept, even if someone names a workspace after it.
    [ -n "$id" ] || continue
    wt="$(meta_key "$id" worktree 2>/dev/null || true)"
    [ -n "$wt" ] || wt="$ROOT/.yggdrasil/$id"
    pane="$(meta_key "$id" seat_pane 2>/dev/null || true)"
    [ -n "$pane" ] || pane="$(pane_of "$ws" 2>/dev/null || true)"

    if agent_in_workspace "$ws" "$wt"; then
      n_kept=$((n_kept + 1))
      kept_rows+=("$(printf '  "%s","%s","%s","a live agent stands here — never touched"' "$id" "$ws" "$pane")")
      continue
    fi
    if closed_errand "$id"; then
      why="errand closed, no agent"
    elif [ -z "$(record "$id" status 2>/dev/null || true)" ]; then
      # THE HEARTBEAT IS THE RECORD OF LIFE — but a seat takes time to breathe.
      # Inside the settling grace the workspace is SETTLING and nothing is closed
      # (tests/test_eindri_liveness_grace.sh is the law this honours).
      age="$(recordless_age "$id" 2>/dev/null || true)"
      if [ -z "$age" ]; then
        n_kept=$((n_kept + 1))
        kept_rows+=("$(printf '  "%s","%s","%s","no live record and no timestamp — kept (an unmeasurable seat is assumed live)"' "$id" "$ws" "$pane")")
        continue
      fi
      if [ "$age" -lt "$(grace_seconds)" ]; then
        n_kept=$((n_kept + 1))
        kept_rows+=("$(printf '  "%s","%s","%s","SETTLING — %ss old, inside the %ss grace"' "$id" "$ws" "$pane" "$age" "$(grace_seconds)")")
        continue
      fi
      why="no live record"
    elif stale_errand "$id"; then
      why="record stale, no agent"
    else
      n_kept=$((n_kept + 1))
      kept_rows+=("$(printf '  "%s","%s","%s","record still fresh — left alone"' "$id" "$ws" "$pane")")
      continue
    fi

    if [ "$do_it" = 0 ]; then
      n_closed=$((n_closed + 1))
      closed_rows+=("$(printf '  "%s","%s","%s","%s"' "$id" "$ws" "$pane" "$why")")
      continue
    fi
    local row
    if row="$(close_seat "$id" "$ws" "$pane" "$why")"; then
      n_closed=$((n_closed + 1)); closed_rows+=("$row")
    else
      case "$row" in *refused*) n_ref=$((n_ref + 1)); refused_rows+=("$row") ;;
                    *) n_kept=$((n_kept + 1)); kept_rows+=("$row") ;; esac
    fi
  done < <(ws_rows 2>/dev/null)

  local verb=closed; [ "$do_it" = 0 ] && verb=would-close
  printf 'seat-reap[1]{%s,kept,refused}:\n  "%s","%s","%s"\n' "$verb" "$n_closed" "$n_kept" "$n_ref"
  if [ "${#closed_rows[@]}" -gt 0 ]; then
    printf '%s[%s]{id,workspace,pane,why}:\n' "$verb" "${#closed_rows[@]}"
    printf '%s\n' "${closed_rows[@]}"
  fi
  if [ "${#refused_rows[@]}" -gt 0 ]; then
    printf 'refused[%s]{id,workspace,pane,why}:\n' "${#refused_rows[@]}"
    printf '%s\n' "${refused_rows[@]}"
  fi
  if [ "${#kept_rows[@]}" -gt 0 ]; then
    printf 'kept[%s]{id,workspace,pane,why}:\n' "${#kept_rows[@]}"
    printf '%s\n' "${kept_rows[@]}"
  fi
  [ "$n_closed" -gt 0 ] && return 0
  return 0
}

# ── the hook, per harness (requirement: pi, opencode and claude alike) ───────
SESSION_DOOR="$ROOT/bin/time/saga-session-start.sh"

# ── verify: report the two structural faults, mend nothing ───────────────────
# `--check` on the installer and on Gróa must not repair an old home; it must NAME
# what is broken. The mend is the migration's (0018) and Eir's.
is_linked_worktree() {  # <path>
  local p=${1:-.} common own
  common="$(git -C "$p" rev-parse --git-common-dir 2>/dev/null)" || return 1
  own="$(git -C "$p" rev-parse --git-dir 2>/dev/null)" || return 1
  [ -n "$common" ] && [ -n "$own" ] || return 1
  [ "$(CDPATH='' cd "$p" && CDPATH='' cd "$common" 2>/dev/null && pwd -P)" \
    = "$(CDPATH='' cd "$p" && CDPATH='' cd "$own" 2>/dev/null && pwd -P)" ] && return 1
  return 0
}
verify() {
  local bad=0 pointer line wt dirty n_bad=0
  pointer="${PI_EXT_HOME:-$HOME/.pi/agent/extensions}/.ymir-root"
  if [ -r "$pointer" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      case "$line" in
        */.yggdrasil/*|*/.yggdrasil)
          printf '  "root-record","broken","%s is a worktree path — a root is a home, a worktree is an errand"\n' "$line"
          bad=$((bad + 1)); continue ;;
      esac
      if [ -d "$line" ] && is_linked_worktree "$line"; then
        printf '  "root-record","broken","%s is a linked worktree — bin/seat/valknut-load.sh must not record it"\n' "$line"
        bad=$((bad + 1))
      fi
    done <"$pointer"
    [ "$bad" = 0 ] && printf '  "root-record","ok","%s"\n' "$pointer"
  else
    printf '  "root-record","absent","%s (nothing recorded yet)"\n' "$pointer"
  fi
  while IFS= read -r wt; do
    [ -n "$wt" ] || continue
    case "$wt" in */.yggdrasil/*) ;; *) continue ;; esac
    [ -d "$wt" ] || continue
    dirty="$(git -C "$wt" status --porcelain 2>/dev/null | grep -c '^\( \{0,1\}\)D  *\.pi/extensions/')"
    [ "${dirty:-0}" = 0 ] && continue
    printf '  "worktree","broken","%s reports %s extension file(s) deleted — sparse-checkout not set"\n' "$wt" "$dirty"
    n_bad=$((n_bad + 1))
  done < <(git -C "$ROOT" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}')
  [ "$n_bad" = 0 ] && printf '  "worktrees","ok","no worktree reports an extension deletion"\n'
  if [ $((bad + n_bad)) -gt 0 ]; then
    printf 'seat-reap: %s fault(s) — mend: bin/engine/ymir-migrate.sh apply (migration 0019)\n' "$((bad + n_bad))" >&2
    return 1
  fi
  return 0
}

claude_settings() { printf '%s' "${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"; }

# The SessionStart hook is MERGED, never rewritten: another tool's keys are the
# operator's, and this door has no business dropping them (the same reason
# bin/pi/arm.sh refuses to mangle a YAML key it did not write).
claude_hook_seated() {
  local f; f="$(claude_settings)"
  [ -r "$f" ] || return 1
  python3 - "$f" "$SESSION_DOOR" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(1)
want=sys.argv[2]
for grp in (d.get("hooks") or {}).get("SessionStart") or []:
    for h in grp.get("hooks") or []:
        if h.get("command") == want:
            raise SystemExit(0)
raise SystemExit(1)
PY
}

claude_hook_seat() {
  local f; f="$(claude_settings)"
  mkdir -p "$(dirname "$f")" || return 1
  [ -r "$f" ] && cp "$f" "$f.seat-reap.bak" 2>/dev/null
  python3 - "$f" "$SESSION_DOOR" <<'PY'
import json,os,sys
f, want = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(f)) if os.path.exists(f) else {}
    if not isinstance(d, dict):
        d = {}
except Exception:
    d = {}
hooks = d.setdefault("hooks", {})
groups = hooks.setdefault("SessionStart", [])
for grp in groups:
    for h in grp.get("hooks") or []:
        if h.get("command") == want:
            print("claude: SessionStart hook already seated")
            raise SystemExit(0)
groups.append({"hooks": [{"type": "command", "command": want, "timeout": 180}]})
tmp = f + ".seat-reap.tmp"
json.dump(d, open(tmp, "w"), indent=2)
open(tmp, "a").write("\n")
os.replace(tmp, f)
print("claude: SessionStart hook seated in %s" % f)
PY
}

seat_hooks() { # <do-it 0|1>
  local do_it=$1 present=0 bad=0
  # pi — the session side is the deployed watch extension (valknut-load seats it).
  if command -v pi >/dev/null 2>&1; then
    present=$((present + 1))
    if ls "$HOME/.pi/agent/extensions"/gna-pi-watch.ts >/dev/null 2>&1 \
       || ls "$ROOT/.pi/extensions"/gna-pi-watch.ts >/dev/null 2>&1; then
      printf '  "pi","seated","the watch extension delivers the digest, and the digest sweeps"\n'
    else
      if [ "$do_it" = 1 ] && [ -x "$SCRIPT_DIR/valknut-load.sh" ]; then
        "$SCRIPT_DIR/valknut-load.sh" --all >/dev/null 2>&1 || true
      fi
      if ls "$HOME/.pi/agent/extensions"/gna-pi-watch.ts >/dev/null 2>&1; then
        printf '  "pi","seated","seated now by bin/seat/valknut-load.sh --all"\n'
      else
        printf '  "pi","NOT SEATED","run: bin/seat/valknut-load.sh --all"\n'; bad=$((bad + 1))
      fi
    fi
  fi
  # opencode — the plugin that arms the watch and relays the digest.
  if command -v opencode >/dev/null 2>&1; then
    present=$((present + 1))
    if ls "$HOME/.config/opencode/plugins"/*syn-watch* "$ROOT/.opencode/plugins"/*syn-watch* >/dev/null 2>&1; then
      printf '  "opencode","seated","the syn-watch plugin arms the session side"\n'
    else
      printf '  "opencode","NOT SEATED","run: bin/engine/ymir-install.sh (opencode-v2-plugin step)"\n'; bad=$((bad + 1))
    fi
  fi
  # claude — a real SessionStart hook, merged into the operator's own settings.
  if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
    present=$((present + 1))
    if claude_hook_seated; then
      printf '  "claude","seated","SessionStart runs the digest, and the digest sweeps"\n'
    elif [ "$do_it" = 1 ] && claude_hook_seat >/dev/null 2>&1 && claude_hook_seated; then
      printf '  "claude","seated","SessionStart hook merged into %s (backup kept)"\n' "$(claude_settings)"
    else
      printf '  "claude","NOT SEATED","run: bin/seat/seat-reap.sh --install (merges %s)"\n' "$(claude_settings)"; bad=$((bad + 1))
    fi
  fi
  if [ "$present" = 0 ]; then
    printf '  "-","skip","no harness on this host — a clean skip, nothing to seat"\n'
  fi
  [ "$bad" = 0 ]
}

usage() {
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  -h|--help|help) usage; exit 0 ;;
  --sweep)   shift; sweep 1 ;;
  --list)    shift; sweep 0 ;;
  --status)  shift; sweep 0 ;;
  --shell)
    # Close the bare shell holding a worktree — refuse a live agent, as everywhere.
    target="${2:-}"
    [ -n "$target" ] || { printf 'error: --shell <worktree path>\n' >&2; exit 2; }
    p="$(pane_at "$target")" || { printf 'seat-reap[1]{path,state}:\n  "%s","no pane stands in it"\n' "$target"; exit 1; }
    if agent_in_workspace "" "$target"; then
      printf 'seat-reap[1]{path,pane,state}:\n  "%s","%s","refused: a live agent stands here"\n' "$target" "$p"; exit 1
    fi
    if "$SCRIPT_DIR/seats.sh" close "$p" >/dev/null 2>&1; then
      printf 'seat-reap[1]{path,pane,state}:\n  "%s","%s","closed (bare shell, no agent)"\n' "$target" "$p"
      exit 0
    fi
    printf 'seat-reap[1]{path,pane,state}:\n  "%s","%s","refused: the pane did not close"\n' "$target" "$p"
    exit 1 ;;
  --install)
    printf 'seat-reap[1]{harness,state,detail}:\n'
    seat_hooks 1 || exit 1
    exit 0 ;;
  --check)
    printf 'seat-reap[1]{harness,state,detail}:\n'
    seat_hooks 0 || exit 1
    exit 0 ;;
  --verify)
    printf 'seat-reap[1]{surface,state,detail}:\n'
    verify ;;
  "" ) printf 'error: an errand id or --sweep|--list|--install|--check is required\n' >&2; exit 2 ;;
  -* ) printf 'error: unknown option %s\n' "$1" >&2; exit 2 ;;
  *)
    id=$1
    printf 'seat-reap[1]{id,workspace,pane,why}:\n'
    reap_one "$id" ;;
esac
