#!/usr/bin/env bash
# plan.sh — the plan ledger: create the NEXT numbered plan and its index row.
#
#   plan.sh new <slug> --title "<title>" [--scope S] [--owner O] [--host H] [--realm R]
#                                        [--project P] [--from-meeting <id>] [--new-shelf]
#   plan.sh route <slug> --title "<title>"   # WHERE a plan belongs — files nothing (plan 311)
#   plan.sh list                      # the ledger's rows (number · title · status)
#   plan.sh next                      # the number the next plan would take (read-only)
#   plan.sh from-meeting <id>         # the plans a meeting produced (reads the headers)
#   plan.sh shelves                   # every realm and project folder, and whether it has a shelf
#   plan.sh check                     # one pad width per shelf; two shapes on one shelf is a fault
#   add --new-shelf to `new` to open a known project's first shelf (never for an unknown one)
#
# `--from-meeting <id>` writes `from_meeting: <id>` into the plan's HEADER, in the same act
# as the plan is created — the join from a meeting to what it produced (plan 228 §5 · F5).
# The reverse join lives in `bin/records/meetings.sh plans <id>`, which reads these headers
# and refuses rather than guessing when a plan carries none.
#
# THE LEDGER (the house law): a plan belongs to whoever owns the work — plan 240.
#
#   --scope project   (default)  svartalfaheim/<realm>/projects/<project>/plans/
#   --scope realm     (company)  svartalfaheim/<realm>/plans/
#   --scope machine              hodd/machines/<host>/plans/   (--host names WHICH machine)
#   --scope personal             hodd/plans/
#
# THE HOST IS A PARAMETER, NEVER AN ASSUMPTION (plan 311 §2). `--scope machine` used to mean
# "this host", so a plan about the heart was filed on the laptop's shelf while it was written.
# `--host zerwizserver` files it on the heart's shelf from any seat; a host the fleet registry
# does not know is refused BY NAME rather than given a shelf nobody reads.
#
# THE ROUTE ABOVE THE LEDGER (plan 311 §3). With no --scope named, `new` (and `route`, which
# only reports) asks the registries that already exist — hodd/identity/projects.yaml for what a
# project is, hodd/identity/services.yaml for what a hosted surface is — and refuses two kinds of
# work instead of filing them here: Gimlé's (a hosted surface, whose plans live with its own code)
# and a card (the board holds it). Machine work goes to that machine's shelf, naming the host;
# personal work to hodd/plans/. A named --scope is the caller's word and is always honoured.
#
# Numbering is per shelf, after its index's highest; a number is never reused IN a shelf, and a
# shelf has ONE pad width (`check` reports a shelf carrying two).
# A shelf under a scope that is allowed to grow (realm · machine · personal) is created on
# first use with its index; a PROJECT shelf is never created silently — an unknown project
# is a typo, and guessing it would file work in a directory nobody reads.
# Extracted from the Pi extension so every harness reaches it (behaviour in bin/).
set -uo pipefail
# the bash floor (RULES/05): macOS ships bash 3.2 — re-run under bash >= 4, or say how to get one
[ "${BASH_VERSINFO[0]:-0}" -ge 4 ] || { . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../fleet/ymir-platform.sh" && ymir_bash_floor "$@"; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
hoard="$(bash "$ROOT/bin/vault/hodd.sh" path 2>/dev/null || true)"
[ -n "$hoard" ] || { printf 'plan: no home (bin/vault/hodd.sh path answered nothing)\n' >&2; exit 1; }
HOME_DIR="$(dirname "$hoard")"
REALM="${YMIR_REALM:-work}"; PROJECT="${YMIR_PROJECT:-ymir}"
SCOPE="${YMIR_PLAN_SCOPE:-project}"; OWNER=""
HOST=""          # --host: WHICH machine's shelf (plan 311 §2); empty means this host
REALM_GIVEN=0     # 1 when --realm is passed: then the realm is a fact, not a preference
SCOPE_GIVEN=0     # 1 when --scope is passed: the caller's word beats the router
NEW_SHELF=0       # 1 when --new-shelf is passed: a known project may get its first shelf
LEDGER=""

# ── the project's shelf is FOUND, after the arguments are read, never guessed ──
# WHY (2026-11-12): the shelf was resolved at the top of this file from the defaults, before
# `--realm` and `--project` were parsed, so `plan.sh new … --realm R --project P` filed the
# plan in the DEFAULT project's ledger. Three stubs for three other projects landed as plans
# 280–282 of another project's ledger. It also made every command fail in a home that has no
# project of the default name, which is any user's home but one. Now: any realm, any project,
# found by its folder; a name in two realms is refused with both named; a project folder with
# no shelf is refused unless --new-shelf says to open one.
resolve_project_ledger() {   # <project> — sets LEDGER or explains and returns 2
  local p="$1" base="$HOME_DIR/svartalfaheim" k d hits=() dirs=()
  [ -n "$p" ] || { printf 'plan: no project named (--project P)\n' >&2; return 2; }
  if [ -n "$REALM" ]; then
    for k in projects workspace; do
      [ -d "$base/$REALM/$k/$p/plans" ] && { LEDGER="$base/$REALM/$k/$p/plans"; return 0; }
    done
  fi
  if [ "$REALM_GIVEN" = 0 ]; then
    mapfile -t dirs < <(find "$base" -mindepth 3 -maxdepth 3 -type d \( -path "$base/*/projects/$p" -o -path "$base/*/workspace/$p" \) 2>/dev/null | sed -E 's#/(projects|workspace)/[^/]+$##' | sort -u)
    if [ "${#dirs[@]}" -gt 1 ]; then
      printf 'plan: REFUSED — a project called %s is in more than one realm; name it with --realm:\n' "$p" >&2
      for d in "${dirs[@]}"; do printf '  %s\n' "${d#$HOME_DIR/}" >&2; done
      return 2
    fi
    dirs=()
    for k in projects workspace; do
      mapfile -t hits < <(find "$base" -mindepth 4 -maxdepth 4 -type d -path "$base/*/$k/$p/plans" 2>/dev/null | sort)
      [ "${#hits[@]}" = 1 ] && { LEDGER="${hits[0]}"; return 0; }
      if [ "${#hits[@]}" -gt 1 ]; then
        printf 'plan: REFUSED — the project %s has a shelf in more than one realm; name it with --realm:\n' "$p" >&2
        for d in "${hits[@]}"; do printf '  %s\n' "${d#$HOME_DIR/}" >&2; done
        return 2
      fi
    done
  fi
  # no shelf: is there a project folder at all?
  if [ "$REALM_GIVEN" = 1 ]; then
    for k in projects workspace; do [ -d "$base/$REALM/$k/$p" ] && dirs+=("$base/$REALM/$k/$p"); done
  else
    mapfile -t dirs < <(find "$base" -mindepth 3 -maxdepth 3 -type d \( -path "$base/*/projects/$p" -o -path "$base/*/workspace/$p" \) 2>/dev/null | sort)
  fi
  if [ "${#dirs[@]}" = 0 ]; then
    printf 'plan: REFUSED — no project folder called %s%s; a plan is never filed for a project that does not exist.\n' "$p" "$([ "$REALM_GIVEN" = 1 ] && printf ' in the realm %s' "$REALM")" >&2
    printf 'plan: see every project and its shelf with  plan.sh shelves\n' >&2
    project_candidates "$p" >&2
    return 2
  fi
  if [ "${#dirs[@]}" -gt 1 ]; then
    printf 'plan: REFUSED — a project folder called %s is in more than one realm; name it with --realm:\n' "$p" >&2
    for d in "${dirs[@]}"; do printf '  %s\n' "${d#$HOME_DIR/}" >&2; done
    return 2
  fi
  if [ "$NEW_SHELF" = 1 ]; then
    LEDGER="${dirs[0]}/plans"
    mkdir -p "$LEDGER" || { printf 'plan: cannot create %s\n' "$LEDGER" >&2; return 2; }
    [ -f "$LEDGER/README.md" ] || printf '# %s — the plans\n\nOne file per plan, numbered in order, never renumbered. A plan is appended to, never rewritten.\n\n| # | Plan | State |\n|---|---|---|\n' "$p" > "$LEDGER/README.md"
    printf 'plan: opened the first shelf for %s at %s\n' "$p" "${LEDGER#$HOME_DIR/}" >&2
    return 0
  fi
  printf 'plan: REFUSED — the project %s (%s) has no plans shelf yet; open one with --new-shelf\n' "$p" "${dirs[0]#$HOME_DIR/}" >&2
  return 2
}

# ── WHICH MACHINE (plan 311 §2) — the host is a parameter, never an assumption ──
this_host() { printf '%s' "${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"; }
fleet_registry() { printf '%s' "${YMIR_FLEET_REGISTRY:-$HOME_DIR/hodd/data/fleet.json}"; }

# Every machine the fleet registry names. Without a registry, the machine folders are the answer;
# with neither, only this host is known — never a guess dressed as a fact.
known_hosts() {
  local reg; reg="$(fleet_registry)"
  if [ -f "$reg" ]; then
    python3 -c 'import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
print("\n".join(sorted(d.get("hosts") or {})))' "$reg" 2>/dev/null | grep -v '^$' && return 0
  fi
  ls -d "$HOME_DIR"/hodd/machines/*/ 2>/dev/null | sed 's#.*/\([^/]*\)/$#\1#'
  return 0
}

# The folder the registry gives a host (`hodd/machines/<h>` by the shipped shape).
host_folder() {
  local h="$1" reg f; reg="$(fleet_registry)"
  if [ -f "$reg" ]; then
    f="$(python3 -c 'import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
print(((d.get("hosts") or {}).get(sys.argv[2]) or {}).get("folder") or "")' "$reg" "$h" 2>/dev/null)"
    [ -n "$f" ] && { printf '%s' "$f"; return 0; }
  fi
  printf 'hodd/machines/%s' "$h"
}

# machine_shelf <host> — sets LEDGER to that machine's shelf, or refuses a host the fleet does
# not know, BY NAME (plan 311 §2: an unknown host is a typo, and a shelf nobody reads is how a
# plan disappears — the same reason an unknown project is refused).
machine_shelf() {
  local h="$1" known reg
  [ -n "$h" ] || { printf 'plan: --scope machine needs a host (--host H, or it means this host)\n' >&2; return 2; }
  reg="$(fleet_registry)"; known="$(known_hosts)"
  if [ -n "$known" ] && ! printf '%s\n' "$known" | grep -qx -- "$h"; then
    printf 'plan: REFUSED — no machine called %s in the fleet registry (%s)\n' "$h" "${reg#$HOME_DIR/}" >&2
    printf 'plan: the fleet knows: %s\n' "$(printf '%s' "$known" | tr '\n' ' ')" >&2
    return 2
  fi
  [ -f "$reg" ] || printf 'plan: note — no fleet registry, so the host %s is taken as given\n' "$h" >&2
  LEDGER="$HOME_DIR/$(host_folder "$h")/plans"
  return 0
}

# ── THE ROUTE ABOVE THE LEDGER (plan 311 §3) ─────────────────────────────
# It reads the registries that already exist and never keeps a table of its own:
#   hodd/identity/projects.yaml  what a project IS (id · realm · name · its plans shelf)
#   hodd/identity/services.yaml  what a hosted surface IS (id · host · name)
# The vocabulary is emitted as TSV: `P<TAB>id<TAB>realm<TAB>name<TAB>plans` and `S<TAB>id<TAB>host<TAB>name`.
# Exit 3 when no YAML reader exists: the router then answers from the words alone and says so.
registries() {
  local pj="$HOME_DIR/hodd/identity/projects.yaml" sv="$HOME_DIR/hodd/identity/services.yaml"
  python3 - "$pj" "$sv" <<'PY'
import sys
try:
    import yaml
except Exception:
    sys.exit(3)
try: doc = yaml.safe_load(open(sys.argv[1])) or {}
except Exception: doc = {}
for p in (doc.get('projects') or []):
    if not isinstance(p, dict): continue
    plans = (((p.get('records') or {}).get('in_home') or {}).get('plans') or '')
    print('P\t%s\t%s\t%s\t%s' % (p.get('id') or '', p.get('realm') or '', p.get('name') or '', plans))
try: doc = yaml.safe_load(open(sys.argv[2])) or {}
except Exception: doc = {}
for s in (doc.get('services') or []):
    if not isinstance(s, dict): continue
    print('S\t%s\t%s\t%s' % (s.get('id') or '', s.get('host') or '', s.get('name') or ''))
PY
}

# The ymir project's ledger, read from the registry (projects.yaml records.in_home.plans), never
# spelled here: `svartalfaheim/<realm>/projects/<project>/plans/` -> realm + project.
default_project() {   # sets R_REALM R_PROJECT from the registry, else the shipped default
  local vocab line plans realm proj
  vocab="$(registries 2>/dev/null)" || vocab=""
  line="$(printf '%s\n' "$vocab" | awk -F'\t' '$1=="P" && $5!="" {print; exit}')"
  if [ -n "$line" ]; then
    plans="$(printf '%s' "$line" | cut -f5)"
    realm="$(printf '%s' "$plans" | sed -n 's#^svartalfaheim/\([^/]*\)/.*#\1#p')"
    proj="$(printf '%s' "$plans" | sed -n 's#^.*/projects/\([^/]*\)/plans.*#\1#p')"
    [ -n "$realm" ] && [ -n "$proj" ] && { R_REALM="$realm"; R_PROJECT="$proj"; return 0; }
  fi
  R_REALM="${REALM:-work}"; R_PROJECT="${PROJECT:-ymir}"
}

# route_decide <slug> <title> — sets R_KIND · R_SCOPE · R_OWNER · R_HOST · R_WHY. Files nothing.
route_decide() {
  local slug="$1" title="$2" vocab words w svc=""
  R_KIND="project"; R_SCOPE="project"; R_OWNER=""; R_HOST=""; R_WHY=""
  default_project
  R_REALM_DEFAULT="$R_REALM"; R_OWNER="$R_PROJECT"
  R_WHY="the ymir project's own ledger (projects.yaml names it)"
  vocab="$(registries 2>/dev/null)"; rv=$?
  [ "$rv" = 3 ] && printf 'plan: note — no YAML reader here, so the route is answered from the words and the folders alone\n' >&2
  [ -n "$vocab" ] || vocab=""
  words=" $(printf '%s %s' "$slug" "$title" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' ' ') "
  has() { case "$words" in *" $1 "*) return 0 ;; esac; return 1; }

  # 1 · Ymir itself, the fleet, the arms — the ymir ledger, whatever else the words resemble.
  if has ymir || has eindri || has ledger || has fleet || has arms || has plan-door; then
    R_KIND="project"; R_SCOPE="project"; R_OWNER="$R_PROJECT"; R_REALM="$R_REALM_DEFAULT"
    R_WHY="the ymir project's own ledger (the words name Ymir's own work)"; return 0
  fi
  # 2 · Gimlé, or a hosted surface the services registry knows.
  if has gimle || has "gimlé"; then
    R_KIND="gimle"; R_WHY="this is Gimlé's — a plan here would be read by nobody; open it there"
    R_GIMLE_SHELF="$(ls -d "$HOME_DIR"/svartalfaheim/*/projects/gimle/plans 2>/dev/null | head -1)"
    return 0
  fi
  if has hosted || has surface || has surfaces; then
    while IFS=$'\t' read -r k id host name; do
      [ "$k" = "S" ] || continue
      [ -n "$id" ] || continue
      if has "$id"; then svc="$id — $name"; break; fi
    done <<< "$vocab"
    if [ -n "$svc" ]; then
      R_KIND="gimle"; R_WHY="this is Gimlé's ($svc, services.yaml) — a plan here would be read by nobody; open it there"; return 0
    fi
  fi
  # 3 · The board, a card, a queue — Trello holds it, not a plan ledger.
  if has card || has cards || has ticket || has tickets || has queue || has backlog || has board || has trello || has plane; then
    R_KIND="card"; R_WHY="this is a card, not a plan — the board holds it"; return 0
  fi
  # 4 · A machine's repair, its limits, its faults — that machine's shelf, named.
  local known; known="$(known_hosts)"
  while read -r w; do
    [ -n "$w" ] || continue
    if has "$w"; then
      if has repair || has fault || has faults || has limit || has limits || has thermal || has thermals \
         || has fan || has fans || has oom || has swap || has kernel || has gpu || has driver || has drivers \
         || has disk || has power || has heat || has budget || has memory || has crash || has crashes \
         || has upgrade || has install || has service || has services; then
        R_KIND="machine"; R_SCOPE="machine"; R_HOST="$w"; R_OWNER="$w"; R_WHY="a machine's own work — the shelf of $w (fleet.json names it)"; return 0
      fi
    fi
  done <<< "$known"
  # 5 · The operator's own work.
  if has personal || has family || has holiday || has health || has life; then
    R_KIND="personal"; R_SCOPE="personal"; R_OWNER=""; R_WHY="the Allfather's own work — hodd/plans/"; return 0
  fi
  # 6 · A project the registry knows, by its id or its name.
  local pid prealm pname
  while IFS=$'\t' read -r k pid prealm pname _; do
    [ "$k" = "P" ] || continue
    [ -n "$pid" ] || continue
    if has "$pid"; then
      R_KIND="project"; R_SCOPE="project"; R_OWNER="$pid"; R_REALM="${prealm:-$R_REALM_DEFAULT}"
      R_WHY="the registry knows $pid (realm ${prealm:-?}) — file it on its own shelf"; return 0
    fi
  done <<< "$vocab"
  return 0
}

