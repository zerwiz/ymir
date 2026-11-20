#!/usr/bin/env bash
# skill-find.sh — find the skill you need, without loading any of them.
#
# THE DESIGN, and it matters: a session must NOT load every skill. That is how
# a context fills with instructions that do not apply, and an agent that reads
# forty skills acts like it read none. So nothing is preloaded. Instead:
#
#   you ask a question in words  ->  this reads the INDEX  ->  you get the one
#   or three paths, and you read those.
#
# THE INDEX IS THE POINT. `bin/agents/skill-index.sh` walks every shelf
# GENERICALLY (SKILL.md at any depth, no pack known by name) and writes ONE
# machine-readable index at $YMIR_HOME/.agents/skills/skills.yaml. This finder
# READS that index first, and REFRESHES it itself when it is missing or stale —
# so the loop cannot go dead the way the old hand-made inventory did (nothing
# ran it, nothing read it, and it pointed at a shelf that had moved).
#
# Four shelves, and the order is the point:
#   1. .agents/skills/          ships with the repo and the npm package
#   2. .agents/skills-local/    THIS MACHINE ONLY - never published, never cloned
#   3. the home shelf            the Allfather's own craft + imported packs
#   4. ~/.pi/agent/skills/      yours, harness-wide, across projects
#
# A shipped skill always wins a name collision on purpose: the project's craft
# must be identical on every machine, or two developers get two answers.
#
# Usage:
#   bin/agents/skill-find.sh deploy              # by word
#   bin/agents/skill-find.sh "how do I make a course"
#   bin/agents/skill-find.sh --list              # every skill and its one-line purpose
#   bin/agents/skill-find.sh --where <name>      # the exact path of one skill
#   bin/agents/skill-find.sh --check             # is the index fresh and complete?
set -uo pipefail

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
ROOT="$(_root)"
SHIPS="$ROOT/.agents/skills"
LOCALS="$ROOT/.agents/skills-local"
# The ships/local shelves belong to the CANONICAL checkout, not to whichever
# worktree runs this (see skill-index.sh): the index is one shared file, and two
# worktrees walking different shipped skills would fight over it.
_gd="$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$_gd" ]; then
  case "$_gd" in /*) ;; *) _gd="$ROOT/$_gd" ;; esac
  _canon="$(cd "$(dirname "$_gd")" 2>/dev/null && pwd)" || _canon=""
  [ -n "$_canon" ] && [ -d "$_canon/.agents/skills" ] && { SHIPS="$_canon/.agents/skills"; LOCALS="$_canon/.agents/skills-local"; }
fi
PISKILLS="$HOME/.pi/agent/skills"
# The home is RESOLVED by the one resolver (bin/vault/hoard-lib.sh); a literal
# path here would be one machine's layout. A wrong source path is how this file
# silently scanned the SHIP shelf for months — so the resolver is loaded by ROOT.
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
if command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi
HOMESKILLS="${YMIR_HOME:-$ROOT}/.agents/skills"
INDEX="$HOMESKILLS/skills.yaml"
GEN="$ROOT/bin/agents/skill-index.sh"

BOLD=$'\033[1m'; DIM=$'\033[2m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; OFF=$'\033[0m'

# Refresh the index if it is absent or stale. Silent by design: a finder that
# shouts while it heals is noise. If generation fails, we fall back to a live walk.
ensure_index() {
  [ -x "$GEN" ] || return 1
  if [ ! -s "$INDEX" ]; then
    "$GEN" >/dev/null 2>&1 || return 1
  elif ! "$GEN" --check >/dev/null 2>&1; then
    "$GEN" >/dev/null 2>&1 || return 1
  fi
  [ -s "$INDEX" ]
}

# Read the index as TSV: shelf<TAB>pack<TAB>name<TAB>path<TAB>description.
# The YAML is written by our own generator, so a small dobule-quote unescape is enough.
index_tsv() {
  awk '
    /^  - name:/ { name=$0; sub(/^  - name:[[:space:]]*"/,"",name); sub(/"$/,"",name); next }
    /^    shelf:/ { shelf=$0; sub(/^    shelf:[[:space:]]*/,"",shelf); next }
    /^    pack:/  { pack=$0;  sub(/^    pack:[[:space:]]*"/,"",pack);  sub(/"$/,"",pack);  next }
    /^    path:/  { path=$0;  sub(/^    path:[[:space:]]*"/,"",path);  sub(/"$/,"",path);  next }
    /^    description:/ { desc=$0; sub(/^    description:[[:space:]]*"/,"",desc); sub(/"$/,"",desc)
                        d=desc; gsub(/\\"/,"\"",d); gsub(/\\\\/,"\\",d)
                        printf "%s\t%s\t%s\t%s\t%s\n", shelf, pack, name, path, d; next }
  ' "$INDEX" |
  # `path` is RELATIVE to the shelf root; anchor it to THIS machine (Rule 25).
  # An older/absolute path is passed through unchanged, so a v1 index still reads.
  while IFS=$'\t' read -r shelf pack name rel desc; do
    case "$shelf" in
      ships) label="ships";        root="$SHIPS" ;;
      local) label="LOCAL — this machine only"; root="$LOCALS" ;;
      home)  label="home — your own craft";     root="$HOMESKILLS" ;;
      pi)    label="yours";        root="$PISKILLS" ;;
      *)     label="$shelf";       root="" ;;
    esac
    case "$rel" in /*) path="$rel" ;; *) path="$root/$rel" ;; esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$shelf" "$label" "$pack" "$name" "$path" "$desc"
  done
}

# A live, recursive walk — the fallback when the index cannot be built.
# Same generic rule as the generator, so the two never disagree in shape.
live_tsv() {
  local shelf id label f pack name desc
  for shelf in "$SHIPS" "$LOCALS" "$HOMESKILLS" "$PISKILLS"; do
    [ -d "$shelf" ] || continue
    case "$shelf" in
      "$SHIPS")   id=ships; label="ships" ;;
      "$LOCALS")  id=local; label="LOCAL — this machine only" ;;
      "$HOMESKILLS") id=home; label="home — your own craft" ;;
      *)          id=pi;    label="yours" ;;
    esac
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      name="$(awk 'BEGIN{i=0} /^---$/{i=!i;next} i&&/^name:/{sub(/^name:[[:space:]]*/,"");print;exit}' "$f" 2>/dev/null)"
      [ -z "$name" ] && name="$(basename "$(dirname "$f")")"
      desc="$(awk 'BEGIN{i=0} /^---$/{i=!i;next} i&&/^description:/{sub(/^description:[[:space:]]*/,"");print;exit}' "$f" 2>/dev/null \
             | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
      [ -z "$desc" ] && desc="(no description — unfindable; add description: to the front matter)"
      rel="${f#"$shelf"/}"; pack="${rel%%/*}"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$label" "$pack" "$name" "$f" "$desc"
    done < <(find "$shelf" -iname 'SKILL.md' \
               -not -path '*/.git/*' -not -path '*/node_modules/*' \
               -not -path '*/.yggdrasil/*' -not -path '*/dist/*' -not -path '*/build/*' \
               2>/dev/null | LC_ALL=C sort)
  done
}

