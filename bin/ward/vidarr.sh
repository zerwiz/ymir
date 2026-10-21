#!/usr/bin/env bash
# vidarr.sh — VÍÐARR, the silent avenger: the defender's own door.
#
# The house's defence is three figures, and the division is the design:
#
#   GARMR    the senses — the hound walks the house and NOTICES (auditd, listeners, egress, files)
#   VÖRÐR    the gates  — the ward REFUSES at a door; a gate never permits, only says no
#   VÍÐARR   the hand   — the silent avenger CONTAINS and holds the evidence
#
# Víðarr is the one who fights the wolf: he does not reason about policy (Garmr's rules are the
# policy), he does not open a door (Vörðr's gates are the doors) — he closes what is open, kills
# what should not run, and keeps what proves it happened.
#
# What he may do is the allowlist and nothing else: `garmr-bite.sh` owns it, so this door cannot
# grow a capability the plan did not grant. Every action is recorded before it is taken, with its
# un-bite, and every incident keeps a bundle a human or an auditor can read afterwards.
#
# Usage:
#   vidarr.sh status                          # switch · armed classes · incidents · last action
#   vidarr.sh respond [--dry-run]             # the response pass: plan, advise, contain, record
#   vidarr.sh incident open <title>           # open an incident bundle
#   vidarr.sh incident list                   # every incident, newest first
#   vidarr.sh evidence <incident-id>          # collect a bundle into that incident
#   vidarr.sh report [<incident-id>] [--open]  # write a human report into hodd/security/incidents/
#   vidarr.sh stand-down                      # the Allfather's hand: bite=report, nothing contained
#
# Exit: 0 ok · 1 refusal/fault · 2 usage · 3 the switch forbids acting
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
VERSION="1.0.0"

home_or_die() {
  local h=""
  declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root h 2>/dev/null
  [ -n "$h" ] || h="${YMIR_HOME:-}"
  [ -n "$h" ] || { printf 'vidarr[1]{error}: "the hoard is unresolved — set YMIR_HOME"\n' >&2; exit 2; }
  printf '%s' "$h"
}
H="$(home_or_die)"
INC="$H/state/garmr/incidents"
BITE="$ROOT/bin/ward/garmr-bite.sh"
mkdir -p "$INC" 2>/dev/null || true

case "${1-}" in -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

runes() { bash "$ROOT/bin/records/runes-append.sh" vidarr "$1" --message "$2" >/dev/null 2>&1; }

# The arm: one door, one wake road (plan 100). A defender who is only roused by a human typing is a
# diary; this is how an incident reaches the session that has to answer it.
wake() {  # <severity> <message> <key>
  local door="$ROOT/bin/notify/send.sh"
  [ -x "$door" ] || return 0
  bash "$door" --source garmr --severity "${1:-CRITICAL}" --key "${3:-vidarr}" \
    --message "Vidarr: ${2}" >/dev/null 2>&1 || true
}

cmd_status() {
  local mode bite_n
  mode=$(bash "$BITE" status 2>/dev/null | sed -n 's/.*"switch","\([a-z]*\)".*/\1/p')
  bite_n=$(bash "$BITE" status 2>/dev/null | sed -n 's/.*"bites taken","\([0-9]*\)".*/\1/p')
  printf 'vidarr[5]{fact,value}:\n'
  printf '  "role","the hand — contains and keeps the evidence (Garmr notices, Vörðr refuses)"\n'
  printf '  "switch","%s"\n' "${mode:-report}"
  printf '  "bites taken","%s"\n' "${bite_n:-0}"
  printf '  "incidents","%s"\n' "$(ls -1 "$INC" 2>/dev/null | wc -l | tr -d ' ')"
  printf '  "quarantine","%s"\n' "$HOME/.local/state/ymir/quarantine"
  [ "${mode:-report}" = "off" ] && printf '  "note","the hand is closed — nothing will be contained"\n'
  return 0
}

