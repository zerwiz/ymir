#!/usr/bin/env bash
# agnostic-audit.sh — the public repository, judged agnostic (RULES/04, RULES/25, plan 287).
#
# THE LAW THIS JUDGES. `~/ymir` is 100 % agnostic: it carries the engine, the apps, the tools, the
# gates, the templates and the documents that teach them — never the operator's own life (people,
# clients, companies, mail domains, NDAs, meetings) and never an assumption about his fleet (host
# names, user names, tailnet names, a machine count). Those live in the operator's home and are read
# from there. This door looks for them in the tree.
#
#   agnostic-audit.sh                    the AUDIT: every tracked file (what the twice-daily job runs)
#   agnostic-audit.sh --ref origin/main  the same, over a fetched ref instead of the working tree
#   agnostic-audit.sh check [FILE...]    the WARD: only what a push ADDS (bin/gates/guards.sh, pre-push)
#   agnostic-audit.sh --list             the classes and the scope — never the words
#
# WHAT IS JUDGED. Two families, and the second is always on so a machine with no list still judges:
#
#   1. the operator's own words, read AT RUN TIME from the home
#      (`$YMIR_HOME/hodd/identity/public-deny.txt`; shape: `hodd/identity/public-deny.txt.example`).
#      Each entry is one of three kinds, because a word scan cannot tell a machine from a figure of
#      the lore (the ward paid for that lesson in plan 278):
#        name:<word>     a person, a client, a company — anywhere in the line
#        host:<word>     a machine or user name — only where it is USED as a host or a user:
#                        after a mailbox `@`, a URL's double slash, `/home/`, a `host=` or
#                        `host:` setting, or `ssh `. A name in prose is not a host, and that
#                        is how a lore name stays public craft while the box that bears it
#                        stays private.
#        domain:<word>   a mail or client domain — anywhere, on a domain boundary (`@` counts)
#      A bare word is `name:`.
#   2. the generic shapes no fleet may publish: a CONCRETE private address (a CIDR range and RFC 5737
#      documentation space are allowed — they are documentation, not a place this house stands) and a
#      real host before `ts.net` (`<host>.tailnet.ts.net` is the placeholder, so it passes).
#
# THE LIST IS NEVER PRINTED (RULES/18). A finding names the file, the line, and WHICH entry of the
# home's list matched — by its position, never by repeating the word. The report is written for a
# person (RULES/52): the findings come first in plain prose, the machine row is the last line.
#
# TWO POSTURES, AND WHY THEY DIFFER:
#   · the AUDIT judges the whole tree and fails on every finding. That is the number that must reach
#     zero (plan 287 phases P2/P3), and it is what the heart's clock runs twice a day.
#   · the WARD judges only what a push ADDS. A finding already present on the base revision is printed
#     `inherited` and never refuses the push — a gate that refuses every push over history it did not
#     write is a gate the house learns to walk around (plan 243 §3, part D).
#
# Usage:
#   agnostic-audit.sh [tree] [--ref REF] [--root DIR] [--deny FILE] [--quiet]
#   agnostic-audit.sh check [FILE...] [--base REF] [--root DIR] [--deny FILE]
#   agnostic-audit.sh --list
#
# Environment (Rule 07 — one documented default each):
#   YMIR_HOME              resolved through bin/vault/hoard-lib.sh when unset
#   YMIR_DENY_LIST         the list (default <home>/hodd/identity/public-deny.txt)
#   YMIR_AUDIT_BASE        the base the ward diffs from (default origin/main, then main)
#   YMIR_AUDIT_MAX_REPORT  findings printed before "… and N more" (default 200)
#
# Exit: 0 clean (a machine with no list says so — a clean skip is a pass, RULES/25) · 1 findings · 2 usage.
set -u
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root() {
  local d="$SCRIPT_DIR"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$SCRIPT_DIR/../.." && pwd)"
}
ROOT="$(_root)"

# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
HOME_DIR=""
[ -n "${YMIR_HOME:-}" ] && HOME_DIR="$YMIR_HOME"
if [ -z "$HOME_DIR" ] && declare -f ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR 2>/dev/null || true; fi
DENY_FILE="${YMIR_DENY_LIST:-${HOME_DIR:+$HOME_DIR/hodd/identity/public-deny.txt}}"
BASE_REF="${YMIR_AUDIT_BASE:-}"
MAX_REPORT="${YMIR_AUDIT_MAX_REPORT:-200}"
REF=""; MODE="tree"; QUIET=0
SCOPE=()