# The one pad width a shelf carries (plan 311 §2): most common among its numbered files,
# ties to the wider, three when the shelf is empty.
pad_width() {
  local d="$1" w
  w="$(ls "$d" 2>/dev/null | grep -oE '^[0-9]+' | awk '{print length($0)}' | sort -n | uniq -c \
       | sort -k1,1nr -k2,2nr | head -1 | awk '{print $2}')"
  if [ -z "$w" ]; then   # no numbered files: the index is the only evidence of the shelf's shape
    w="$(grep -hoE '^\| [0-9]+ \|' "$d/README.md" 2>/dev/null | grep -oE '[0-9]+' | awk '{print length($0)}' \
         | sort -n | uniq -c | sort -k1,1nr -k2,2nr | head -1 | awk '{print $2}')"
  fi
  [ -n "$w" ] || w=3
  printf '%s' "$w"
}

# A refused project names the shelves it MIGHT have meant (plan 311 §4 proof 3): the registry's
# own near names, and the house's ledger — never a bare "no such project".
project_candidates() {
  local want="$1" vocab k pid prealm pname plans
  vocab="$(registries 2>/dev/null)"; [ -n "$vocab" ] || vocab=""
  [ "${#want}" -ge 2 ] || return 0
  while IFS=$'\t' read -r k pid prealm pname plans; do
    [ "$k" = "P" ] || continue
    [ -n "$pid" ] || continue
    [ "$pid" = "$want" ] && continue
    case "$pid" in "$want"*|*"$want"*) ;; *) continue ;; esac
    if [ -n "$plans" ]; then
      printf 'plan: it might have meant  %s — %s (realm %s); its plans: %s\n' "$pid" "$pname" "$prealm" "$plans"
    else
      printf 'plan: it might have meant  %s — %s (realm %s), which the registry knows but no ledger shelf holds\n' "$pid" "$pname" "$prealm"
    fi
  done <<< "$vocab"
  local r="${REALM:-work}" pr="${PROJECT:-ymir}" line plans realm proj
  line="$(printf '%s\n' "$vocab" | awk -F'\t' '$1=="P" && $5!="" {print; exit}')"
  if [ -n "$line" ]; then
    plans="$(printf '%s' "$line" | cut -f5)"
    realm="$(printf '%s' "$plans" | sed -n 's#^svartalfaheim/\([^/]*\)/.*#\1#p')"
    proj="$(printf '%s' "$plans" | sed -n 's#^.*/projects/\([^/]*\)/plans.*#\1#p')"
    [ -n "$realm" ] && [ -n "$proj" ] && { r="$realm"; pr="$proj"; }
  fi
  printf "plan: or the house's own ledger — svartalfaheim/%s/projects/%s/plans\n" "$r" "$pr"
  return 0
}