cmd_incident() {
  local what="${1-}"; shift || true
  case "$what" in
    open)
      local title="${1:-unnamed}"; local id
      id="$(date +%Y%m%dT%H%M%S)-$(printf '%s' "$title" | tr -cs 'a-z0-9' '-' | cut -c1-40)"
      mkdir -p "$INC/$id"
      printf '%s\n' "$title" > "$INC/$id/title"
      date -Is > "$INC/$id/opened"
      runes incident.open "id=$id title=[$title]"
      wake HIGH "an incident is opened: ${title} (${id})" "vidarr-incident-$id"
      printf 'incident[2]{id,dir}:\n  "%s","%s"\n' "$id" "$INC/$id"
      ;;
    list)
      local n=0
      printf 'incidents[%s]{id,opened,title}:\n' "$(ls -1 "$INC" 2>/dev/null | wc -l | tr -d ' ')"
      for d in $(ls -1 "$INC" 2>/dev/null | sort -r | head -20); do
        printf '  "%s","%s","%s"\n' "$d" "$(cat "$INC/$d/opened" 2>/dev/null)" "$(head -1 "$INC/$d/title" 2>/dev/null)"
        n=$((n+1))
      done
      [ "$n" = 0 ] && printf '  "—","—","no incident has been opened"\n'
      ;;
    *) printf 'vidarr[1]{error}: "incident open|list"\n' >&2; exit 2 ;;
  esac
}

# A bundle an auditor can read: what was seen, what listens, what runs, what changed.
cmd_evidence() {
  local id="${1-}"
  [ -n "$id" ] && [ -d "$INC/$id" ] || { printf 'vidarr[1]{error}: "no such incident: %s"\n' "$id" >&2; exit 2; }
  local d="$INC/$id"
  {
    echo "# uname"; uname -a
    echo; echo "# listening sockets"; (ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null) | head -200
    echo; echo "# recent findings (last 200)"; tail -200 "$H/../state/garmr/findings.jsonl" 2>/dev/null || tail -200 "/var/log/ymir/garmr/findings.jsonl" 2>/dev/null
    echo; echo "# units non-default"; systemctl list-units --type=service --state=running --no-pager 2>/dev/null | head -150
    echo; echo "# bite runes for this window"; grep -F "garmr.bite" "$H/hodd/memory/runes_audit.md" 2>/dev/null | tail -50
  } > "$d/evidence.txt" 2>/dev/null
  sha256sum "$d/evidence.txt" 2>/dev/null > "$d/evidence.sha256"
  runes incident.evidence "id=$id sha=$(cut -d' ' -f1 "$d/evidence.sha256" 2>/dev/null)"
  printf 'vidarr[2]{incident,evidence}:\n  "%s","%s"\n' "$id" "$d/evidence.txt"
}

cmd_respond() {
  local dry=""
  while [ $# -gt 0 ]; do case "$1" in --dry-run) dry="--dry-run"; shift ;; *) shift ;; esac; done
  local findings="$H/../state/garmr/findings.jsonl"
  [ -r "$findings" ] || findings="/var/log/ymir/garmr/findings.jsonl"
  printf 'vidarr[2]{pass,findings}:\n  "response","%s"\n' "$findings"
  local out_file; out_file=$(mktemp)
  bash "$BITE" contain $dry --findings "$findings" 2>&1 | tee "$out_file" | sed 's/^/  /'
  local rc=${PIPESTATUS[0]}
  # what the pass decided → the arm, so the session that must answer is woken, not polled
  local decided woken=""
  decided=$(grep -c 'WOULD BITE\|"taken"' "$out_file" 2>/dev/null || true)
  if [ "${decided:-0}" -gt 0 ]; then
    woken=$(grep -m1 '"undo\|undo:' "$out_file" | sed 's/.*undo: //' | head -c 160)
    wake CRITICAL "a bite is ${dry:+planned (dry-run)}${dry:-taken}; undo: ${woken:-see the rune}" "vidarr-respond"
    printf 'vidarr[1]{arm}: "the Gna arm was woken (Hofvarpnir, CRITICAL) — the session answers, not a poll"\n'
  fi
  runes respond.pass "dry=${dry:-no} rc=$rc findings=$findings decided=$decided"
  rm -f "$out_file"
  return "$rc"
}

cmd_stand_down() {
  python3 - "$H/config/guardian.yaml" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); s = p.read_text()
if "bite:" in s:
    s = re.sub(r'bite:\s*"?[a-z]+"?', 'bite: "report"', s, count=1)
else:
    s = s.replace("hound:\n", 'hound:\n  bite: "report"\n', 1)
p.write_text(s)
print("vidarr[1]{stand_down}: \"bite=report — the hound speaks, and nothing is contained\"")
PY
  runes stand.down "the Allfather closed the hand"
}


