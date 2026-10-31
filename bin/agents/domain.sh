#!/usr/bin/env bash
# domain.sh — the ONE door that starts, reports and stops a domain's keeper.
#
# A domain is a system with a folder, a declaration (`systems/<domain>/domain.yaml`), a keeper figure
# (`.agents/agents/<keeper>*.md`), a board and a memory namespace (plans 129 and 149). Until this door
# existed a keeper was "a folder with a declaration, not an office" — plan 129 §23's own words.
#
# THE BRIEF IS GENERATED, NEVER HAND-WRITTEN. It is read out of the domain's own declaration, so a keeper
# cannot drift from the system it keeps: change `domain.yaml` and the brief changes with it.
#
# Usage:
#   domain.sh list                      # every declared domain, its keeper, and whether it is seated
#   domain.sh check [domain]            # a declaration that cannot be honoured is a fault, named
#   domain.sh brief <domain>            # the generated brief (what the keeper is told, in full)
#   domain.sh call <domain> [--headless] [--note "<what for>"]
#   domain.sh status [domain]
#   domain.sh stop <domain>
#
# Exit: 0 ok · 1 refused/unavailable · 2 usage.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE="${YMIR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}/domains"
SEAT="$ROOT/bin/seat/herdr-run.sh"
mkdir -p "$STATE" 2>/dev/null || true