# ── the scopes (plan 240) — a plan belongs to whoever owns the work ───────────
seed_shelf_index() {   # <scope> <owner> — the shelf's own index, written once
  local scope="$1" owner="$2" f="$LEDGER/README.md"
  [ -f "$f" ] && return 0
  {
    case "$scope" in
      machine)
        printf '# %s'"'"'s plans — the machine'"'"'s own ledger\n\n' "$owner"
        printf '**A machine plans for itself here.** Its power, its thermals, its fans, its rail, its repairs —\n'
        printf 'deliberately *not* a project'"'"'s ledger, because a plan belongs to whoever owns the work.\n\n' ;;
      realm|company)
        printf '# %s — the realm'"'"'s plans\n\n' "$owner"
        printf '**A company (realm) plans for itself here** — strategy, money, the house'"'"'s own work —\n'
        printf 'deliberately *not* a project'"'"'s ledger (plan 240).\n\n' ;;
      personal)
        printf '# The Allfather'"'"'s plans\n\n'
        printf '**His own working plans live here** — personal work, schedules, errands that belong to no project\n'
        printf 'and no machine (plan 240).\n\n' ;;
      *)  printf '# Plans — %s\n\n' "$owner" ;;
    esac
    printf '```\nplan[3]{rule,why}:\n'
    printf '  "numbering is per shelf","%s 001 is this shelf'"'"'s first plan; no number is reused within a shelf"\n' "$owner"
    printf '  "one index: this file","every plan gets a row here, in the same change that creates it"\n'
    printf '  "the owner is in the plan header","owner · owner_name, so a plan keeps its provenance if it ever moves"\n'
    printf '```\n\n## The plans\n'
  } > "$f"
}