usage() { sed -n '2,57p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage ;;
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    --list) MODE="list"; shift ;;
    --ref) REF="${2:?--ref needs a git ref}"; shift 2 ;;
    --ref=*) REF="${1#*=}"; shift ;;
    --root) ROOT="${2:?--root needs a directory}"; shift 2 ;;
    --root=*) ROOT="${1#*=}"; shift ;;
    --deny) DENY_FILE="${2:?--deny needs a file}"; shift 2 ;;
    --deny=*) DENY_FILE="${1#*=}"; shift ;;
    --base) BASE_REF="${2:?--base needs a ref}"; shift 2 ;;
    --base=*) BASE_REF="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    tree|audit) MODE="tree"; shift ;;
    check|ward) MODE="check"; shift ;;
    --) shift; while [ $# -gt 0 ]; do SCOPE+=("$1"); shift; done ;;
    -*) printf 'error: unknown flag %s\nhelp: agnostic-audit.sh [tree|check] [FILE...] [--ref REF]\n' "$1" >&2; exit 2 ;;
    *) SCOPE+=("$1"); shift ;;
  esac
done
if [ "$MODE" != "check" ] && [ "${#SCOPE[@]}" -gt 0 ]; then
  printf 'error: the tree posture takes no files\nhelp: agnostic-audit.sh check FILE...\n' >&2; exit 2
fi
case "$MAX_REPORT" in ''|*[!0-9]*) MAX_REPORT=200 ;; esac

# ── the deny list: read, never echoed ────────────────────────────────────────────────────────────
# Three classes, three alternations, one index per entry so a finding can name WHICH entry matched
# without printing it. A home with no list is a clean skip that SAYS SO; the generic shapes still run.
ENTRIES=0
DENY_STATE="absent"
declare -A IDX=()                 # lowercased entry -> its position in the list (1-based)
declare -a NAME_ALT=() HOST_ALT=() DOM_ALT=() ALL_ALT=()
declare -a ALL_LOWER=() ALL_POS=()   # the same entries, lowercased, with their position

re_escape() { printf '%s' "$1" | sed -e 's/[][\.^$*+?(){}|/]/\\&/g'; }

if [ -n "$DENY_FILE" ] && [ -r "$DENY_FILE" ]; then
  DENY_STATE="loaded"
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || continue
    case "$line" in \#*) continue ;; esac
    kind="name"; val="$line"
    case "$line" in name:*|host:*|user:*|domain:*) kind="${line%%:*}"; val="${line#*:}" ;; esac
    val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
    [ -n "$val" ] || continue
    [ "$kind" = "user" ] && kind="host"
    n=$((n + 1))
    IDX["$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')"]="$n"
    esc="$(re_escape "$val")"
    ALL_ALT+=("$esc")
    ALL_LOWER+=("$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')")
    ALL_POS+=("$n")
    case "$kind" in
      host)   HOST_ALT+=("$esc") ;;
      domain) DOM_ALT+=("$esc") ;;
      *)      NAME_ALT+=("$esc") ;;
    esac
  done <"$DENY_FILE"
  ENTRIES="$n"
fi

join_alt() { local IFS='|'; printf '%s' "$*"; }

# ── the classes ─────────────────────────────────────────────────────────────────────────────────
NAMES_ERE=""; HOSTS_ERE=""; DOMS_ERE=""; ALL_ERE=""
[ "${#ALL_ALT[@]}" -gt 0 ] && ALL_ERE="($(join_alt "${ALL_ALT[@]}"))"
[ "${#NAME_ALT[@]}" -gt 0 ] && NAMES_ERE="($(join_alt "${NAME_ALT[@]}"))"
[ "${#DOM_ALT[@]}"  -gt 0 ] && DOMS_ERE="(^|[^[:alnum:].-])($(join_alt "${DOM_ALT[@]}"))([^[:alnum:]-]|$)"
if [ "${#HOST_ALT[@]}" -gt 0 ]; then
  # A HOST is judged where it is USED as one: after a mailbox @, a double slash, /home/, /Users/,
  # host=/host:/hostname=, user=/user:, `ssh ` or `scp `; and only where it ENDS a word, so a
  # name never matches a longer one. Prose that merely says the name is not a host (plan 278).
  HOSTS_ERE="(@|//|/home/|/Users/|host(name)?[[:space:]]*[=:][[:space:]\"']*|user(name)?[[:space:]]*[=:][[:space:]\"']*|ssh[[:space:]]+|scp[[:space:]]+)($(join_alt "${HOST_ALT[@]}"))([^[:alnum:]_-]|$)"