usage(){ sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

declare -A DOMAIN_DIR KEEPER_FIG
load_domains(){
  local d name keeper
  for d in "$ROOT"/systems/*/domain.yaml; do
    [ -r "$d" ] || continue
    name="$(sed -n 's/^domain:[[:space:]]*//p' "$d" | head -1)"
    keeper="$(sed -n 's/^  keeper:[[:space:]]*//p;s/^keeper:[[:space:]]*//p' "$d" | head -1)"
    [ -n "$name" ] || name="$(basename "$(dirname "$d")")"
    [ -n "$keeper" ] || keeper="$name"   # a declaration may leave it implicit: the domain keeps itself
    DOMAIN_DIR["$name"]="$(dirname "$d")"
    KEEPER_FIG["$name"]="$keeper"
  done
}

figure_file(){  # <keeper> → the one figure file, or nothing
  local k="${1:-}"
  [ -n "$k" ] || return 0
  ls "$ROOT/.agents/agents/$k"*.md 2>/dev/null | head -1
}

brief_for(){  # <domain>
  local name="$1" dir="${DOMAIN_DIR[$1]:-}" keeper="${KEEPER_FIG[$1]:-}" fig
  fig="$(figure_file "$keeper")"
  printf '# Brief — you are %s, keeper of the %s domain\n\n' "${keeper:-its keeper}" "$name"
  printf '## The declaration (`%s`)\n\n' "${dir#"$ROOT"/}/domain.yaml"
  sed -n 's/^/    /p' "$dir/domain.yaml"
  if [ -n "$fig" ]; then
    printf '\n## Your figure (`%s`)\n\n' "${fig#"$ROOT"/}"
    sed -n 's/^/    /p' "$fig"
  else
    printf '\n## Your figure\n\n    NONE — no file matches .agents/agents/%s*.md. Say so before you act.\n' "${keeper:-?}"
  fi
  [ -r "$dir/AGENTS.md" ] && { printf '\n## The house rules in this folder\n\n'; sed -n 's/^/    /p' "$dir/AGENTS.md"; }
  printf '\n## How you work\n\n'
  printf '    You keep %s. You may write in %s and nowhere else.\n' "$name" "${dir#"$ROOT"/}/"
  printf '    You ask other domains through their doors; you never edit their folders.\n'
  printf '    Before you claim done: bash -n on every door you touched, the domain smoke, and the ward.\n'
}

seated_pids(){  # <domain> → pane ids whose cwd is the domain folder
  timeout 10 herdr agent list 2>/dev/null \
  | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for a in (d.get("result") or {}).get("agents") or []:
    cwd=(a.get("cwd") or "")
    import os
    if sys.argv[1] and sys.argv[1] in cwd: print(a.get("pane_id",""))' "${DOMAIN_DIR[$1]:-}" 2>/dev/null | grep . || true
}

ACTION="${1:-list}"; shift || true
load_domains
case "$ACTION" in
  list)
    printf 'domains[%s]{domain,keeper,figure,folder}:\n' "$(printf '%s\n' "${!DOMAIN_DIR[@]}" | grep -c .)"
    for n in $(printf '%s\n' "${!DOMAIN_DIR[@]}" | sort); do
      k="${KEEPER_FIG[$n]}"; f="$(figure_file "$k")"
      printf '  "%s","%s","%s","%s"\n' "$n" "${k:-none}" "$([ -n "$f" ] && echo yes || echo MISSING)" "${DOMAIN_DIR[$n]#"$ROOT"/}"
    done ;;
  check)
    want="${1:-}"; rc=0
    for n in $(printf '%s\n' "${!DOMAIN_DIR[@]}" | sort); do
      [ -z "$want" ] || [ "$n" = "$want" ] || continue
      k="$(printf '%s' "${KEEPER_FIG[$n]}" | tr -d '"')"; f="$(figure_file "$k")"
      # A DECLARED DOOR THAT DOES NOT EXIST IS A LIE (Skirnir's own audit, 2026-10-31: his declaration
      # named services/rooms-wall-test.sh while the file was room-wall-test.sh, and this check said fine).
      doors="$(grep -oE 'services/[A-Za-z0-9._-]+\.(sh|py)' "${DOMAIN_DIR[$n]}/domain.yaml" 2>/dev/null | sort -u)"
      missing=""
      for door in $doors; do
        [ -e "${DOMAIN_DIR[$n]}/$door" ] || missing="$missing $door"
      done
      printf '  "%s","keeper=%s","figure=%s","folder=%s","doors=%s"\n' "$n" "${k:-none}" \
        "$([ -n "$f" ] && echo ok || echo MISSING)" "$([ -d "${DOMAIN_DIR[$n]}" ] && echo ok || echo MISSING)" \
        "$([ -z "$missing" ] && echo ok || echo "MISSING:$missing")"
      [ -n "$f" ] || rc=1
      [ -z "$missing" ] || rc=1
    done
    [ "$rc" -eq 0 ] || printf 'check: a domain that cannot honour its declaration cannot be seated — a missing figure is .agents/agents/<keeper>*.md, a missing door is a name in domain.yaml with no file\n' >&2
    exit "$rc" ;;
  brief)
    n="${1:-}"; [ -n "$n" ] || { printf 'error: brief needs a domain\n' >&2; exit 2; }
    [ -n "${DOMAIN_DIR[$n]:-}" ] || { printf 'error: no such domain: %s\nhelp: domain.sh list\n' "$n" >&2; exit 2; }
    brief_for "$n" ;;
  call)
    n="${1:-}"; shift || true; headless=0; note=""
    while [ $# -gt 0 ]; do case "$1" in --headless) headless=1; shift;; --note) note="${2-}"; shift 2;; --note=*) note="${1#--note=}"; shift;; *) shift;; esac; done
    [ -n "$n" ] || { printf 'error: call needs a domain\n' >&2; exit 2; }
    [ -n "${DOMAIN_DIR[$n]:-}" ] || { printf 'error: no such domain: %s\n' "$n" >&2; exit 2; }
    dir="${DOMAIN_DIR[$n]}"; k="$(printf '%s' "${KEEPER_FIG[$n]}" | tr -d '"')"
    [ -n "$(figure_file "$k")" ] || { printf 'domain[1]{domain,refused}: " \n  "%s","no figure: write .agents/agents/%s*.md first"\n' "$n" "$k" >&2; exit 1; }
    brief="$(brief_for "$n")"
    bf="$STATE/$n.brief.md"; printf '%s\n' "$brief" >"$bf"
    [ -n "$note" ] && printf '\n## This errand\n\n    %s\n' "$note" >>"$bf"
    # THE BRIEF IS THE SYSTEM PROMPT (never a giant first message): pi takes a file with
    # --append-system-prompt, so the keeper carries its declaration for the whole session and the first
    # turn stays a turn.
    opening="${note:-You are seated as the keeper of the $n domain. Read your brief, confirm in one line what you may write and what you may never touch, then wait for an order.}"
    # THE SEAT IS DECLARED, NOT ASSUMED (plan 101's law for Skírnir: the model has NO tool calls).
    # `seat.tools: none` seats a brain with no hands; a list becomes pi's allowlist. MCP doors are
    # off unless the declaration names them — a door is a hand.
    seat_tools="$(sed -n '/^seat:/,/^[a-z]/p' "$dir/domain.yaml" 2>/dev/null | sed -n 's/^ *tools:[[:space:]]*//p' | head -1)"
    seat_tools="${seat_tools#[}; ${seat_tools%]}"; seat_tools="${seat_tools// /}"
    seat_args=()
    case "$seat_tools" in
      ""|none|None|NONE) seat_args+=(--no-tools --no-mcp) ;;
      *)                 seat_args+=(--tools "$seat_tools" --no-mcp) ;;
    esac
    if [ "$headless" = 1 ]; then
      printf 'domain[1]{domain,state,mode,brief}:\n  "%s","seated","headless","%s"\n' "$n" "${bf#"$ROOT"/}"
      ( cd "$dir" && exec pi -p "${seat_args[@]}" --append-system-prompt "$bf" "$opening" ) ; exit $?
    fi
    # A PANE AGENT IS A TAB RUNNING THE AGENT, then a prompt into it (herdr 0.9's own shape): `herdr tab
    # create` with a command gives the pane a TTY, and `herdr agent prompt` speaks to the agent herdr then
    # detects. `pane run` alone is wrong here — it hands the command a pipe, so pi answers once and exits.
    if ! command -v herdr >/dev/null 2>&1; then
      printf 'domain[1]{domain,state}:\n  "%s","refused: no herdr on this seat — use --headless"\n' "$n" >&2
      exit 1
    fi
    line="$(printf '%q ' pi "${seat_args[@]}" --append-system-prompt "$bf")"
    out="$(timeout 60 herdr tab create --cwd "$dir" --label "domain:$n" --focus 2>/dev/null || true)"
    tab="$(printf '%s' "$out" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