set_ledger_for_scope() {   # <scope> <owner> — resolve (and, where legal, create) the shelf
  local scope="$1" owner="$2"
  case "$scope" in
    project) resolve_project_ledger "$owner" || return 2 ;;
    realm|company)
      [ -n "$owner" ] || { printf 'plan: --scope realm needs --owner <realm>\n' >&2; return 2; }
      LEDGER="$HOME_DIR/svartalfaheim/$owner/plans" ;;
    machine)
      owner="${HOST:-${owner:-$(this_host)}}"
      machine_shelf "$owner" || return 2 ;;
    personal) LEDGER="$HOME_DIR/hodd/plans" ;;
    *) printf 'plan: unknown scope %s (project|realm|machine|personal)\n' "$scope" >&2; return 2 ;;
  esac
  [ "$scope" = project ] && return 0
  mkdir -p "$LEDGER" 2>/dev/null || { printf 'plan: cannot create %s\n' "$LEDGER" >&2; return 2; }
  seed_shelf_index "$scope" "${owner:-$REALM}"
  return 0
}

# ── Rule 45 — a number is taken from the CURRENT ledger, never from a stale one ──
# WHY (2026-11-04): this seat sat seven commits behind origin, asked for the next
# number, and was told 182. The plan was written — but another machine had taken 182
# the same day, so two plans shared a number and one had to be renumbered. Numbering
# is a DISTRIBUTED allocation: the ledger is git, and an allocation without a fetch
# is a guess dressed as a fact.
ledger_state() {   # fresh | behind:<n> | unverified:<why>
  local repo br behind
  command -v git >/dev/null 2>&1 || { printf 'unverified:no git on PATH'; return 0; }
  repo="$(git -C "$LEDGER" rev-parse --show-toplevel 2>/dev/null)" || { printf 'unverified:the home is not a git repository'; return 0; }
  [ "${YMIR_OFFLINE:-0}" = "1" ] && { printf 'unverified:YMIR_OFFLINE=1'; return 0; }
  git -C "$repo" fetch --quiet --prune origin 2>/dev/null || { printf 'unverified:origin is unreachable'; return 0; }
  br="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  br="${br:-main}"
  git -C "$repo" rev-parse --verify -q "origin/$br" >/dev/null 2>&1 || { printf 'unverified:origin/%s is missing' "$br"; return 0; }
  behind="$(git -C "$repo" rev-list --count "HEAD..origin/$br" 2>/dev/null || printf 0)"
  if [ "${behind:-0}" = "0" ]; then printf 'fresh'; else printf 'behind:%s' "$behind"; fi
}

