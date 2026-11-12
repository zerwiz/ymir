#!/usr/bin/env bash
# groa-verdict-lib.sh — how Gróa's update ends: whole, or owed, and never "done" when it is not (plan 278).
#
# Sourced by bin/agents/groa-update.sh; pure functions, so a test can drive them with no real update.
#
#   groa_owed_from <eir-output>                 the `owed: <surface> <risk>` lines Eir printed, as "surface risk"
#   groa_accepted <file>                        surfaces the operator accepted as owed on this machine, one per line
#   groa_verdict <owed> <stopped> <accepted>    prints the closing line(s); returns 0 whole · 4 not whole
#   groa_fault_report <dir> <owed> <stopped>    writes one dated report when the owed set changed (plan 275 B)
#
# The accepted list lives in the home (`$YMIR_HOME/config/owed-accepted.txt`): a surface the operator has
# looked at and said "leave it" is still NAMED in the closing line, but it no longer makes the update fail.
# Nothing in this file names a machine, a user or a path (RULES/04).

groa_owed_from() {  # <text> → "surface risk" per line
  printf '%s\n' "${1-}" | sed -n 's/^owed: \([A-Za-z0-9_]*\) \(safe\|ask\|never\)$/\1 \2/p'
}

groa_accepted() {  # <file> → surface names, comments and blanks dropped
  [ -r "${1-}" ] || return 0
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$1" | grep -v '^$' || true
}

groa_verdict() {  # <owed-lines> <stopped-steps> <accepted-names> → closing line; rc 0 whole, 4 not whole
  local owed="${1-}" stopped="${2-}" accepted="${3-}" s r failing="" held="" cmds=""
  while read -r s r; do
    [ -n "$s" ] || continue
    if printf '%s\n' "$accepted" | grep -qxF "$s"; then
      held="${held:+$held, }$s"
      continue
    fi
    failing="${failing:+$failing, }$s ($r)"
    case "$r" in
      never) cmds="${cmds}  $s: report only — read its row in bin/agents/eir-doctor.sh check\n" ;;
      *)     cmds="${cmds}  $s: bin/agents/eir-doctor.sh fix $s\n" ;;
    esac
  done <<EOF
$owed
EOF
  stopped="$(printf '%s' "$stopped" | sed 's/^ *//; s/ *$//; s/  */, /g')"
  if [ -z "$failing" ] && [ -z "$stopped" ]; then
    printf 'groa-update: whole — every surface answers%s\n' "${held:+ (accepted as owed: $held)}"
    return 0
  fi
  printf 'groa-update: NOT whole —'
  [ -n "$failing" ] && printf ' owed: %s;' "$failing"
  [ -n "$stopped" ] && printf ' steps stopped at their limit: %s;' "$stopped"
  [ -n "$held" ] && printf ' accepted as owed: %s;' "$held"
  printf '\n'
  [ -n "$cmds" ] && printf 'groa-update: the exact commands —\n%b' "$cmds"
  [ -n "$stopped" ] && printf '  a stopped step: run it by hand to see why (YMIR_GROA_STEP_TIMEOUT_<STEP> raises its limit)\n'
  return 4
}

groa_fault_report() {  # <dir> <owed-lines> <stopped> → path of a NEW report, or nothing when unchanged
  local dir="${1-}" owed="${2-}" stopped="${3-}" body last stamp f
  [ -n "$dir" ] || return 0
  [ -n "$owed$stopped" ] || return 0
  body="$(printf 'owed:\n%s\nstopped: %s\n' "$(printf '%s\n' "$owed" | sed '/^$/d' | sort)" "$(printf '%s' "$stopped" | tr -s ' ' | sed 's/^ //')")"
  mkdir -p "$dir" 2>/dev/null || return 0
  last="$(ls -1 "$dir"/*-surfaces.md 2>/dev/null | sort | tail -1)"
  # A fault already reported and unchanged is not reported again (plan 275: one smith per new fault).
  if [ -n "$last" ] && [ "$(sed -n '/^```text$/,/^```$/p' "$last" | sed '1d;$d')" = "$body" ]; then
    return 0
  fi
  stamp="$(date -u '+%Y-%m-%dT%H%M%SZ')"
  f="$dir/$stamp-surfaces.md"
  {
    printf '# Gróa: the update left surfaces owed\n\n'
    printf 'Written %s by `bin/agents/groa-update.sh` on a seat of role `%s`, at commit `%s`.\n\n' \
      "$stamp" "${GROA_ROLE:-unknown}" "${GROA_COMMIT:-unknown}"
    printf 'This is the brief for the one smith an update may send (plan 275). Each row names a surface, its risk\n'
    printf 'class from `config/surfaces.yaml`, and the command that mends it. Read `bin/agents/eir-doctor.sh check`\n'
    printf 'for the reason on each row.\n\n'
    printf '```text\n%s\n```\n' "$body"
  } >"$f" 2>/dev/null || return 0
  printf '%s\n' "$f"
}