fi
# FOUR SEATS, THE WHOLE ADDRESS. The first spelling of this pattern wrote the block as a two-octet
# prefix and then demanded three octets after it, so an ordinary private address in the 192.168
# block walked through the ward that exists to stop it (found by the canary, 2026-11-14). Each
# range now carries all four octets.
IP_ERE='(^|[^0-9./])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3})'
# A RANGE is documentation, a documentation net is a placeholder, and a sentinel is the first host of
# the range it classifies. None of them is a place this house stands.
IP_ALLOW='(/8|/10|/12|/16|/24|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|127\.0\.0\.1|0\.0\.0\.0|169\.254\.169\.254|(^|[^0-9.])10\.0\.0\.0|172\.16\.0\.0|192\.168\.0\.0|100\.64\.0\.1)([^0-9]|$)'
TSNET_ERE='\b[a-z0-9][a-z0-9-]*\.(tail[a-z0-9]*\.)?ts\.net\b'
# `<host>.tailnet.ts.net`, `tailnet.ts.net`, `tail.ts.net` and the bracketed placeholders are the SHAPE.
TSNET_ALLOW='(<host>|<seat>|<machine>|<tailnet>|<node>)?\.?(tailnet|tail)\.ts\.net'

if [ "$MODE" = "list" ]; then
  printf 'agnostic-audit — what this door judges (the words themselves are never printed)\n\n'
  printf '  the operator'"'"'s words   %s entries read from %s\n' "$ENTRIES" "${DENY_FILE:-<no home resolves>}"
  printf '    name:<word>       a person, client or company — anywhere, whole word\n'
  printf '    host:<word>       a machine or user — only where it is used as a host or a user\n'
  printf '    domain:<word>     a mail or client domain — anywhere, on a domain boundary\n'
  printf '  the generic shapes   a concrete private address (a range is documentation)\n'
  printf '                       a real host before ts.net (a placeholder passes)\n'
  printf '  never printed        the list itself: a finding names the file, the line and the entry'"'"'s position\n'
  exit 0
fi

# ── gathering the hits ─────────────────────────────────────────────────────────────────────────
# ONE git grep per class over the whole tree. The old shape — a loop and a grep per file — took
# minutes on 6,000 files, and a gate too slow to run is a gate that gets skipped.
cd "$ROOT" || { printf 'agnostic-audit: %s is not a directory\n' "$ROOT" >&2; exit 2; }
if [ -n "$REF" ]; then
  git rev-parse -q --verify "$REF^{commit}" >/dev/null 2>&1 || {
    printf 'agnostic-audit: the ref %s does not resolve in %s\nhelp: fetch it first (git fetch origin main)\n' "$REF" "$ROOT" >&2
    exit 2
  }
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/agnostic-audit-XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT
RAW="$WORK/raw"          # path<TAB>line<TAB>class<TAB>the line as it stands
: >"$RAW"

# THE SCOPE IS DECIDED BEFORE THE FIRST GREP. It used to be decided after them, so the CI posture
# (`check` with no files) greps the whole tree and then labelled every hit inherited — the verdict
# was right, the work was wrong, and on a tree with a real leak the census was the only thing judging.
if [ "$MODE" = "check" ]; then
  if [ -z "$BASE_REF" ]; then
    for b in origin/main origin/master main; do
      git rev-parse -q --verify "$b" >/dev/null 2>&1 && { BASE_REF="$b"; break; }
    done
  fi
  if [ "${#SCOPE[@]}" -eq 0 ]; then
    # The ward called with no files (CI's --full posture): the push's own diff is the scope.
    { git diff --name-only --no-renames "${BASE_REF:-HEAD}" 2>/dev/null
      git diff --name-only --no-renames --cached 2>/dev/null
      git ls-files --others --exclude-standard 2>/dev/null; } | sort -u >"$WORK/scope"
    mapfile -t SCOPE <"$WORK/scope"
  fi
fi