# READING a number is harmless; TAKING one is not. Only `new` calls this.
refuse_stale_ledger() {
  local s repo; s="$(ledger_state)"
  case "$s" in
    fresh) : ;;
    behind:*)
      if [ "${YMIR_ALLOW_STALE_LEDGER:-0}" = "1" ]; then
        printf 'plan: WARNING — the ledger is %s commit(s) behind origin and a number was taken anyway (YMIR_ALLOW_STALE_LEDGER=1)\n' "${s#behind:}" >&2
      else
        repo="$(git -C "$LEDGER" rev-parse --show-toplevel 2>/dev/null)"
        printf 'plan: REFUSED — the ledger is %s commit(s) behind origin, so the next number is not this seat to take.\n' "${s#behind:}"
        printf 'plan: it may already belong to a plan written elsewhere (that is how 182 was written twice, 2026-11-04).\n'
        printf 'plan: run  git -C "%s" pull --ff-only  then ask again; the ledger is %s\n' "$repo" "$LEDGER"
        printf 'plan: loud override when you know better:  YMIR_ALLOW_STALE_LEDGER=1\n'
        return 1
      fi ;;
    unverified:*)
      printf 'plan: note — the ledger is UNVERIFIED against origin (%s): a number taken now may already be taken elsewhere.\n' "${s#unverified:}" >&2 ;;
  esac
  return 0
}