r=d.get("result") or d
print((r.get("tab") or {}).get("tab_id") or r.get("tab_id") or "")' 2>/dev/null)"
    pane="$(printf '%s' "$out" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
r=d.get("result") or d
print((r.get("root_pane") or {}).get("pane_id") or "")' 2>/dev/null)"
    if [ -z "$tab" ]; then
      printf 'domain[1]{domain,state}:\n  "%s","refused: herdr did not create a tab"\n' "$n" >&2
      printf '%s\n' "$out" >&2
      exit 1
    fi
    if [ -z "$pane" ]; then
      printf 'domain[1]{domain,state,tab}:\n  "%s","refused: tab has no pane","%s"\n' "$n" "$tab" >&2
      exit 1
    fi
    timeout 30 herdr pane run "$pane" "$line" >/dev/null 2>&1 || true
    sleep 3
    timeout 60 herdr agent prompt "$pane" "$opening" >/dev/null 2>&1 || \
      timeout 30 herdr pane send-text "$pane" "$opening" >/dev/null 2>&1 || true
    printf 'domain[1]{domain,state,mode,tab,pane,brief}:\n  "%s","seated","pane","%s","%s","%s"\n' \
      "$n" "$tab" "$pane" "${bf#"$ROOT"/}"
    printf '%s\t%s\t%s\n' "$n" "$tab" "$pane" >>"$STATE/seated.tsv" 2>/dev/null || true
    exit 0
    ;;
  status)
    for n in ${1:+"$1"} $(printf '%s\n' "${!DOMAIN_DIR[@]}" | sort); do
      [ -n "${DOMAIN_DIR[$n]:-}" ] || continue
      pids="$(seated_pids "$n" | paste -sd, -)"
      printf 'domain[1]{domain,pane}:\n  "%s","%s"\n' "$n" "${pids:-not seated}"
    done ;;
  stop)
    n="${1:-}"; [ -n "$n" ] || { printf 'error: stop needs a domain\n' >&2; exit 2; }
    pids="$(seated_pids "$n" | paste -sd' ' -)"
    [ -n "$pids" ] || { printf 'domain[1]{domain,stopped}: " \n  "%s","nothing seated"\n' "$n"; exit 0; }
    for p in $pids; do timeout 10 herdr pane close "$p" >/dev/null 2>&1 || true; done
    printf 'domain[1]{domain,stopped,panes}:\n  "%s","yes","%s"\n' "$n" "$(printf '%s' "$pids" | tr ' ' ',')" ;;
  *) usage; exit 2 ;;
esac