# ── the report ────────────────────────────────────────────────────────────────
# A containment that leaves no account of itself is indistinguishable from an accident, so every
# incident and every bite leaves a REPORT a human can read: what was seen, what was decided, what
# was done, what it can be undone by, and what is still owed. It lands in the vault's security shelf
# (hodd/security/incidents/), not in a runtime directory: this is the document a client's auditor,
# or a lawyer, would ask for.
cmd_report() {
  local id="" open=0
  while [ $# -gt 0 ]; do case "$1" in --open) open=1; shift ;; *) id="$1"; shift ;; esac; done
  local slug ts out
  ts=$(date -Is)
  slug="${id:-incident-$(date +%Y%m%dT%H%M%S)}"
  local shelf="$H/hodd/security/incidents"; mkdir -p "$shelf" || exit 1
  out="$shelf/${slug}-report.md"

  local mode classes bites findings_n
  mode=$(bash "$BITE" status 2>/dev/null | sed -n 's/.*"switch","\([a-z]*\)".*/\1/p')
  bites=$(bash "$BITE" status 2>/dev/null | sed -n 's/.*"bites taken","\([0-9]*\)".*/\1/p')
  classes=$(python3 - "$H/config/garmr-rules.yaml" <<'PY'
import sys
try:
    import yaml; d = yaml.safe_load(open(sys.argv[1])) or {}
    print(", ".join(d.get("enabled") or []) or "none armed")
except Exception:
    print("no rules file — every finding is a bark")
PY
)
  local ff="$H/../state/garmr/findings.jsonl"; [ -r "$ff" ] || ff="/var/log/ymir/garmr/findings.jsonl"
  findings_n=$(wc -l < "$ff" 2>/dev/null | tr -d ' ' || echo 0)

  {
    echo "# Incident report — ${slug}"
    echo
    echo "**Written:** ${ts} · **By:** Víðarr, the defender (the hand) · **Ledger:** a rune is carved with this file's name."
    echo
    echo "## What the machine stands as"
    echo
    echo "| Field | Value |"
    echo "|---|---|"
    echo "| switch | \`${mode:-report}\` (off · report · contain · hard) |"
    echo "| armed classes | ${classes} |"
    echo "| bites taken (all time) | ${bites:-0} |"
    echo "| findings on this seat | ${findings_n} |"
    echo
    echo "## What was seen"
    echo
    echo '```'
    tail -20 "$ff" 2>/dev/null | head -c 4000 || echo "no findings file readable"
    echo '```'
    echo
    echo "## What was decided, and by what"
    echo
    echo "A bite requires a **written rule** (\`garmr-rules.yaml\`); an uncovered CRITICAL may be put to the"
    echo "advisor (opencode-go/deepseek-v4.1-flash, metadata only), whose answer is validated against the"
    echo "allowlist and against the armed classes. Nothing here was decided by a model acting alone."
    echo
    echo "## The bites in the ledger"
    echo
    echo '```'
    grep -F "garmr.bite" "$H/hodd/memory/runes_audit.md" 2>/dev/null | tail -20 | cut -c1-300 || echo "no bites recorded"
    echo '```'
    echo
    echo "## Evidence"
    echo
    if [ -n "$id" ] && [ -d "$INC/$id" ]; then
      echo "- bundle: \`$INC/$id/evidence.txt\`"
      echo "- hash: \`$(cut -d' ' -f1 "$INC/$id/evidence.sha256" 2>/dev/null)\`"
    else
      echo "- no incident bundle attached to this report"
    fi
    echo
    echo "## What is still owed"
    echo
    echo "- A false-positive count for the first week of \`contain\` (if it fired on the operator's own"
    echo "  traffic, the RULE is wrong, not the machine)."
    echo "- Recovery: containment stops the bleeding; restoring a service is Eir's craft, not Víðarr's."
    echo "- Nothing left this machine. A blocked destination is a door WE closed, never a counter-strike."
  } > "$out"

  runes incident.report "id=$slug file=$out mode=${mode:-report} bites=${bites:-0}"
  [ "$open" = 1 ] && cmd_incident open "report ${slug}" >/dev/null 2>&1
  printf 'vidarr[3]{report,path,ledger}:\n  "%s","%s","a rune carries its name"\n' "$slug" "$out"
}

CMD="${1-}"; shift || true
case "$CMD" in
  status) cmd_status ;;
  respond) cmd_respond "$@" ;;
  incident) cmd_incident "$@" ;;
  evidence) cmd_evidence "$@" ;;
  report) cmd_report "$@" ;;
  stand-down) cmd_stand_down ;;
  *) printf 'vidarr[1]{error}: "unknown command: %s" · help: "vidarr.sh --help"\n' "$CMD" >&2; exit 2 ;;
esac