grep_pass() {  # <class-label> <ERE> [<allow-ERE>]
  local class="$1" ere="$2" allow="${3:-}"
  local out="$WORK/pass.out"
  : >"$out"
  if [ "$MODE" = "check" ] && [ "${#SCOPE[@]}" -gt 0 ]; then
    if [ -n "$REF" ]; then git grep -I -n -i -E -e "$ere" "$REF" -- "${SCOPE[@]}" >"$out" 2>/dev/null
    else git grep -I -n -i -E --untracked -e "$ere" -- "${SCOPE[@]}" >"$out" 2>/dev/null; fi
  else
    if [ -n "$REF" ]; then git grep -I -n -i -E -e "$ere" "$REF" -- . >"$out" 2>/dev/null
    else git grep -I -n -i -E --untracked -e "$ere" -- . >"$out" 2>/dev/null; fi
  fi
  [ -s "$out" ] || return 0
  while IFS= read -r row || [ -n "$row" ]; do
    [ -n "$row" ] || continue
    # A ref search prefixes every row with `<ref>:` — strip it BEFORE parsing, or the path
    # becomes the ref and the line number becomes the path.
    [ -n "$REF" ] && row="${row#"$REF":}"
    local p="${row%%:*}" rest="${row#*:}" ln text
    ln="${rest%%:*}"; text="${rest#*:}"
    case "$ln" in ''|*[!0-9]*) continue ;; esac
    if [ -n "$allow" ] && printf '%s' "$text" | grep -qE -- "$allow"; then continue; fi
    printf '%s\t%s\t%s\t%s\n' "$p" "$ln" "$class" "$text" >>"$RAW"
  done <"$out"
  return 0
}

[ -n "$NAMES_ERE" ] && grep_pass "a person, client or company of the operator's" "$NAMES_ERE"
[ -n "$DOMS_ERE"  ] && grep_pass "the operator's own domain" "$DOMS_ERE"
[ -n "$HOSTS_ERE" ] && grep_pass "a machine or user of the operator's, named as a host" "$HOSTS_ERE"
grep_pass "a private address, not a range" "$IP_ERE" "$IP_ALLOW"
grep_pass "a real tailnet host, not a placeholder" "$TSNET_ERE" "$TSNET_ALLOW"

awk -F'\t' '{ k=$1"\t"$2"\t"$3; if (!(k in seen)) { seen[k]=1; print } }' "$RAW" >"$WORK/unique"

if [ -n "$REF" ]; then FILES_JUDGED="$(git ls-tree -r --name-only "$REF" 2>/dev/null | wc -l | tr -d ' ')"
else FILES_JUDGED="$(git ls-files | wc -l | tr -d ' ')"; fi

# ── the ward's question: is this hit NEW, or was it already on the base? ────────────────────────
BASE_USED=""
declare -A ADDED=()    # "path:line" (or "path:*" for a whole new file) -> 1
if [ "$MODE" = "check" ]; then
  if [ -n "$BASE_REF" ] && git rev-parse -q --verify "$BASE_REF^{commit}" >/dev/null 2>&1; then
    BASE_USED="$BASE_REF"
    for f in "${SCOPE[@]}"; do
      [ -n "$f" ] || continue
      if ! git cat-file -e "$BASE_USED:$f" 2>/dev/null; then
        ADDED["$f:*"]=1        # a file the base does not carry is entirely new
        continue
      fi
      while IFS= read -r n; do
        [ -n "$n" ] && ADDED["$f:$n"]=1
      done < <(git diff -U0 --no-renames "$BASE_USED" -- "$f" 2>/dev/null | awk '
        /^@@/ { split($3, p, ","); start = substr(p[1], 2) + 0; len = (p[2] == "" ? 1 : p[2] + 0)
                for (i = 0; i < len; i++) print start + i }')
    done
  fi
fi

# ── the report: for a person, then one row for a machine ────────────────────────────────────────
FINDINGS=0; NEW=0; INHERITED=0
: >"$WORK/report"
declare -A FILE_HITS=()
while IFS=$'\t' read -r p ln class text; do
  [ -n "$p" ] || continue
  FINDINGS=$((FINDINGS + 1))
  FILE_HITS["$p"]=1
  tag=""
  if [ "$MODE" = "check" ]; then
    if [ -n "${ADDED["$p:*"]:-}" ] || [ -n "${ADDED["$p:$ln"]:-}" ]; then NEW=$((NEW + 1))
    else tag="  (inherited — already on ${BASE_USED:-the base})"; INHERITED=$((INHERITED + 1)); fi
  fi
  # WHICH entry of the home's list matched — by position, never by printing the word (RULES/18).
  # Pure bash on purpose: one process per finding made this loop the whole cost of the audit.
  which=""
  if [ "${#ALL_LOWER[@]}" -gt 0 ]; then
    low="${text,,}"; best=0; i=0
    while [ "$i" -lt "${#ALL_LOWER[@]}" ]; do
      cand="${ALL_LOWER[$i]}"
      case "$low" in
        *"$cand"*) [ "${#cand}" -gt "$best" ] && { best="${#cand}"; which="${ALL_POS[$i]}"; } ;;
      esac
      i=$((i + 1))
    done
  fi
  label="$class"
  [ -n "$which" ] && label="$class (home entry $which)"
  printf '%s:%s\t%s\t%s\n' "$p" "$ln" "$label" "$tag" >>"$WORK/report"