# A number is taken from the FILES *and* the index: a plan whose file has moved still holds its
# number, and a shelf's index is the record of every number it has spent.
shelf_file_numbers()  { ls "$LEDGER" 2>/dev/null | grep -oE '^[0-9]+'; }
shelf_index_numbers() {
  { grep -hoE '^\| [0-9]+ \|' "$LEDGER/README.md" 2>/dev/null | grep -oE '[0-9]+'
    grep -hoE '^- \*\*[0-9]+\*\*' "$LEDGER/README.md" 2>/dev/null | grep -oE '[0-9]+'
  } 2>/dev/null
}
next_number() {
  { shelf_file_numbers; shelf_index_numbers; } | sort -n | tail -1 | awk '{print ($1+1)}'
}

case "${1:-}" in
  -h|--help|"") sed -n '2,43p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  next)
    # next [--scope S] [--owner O] [--host H] [--all]
    shift; while [ $# -gt 0 ]; do case "$1" in
      --scope) SCOPE="${2-}"; SCOPE_GIVEN=1; shift 2 ;;
      --owner) OWNER="${2-}"; shift 2 ;;
      --host) HOST="${2-}"; shift 2 ;;
      --realm) REALM="${2-}"; REALM_GIVEN=1; shift 2 ;;
      --project) PROJECT="${2-}"; shift 2 ;;
      --all) SCOPE="all"; shift ;;
      *) shift ;;
    esac; done
    if [ "$SCOPE" = all ]; then
      printf 'shelves[5]{scope,owner,path,next}\n'
      for d in "$HOME_DIR"/svartalfaheim/*/plans "$HOME_DIR"/svartalfaheim/*/projects/*/plans "$HOME_DIR"/svartalfaheim/*/workspace/*/plans \
               "$HOME_DIR"/hodd/machines/*/plans "$HOME_DIR"/hodd/plans; do
        [ -d "$d" ] || continue
        LEDGER="$d"
        printf '  "%s","%s","%s","%s"\n' "$(basename "$(dirname "$d")")" "$(basename "$d")" "${d#$HOME_DIR/}" "$(next_number)"
      done
      exit 0
    fi
    set_ledger_for_scope "$SCOPE" "${OWNER:-$PROJECT}" || exit 2
    n="$(next_number)"; printf '%s\n' "${n:-1}" ;;
  list)
    # list [--scope S] [--owner O] [--host H] [--all]
    shift; ALL=0; while [ $# -gt 0 ]; do case "$1" in
      --scope) SCOPE="${2-}"; SCOPE_GIVEN=1; shift 2 ;;
      --owner) OWNER="${2-}"; shift 2 ;;
      --host) HOST="${2-}"; shift 2 ;;
      --realm) REALM="${2-}"; REALM_GIVEN=1; shift 2 ;;
      --project) PROJECT="${2-}"; shift 2 ;;
      --all) ALL=1; shift ;;
      *) shift ;;
    esac; done
    if [ "$ALL" = 1 ]; then
      for d in "$HOME_DIR"/svartalfaheim/*/projects/*/plans "$HOME_DIR"/svartalfaheim/*/plans \
               "$HOME_DIR"/hodd/machines/*/plans "$HOME_DIR"/hodd/plans; do
        [ -f "$d/README.md" ] || continue
        printf '# %s\n' "${d#$HOME_DIR/}"
        grep -hE '^\| [0-9]+ \|' "$d/README.md" 2>/dev/null | sed -E 's/^\| ([0-9]+) \| \[([^]]*)\].*/  #\1 \2/' | tail -20
        grep -hE '^- \*\*[0-9]+\*\*|^- \*\*[0-9]{4}\*\*' "$d/README.md" 2>/dev/null | sed -E 's/^- \*\*([0-9]+)\*\* [—-] \[(.*)\]\(.*/  #\1 \2/' | tail -20
      done
      exit 0
    fi
    set_ledger_for_scope "$SCOPE" "${OWNER:-$PROJECT}" || exit 2
    grep -hE '^\| [0-9]+ \|' "$LEDGER/README.md" 2>/dev/null | sed -E 's/^\| ([0-9]+) \| \[([^]]*)\].*/#\1 \2/' | tail -20
    grep -hE '^- \*\*[0-9]+\*\*' "$LEDGER/README.md" 2>/dev/null | sed -E 's/^- \*\*([0-9]+)\*\* [—-] \[(.*)\]\(.*/  #\1 \2/' | tail -20 ;;
  new)
    slug="${2:-}"; shift 2 2>/dev/null || true
    title=""; from_meeting=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --title) title="${2-}"; shift 2 ;;
        --realm) REALM="${2-}"; REALM_GIVEN=1; shift 2 ;;
        --project) PROJECT="${2-}"; shift 2 ;;
        --host) HOST="${2-}"; shift 2 ;;
        --new-shelf) NEW_SHELF=1; shift ;;
        --scope) SCOPE="${2-}"; SCOPE_GIVEN=1; shift 2 ;;
        --owner) OWNER="${2-}"; shift 2 ;;
        --from-meeting) from_meeting="${2-}"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -n "$slug" ] && [ -n "$title" ] || { printf 'plan: new needs <slug> and --title\n' >&2; exit 2; }
    # ── THE ROUTE (plan 311 §3): only when the caller named no scope ──────────
    routed=0
    if [ "$SCOPE_GIVEN" = 0 ] && [ "$REALM_GIVEN" = 0 ] && [ -z "$OWNER" ] && [ -z "$HOST" ] \
       && [ "$PROJECT" = "${YMIR_PROJECT:-ymir}" ]; then
      route_decide "$slug" "$title"
      routed=1
      case "$R_KIND" in
        gimle)
          printf 'plan: REFUSED — %s.\n' "$R_WHY"
          printf 'plan: Gimlé keeps its runbooks beside its own code; the door for a plan there is Gimlé itself.\n'
          if [ -n "${R_GIMLE_SHELF:-}" ]; then
            printf 'plan: today Gimlé also carries a shelf in this home (%s) — whether a plan\n' "${R_GIMLE_SHELF#$HOME_DIR/}"
            printf 'plan: belongs there or with its own code is the Allfather%s call (plan 311 §5), not this door%s.\n' "'s" "'s"
            printf 'plan: to file it on that shelf anyway, name it:  --scope project --project gimle\n'
          fi
          printf "plan: if this really is Ymir's own work, say so:  --scope project --project %s\n" "$R_PROJECT"
          exit 2 ;;
        card)
          printf 'plan: REFUSED — %s.\n' "$R_WHY"
          printf 'plan: the board is Trello (projects.yaml names it); a card is tracked there, and a plan filed here would duplicate it.\n'
          printf 'plan: if this really is a plan, name its shelf:  --scope project|realm|machine|personal\n'
          exit 2 ;;
        machine)
          SCOPE="machine"; HOST="$R_HOST"; OWNER="$R_HOST" ;;
        personal)
          SCOPE="personal"; OWNER="" ;;
        project)
          SCOPE="project"; PROJECT="$R_OWNER"; OWNER="$R_OWNER"
          [ -n "${R_REALM:-}" ] && { REALM="$R_REALM"; REALM_GIVEN=1; } ;;
      esac
      printf 'plan: route — %s\n' "$R_WHY" >&2
    fi
    [ "$SCOPE" = project ] && OWNER="${OWNER:-$PROJECT}"
    # a machine's plan names the machine as its owner, whether the host was given or assumed
    [ "$SCOPE" = machine ] && OWNER="${HOST:-${OWNER:-$(this_host)}}"
    set_ledger_for_scope "$SCOPE" "${OWNER:-}" || exit 2
    refuse_stale_ledger || exit 1
    n="$(next_number)"; n="${n:-1}"
    # one pad width per shelf: adopt the shelf's own, never impose a second shape
    pw="$(pad_width "$LEDGER")"; pad="$(printf "%0${pw}d" "$n")"
    f="$LEDGER/${pad}-${slug}.md"
    [ -e "$f" ] && { printf 'plan: %s exists\n' "$f" >&2; exit 1; }
    {
      printf '# Plan %s - %s\n' "$n" "$title"
      printf 'owner: %s\nowner_name: %s\n' "$SCOPE" "${OWNER:-$PROJECT}"
      [ "$SCOPE" = machine ] && printf 'host: %s\n' "${HOST:-$(this_host)}"
      [ -n "$from_meeting" ] && printf 'from_meeting: %s\n' "$from_meeting"
      printf '\n**Opened %s.**\n' "$(date +%F)"
    } > "$f"
    printf '| %s | [%s](%s) | opened |\n' "$n" "$title" "$(basename "$f")" >> "$LEDGER/README.md"
    printf 'created %s\n  shelf: %s (%s)\n' "$f" "$LEDGER" "$SCOPE"
    [ "$SCOPE" = machine ] && printf '  host: %s\n' "${HOST:-$(this_host)}"
    [ "$routed" = 1 ] && printf '  route: %s\n' "$R_WHY"
    printf '  number: %s on this shelf (pad width %s)\n' "$pad" "$pw" ;;
  route)
    # route <slug> --title <t> [--project P] — WHERE it belongs. Files nothing, ever.
    slug="${2:-}"; shift 2 2>/dev/null || true
    title=""
    while [ $# -gt 0 ]; do case "$1" in
      --title) title="${2-}"; shift 2 ;;
      --project) PROJECT="${2-}"; shift 2 ;;
      *) shift ;;
    esac; done
    [ -n "$slug" ] && [ -n "$title" ] || { printf 'plan: route needs <slug> and --title\n' >&2; exit 2; }
    route_decide "$slug" "$title"
    case "$R_KIND" in
      gimle|card)
        printf 'route[1]{kind,scope,owner,host,shelf,why}:\n'
        printf '  "%s","refused","-","-","-","%s"\n' "$R_KIND" "$R_WHY"
        printf 'plan: %s\n' "$R_WHY" >&2
        exit 0 ;;
      machine)
        printf 'route[1]{kind,scope,owner,host,shelf,why}:\n'
        printf '  "machine","machine","%s","%s","%s","%s"\n' "$R_HOST" "$R_HOST" "$(host_folder "$R_HOST")/plans" "$R_WHY" ;;
      personal)
        printf 'route[1]{kind,scope,owner,host,shelf,why}:\n'
        printf '  "personal","personal","-","-","hodd/plans","%s"\n' "$R_WHY" ;;
      *)
        LEDGER=""
        printf 'route[1]{kind,scope,owner,host,shelf,why}:\n'
        if set_ledger_for_scope project "$R_OWNER" >/dev/null 2>&1; then
          printf '  "project","project","%s","-","%s","%s"\n' "$R_OWNER" "${LEDGER#$HOME_DIR/}" "$R_WHY"
        else
          printf '  "project","project","%s","-","none yet","%s"\n' "$R_OWNER" "$R_WHY"
          printf 'plan: the registry knows %s but it has no shelf; open one with --new-shelf\n' "$R_OWNER" >&2
        fi ;;
    esac ;;
  check)
    # check — ONE pad width per shelf (plan 311 §2). Reports a shelf carrying two shapes; exit 1.
    bad=0; rows=0; body=""
    for d in "$HOME_DIR"/svartalfaheim/*/projects/*/plans "$HOME_DIR"/svartalfaheim/*/workspace/*/plans \
             "$HOME_DIR"/svartalfaheim/*/plans "$HOME_DIR"/hodd/machines/*/plans "$HOME_DIR"/hodd/plans; do
      [ -d "$d" ] || continue
      # one example number per pad width, narrowest first: the SHAPES a shelf carries
      widths="$(ls "$d" 2>/dev/null | grep -oE '^[0-9]+' | awk '{print length($0)"\t"$0}' \
                | sort -k1,1n -k2,2n | awk -F'\t' '!seen[$1]++ {print $2}' | tr '\n' ',' | sed 's/,$//')"
      [ -n "$widths" ] || continue
      case "$widths" in *,*) bad=1
        files="$(ls "$d" 2>/dev/null | grep -E '^[0-9]+' | head -6 | tr '\n' ' ' | sed 's/ *$//')"
        n_files="$(ls "$d" 2>/dev/null | grep -cE '^[0-9]+')"
        [ "$n_files" -gt 6 ] && files="$files … and $((n_files-6)) more"
        body="$body  \"${d#$HOME_DIR/}\",\"$widths\",\"$files\"\n" ;;
      esac
      rows=$((rows+1))
    done
    printf 'pad[%s]{shelf,widths,files}:\n' "$((bad))"
    printf '%b' "$body"
    [ "$bad" = 0 ] && printf '  "-","-","every shelf carries one pad width (%s shelf(s) read)"\n' "$rows"
    exit "$bad" ;;
  shelves)
    # Every realm and every project folder in this home, and whether each has a plans shelf.
    # Read from the folders, so it holds for any user's home and any number of projects.
    printf 'shelves{realm,project,shelf,plans}\n'
    base="$HOME_DIR/svartalfaheim"
    for r in "$base"/*/; do
      [ -d "$r" ] || continue; r="${r%/}"; rn="$(basename "$r")"
      if [ -d "$r/plans" ]; then
        printf '  "%s","-","%s","%s"\n' "$rn" "${r#$HOME_DIR/}/plans" "$(find "$r/plans" -maxdepth 1 -name '*.md' ! -name README.md | wc -l)"
      else printf '  "%s","-","none","0"\n' "$rn"; fi
      for d in "$r"/projects/*/ "$r"/workspace/*/; do
        [ -d "$d" ] || continue; d="${d%/}"
        if [ -d "$d/plans" ]; then
          printf '  "%s","%s","%s","%s"\n' "$rn" "$(basename "$d")" "${d#$HOME_DIR/}/plans" "$(find "$d/plans" -maxdepth 1 -name '*.md' ! -name README.md | wc -l)"
        else printf '  "%s","%s","none","0"\n' "$rn" "$(basename "$d")"; fi
      done
    done ;;
  from-meeting)
    set_ledger_for_scope "$SCOPE" "${OWNER:-$PROJECT}" || exit 2
    # The join, read back out of the ledger: which plans a meeting produced. It refuses
    # rather than guessing — a plan with no `from_meeting:` header is never assumed to be one.
    want="${2:-}"; [ -n "$want" ] || { printf 'plan: from-meeting needs a meeting id\n' >&2; exit 2; }
    found=0
    for p in "$LEDGER"/*.md; do
      [ -e "$p" ] || continue
      [ "$(basename "$p")" = "README.md" ] && continue
      if head -20 "$p" | grep -qE "^\**from_meeting\**\s*:\s*\`?$want\`?\s*$"; then
        printf '  "%s","%s"\n' "$want" "$(basename "$p")"
        found=$((found+1))
      fi
    done
    if [ "$found" = 0 ]; then
      printf 'plan: no plan header names meeting %s (from_meeting: %s)\n' "$want" "$want" >&2
      exit 1
    fi ;;
  *) printf 'error: unknown action %s\nhelp: plan.sh [new <slug> --title <t> [--scope project|realm|machine|personal] [--owner O] [--host H] [--realm R] [--project P] [--new-shelf] [--from-meeting <id>] | route <slug> --title <t> | list | next | shelves | check | from-meeting <id>]\n' "$1" >&2; exit 2 ;;
esac