# The one source of rows: the index if we can keep it fresh, else a live walk.
rows() {
  if ensure_index; then index_tsv; else live_tsv; fi
}

# --check
if [ "${1:-}" = "--check" ]; then
  if [ -x "$GEN" ] && "$GEN" --check; then
    exit 0
  fi
  printf '%sindex is stale or incomplete — regenerating%s\n' "$YEL" "$OFF" >&2
  ensure_index && { "$GEN" --check; exit $?; }
  printf '%sno generator at %s — falling back to a live walk (slower, unfindable gaps possible)%s\n' "$YEL" "$GEN" "$OFF" >&2
  exit 0
fi

# --where <name>
if [ "${1:-}" = "--where" ]; then
  want="${2:-}"
  [ -z "$want" ] && { printf '%susage: skill-find.sh --where <name>%s\n' "$RED" "$OFF" >&2; exit 2; }
  hit="$(rows | awk -F'\t' -v w="$want" '{ n=$4; p=$5; sub(/\/SKILL\.md$/,"",p); sub(/.*\//,"",p); if (n==w || p==w) {print $5; exit} }')" || true
  [ -n "$hit" ] && { echo "$hit"; exit 0; }
  printf '%sno skill named %s in any shelf%s\n' "$RED" "$want" "$OFF" >&2
  exit 1
fi

# --list
if [ "${1:-}" = "--list" ]; then
  rows | awk -F'\t' '{ d=$6; if (length(d)>88) d=substr(d,1,88) "…"; printf "%-62s %-24s %s\n", $1 " · " $3 "/" $4, $5, d }' \
    | sed "s/^/${DIM}/; s/$/${OFF}/"
  printf '\n%s%s skills. Read the one you need; do not read them all.%s\n' "$DIM" "$(rows | grep -c .)" "$OFF"
  exit 0
fi

# the default: search the descriptions
QUERY="${*:-}"
[ -z "$QUERY" ] && { printf 'usage: bin/agents/skill-find.sh <words> | --list | --where <name> | --check\n' >&2; exit 2; }

HITS=0
while IFS=$'\t' read -r id label pack name path desc; do
  [ -n "$id" ] || continue
  hay="$name $pack $desc"
  if printf '%s' "$hay" | grep -qi -- "$QUERY"; then
    HITS=$((HITS+1))
    printf '%s[%s · %s]%s %s\n' "$BOLD" "$label" "$name" "$OFF" "$path"
    printf '        %s%s%s\n' "$DIM" "$desc" "$OFF"
  fi
done < <(rows)

[ "$HITS" = 0 ] && printf '%sno skill mentions "%s" — report the gap, do not improvise%s\n' "$YEL" "$QUERY" "$OFF"
printf '\n%s%d match(es). Read the one you need; do not read them all.%s\n' "$DIM" "$HITS" "$OFF"