done <"$WORK/unique"

FILES_HIT="${#FILE_HITS[@]}"

if [ "$QUIET" = 0 ]; then
  printf 'agnostic-audit — the public repository, judged agnostic (RULES/04 · plan 287)\n\n'
  if [ "$MODE" = "check" ]; then
    printf 'scope: what this push ADDS in %s file(s), against %s\n' "${#SCOPE[@]}" \
      "${BASE_USED:-a base that does not resolve, so every hit counts}"
  elif [ -n "$REF" ]; then
    printf 'scope: every file at %s — %s tracked file(s), read from the ref, not the working tree\n' "$REF" "$FILES_JUDGED"
  else
    printf 'scope: every tracked file — %s file(s)\n' "$FILES_JUDGED"
  fi
  if [ "$DENY_STATE" = "loaded" ]; then
    printf 'the operator'"'"'s words: %s entries, read from the home. Never printed (RULES/18)\n' "$ENTRIES"
  else
    printf 'the operator'"'"'s words: NONE READ — %s\n' "$(basename "${DENY_FILE:-no home resolves}")"
    printf '  this is not a pass: only the generic shapes (a private address, a tailnet host) were judged.\n'
    printf '  shape: hodd/identity/public-deny.txt.example · plan 287 phase P1\n'
  fi
  printf '\n'
  if [ "$FINDINGS" -eq 0 ]; then
    printf 'nothing found. The tree carries no name, host or address of the operator'"'"'s, and no generic shape.\n'
  else
    if [ "$MODE" = "check" ]; then
      printf 'findings: %s (%s new in this push · %s inherited, not this push'"'"'s to fix)\n\n' "$FINDINGS" "$NEW" "$INHERITED"
    else
      printf 'findings: %s in %s file(s)\n\n' "$FINDINGS" "$FILES_HIT"
    fi
    shown=0
    while IFS=$'\t' read -r where label tag; do
      [ -n "$where" ] || continue
      [ "$shown" -ge "$MAX_REPORT" ] && break
      printf '  %-58s %s%s\n' "$where" "$label" "$tag"
      shown=$((shown + 1))
    done <"$WORK/report"
    [ "$FINDINGS" -gt "$shown" ] && printf '  … and %s more (YMIR_AUDIT_MAX_REPORT raises the cap)\n' "$((FINDINGS - shown))"
    printf '\nhelp: an example uses an invented person, an invented domain and a placeholder host\n'
    printf '      (Ada, example.org, host-a); a note names a ROLE, not a machine; whatever is the\n'
    printf '      operator'"'"'s own life or tooling lives in the home, never here (RULES/04, RULES/25).\n'
  fi
  printf '\n'
fi

# One machine row, last, so a job or a page reads the verdict without parsing prose.
if [ "$MODE" = "check" ]; then
  verdict=CLEAN; [ "$NEW" -gt 0 ] && verdict=FAIL
  printf 'agnostic_audit[1]{scope,findings,files,entries,new,inherited,verdict}:\n  "%s","%s","%s","%s","%s","%s","%s"\n' \
    "this push" "$FINDINGS" "${#SCOPE[@]}" "$ENTRIES" "$NEW" "$INHERITED" "$verdict"
  [ "$NEW" -gt 0 ] || exit 0
  printf 'agnostic-audit: %s new finding(s) — what this push would publish belongs in the home (RULES/04)\n' "$NEW" >&2
else
  verdict=CLEAN; [ "$FINDINGS" -gt 0 ] && verdict=FAIL
  printf 'agnostic_audit[1]{scope,findings,files,entries,verdict}:\n  "%s","%s","%s","%s","%s"\n' \
    "$([ -n "$REF" ] && printf '%s' "$REF" || printf 'the tree')" "$FINDINGS" "$FILES_HIT" "$ENTRIES" "$verdict"
  [ "$FINDINGS" -gt 0 ] || exit 0
  printf 'agnostic-audit: %s finding(s) — the public tree carries what belongs in the home (RULES/04)\n' "$FINDINGS" >&2
fi
exit 1
