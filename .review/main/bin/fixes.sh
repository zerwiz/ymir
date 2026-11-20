#!/usr/bin/env bash
# fixes.sh — the fix notes. ONE FILE PER FIX, and nothing to fold.
#
# The two systems this replaces both failed us, and for the same reason: they kept
# a MONOLITH (CHANGELOG.md) and fed it from fragments (CHANGELOG.d). The pre-push
# hook folded the fragments into the monolith, then demanded a commit for the edit
# it had just made — a push that mutates the tree it is pushing, and a gate that
# passed if a range merely *touched* the file.
#
# So there is no monolith and no fold here. A note IS a file:
#
#   docs/fixes/<component>/<version>-<slug>.md
#
# Two branches never write the same path, so the collision is impossible. The
# history of a component is its directory, sorted. Nothing is ever assembled at
# push time, and the gate that guards it only READS (bin/fixes-guard.sh).
#
#   bin/fixes.sh record --component=install --version=0.1.28 --title="…" \
#                       [--why="…"] [--files="a,b"] [--date=YYYY-MM-DD]
#   bin/fixes.sh list [<component>]          # the components, or one's notes
#   bin/fixes.sh show <file|component>       # a note, or the newest of a component
#   bin/fixes.sh diff --component=X --from=V --to=V
#   bin/fixes.sh validate                    # every note's header, and its order
#   bin/fixes.sh components                  # just the names
#
# Exit: 0 ok, 1 error, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXES="$ROOT/docs/fixes"

# The components are the machine's own parts, not an invented list.
COMPONENTS="install runtime skills agents hlidskjalf odrerir sessrumnir smidja hoard gate"

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'error: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf 'help: %s\n' "$2" >&2; exit 1; }
known() { case " $COMPONENTS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
slugify() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed 's/--*/-/g; s/^-//; s/-$//' | cut -c1-56; }

action="${1-}"; shift || true
case "$action" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;
esac

component=""; version=""; title=""; why=""; files=""; date=""; from=""; to=""
for a in "$@"; do
  case "$a" in
    --component=*) component="${a#*=}" ;;
    --version=*)   version="${a#*=}" ;;
    --title=*)     title="${a#*=}" ;;
    --why=*)       why="${a#*=}" ;;
    --files=*)     files="${a#*=}" ;;
    --date=*)      date="${a#*=}" ;;
    --from=*)      from="${a#*=}" ;;
    --to=*)        to="${a#*=}" ;;
    -*) die "unknown argument $a" "bin/fixes.sh --help" ;;
    *) pos="${a}" ;;
  esac
done

notes_of() {  # <component> — its notes, newest first (the version decides the order)
  local c="$1"
  [ -d "$FIXES/$c" ] || return 0
  ls -1 "$FIXES/$c"/*.md 2>/dev/null | sort -V -r
}

case "$action" in
  components)
    printf 'components[%d]{name}:\n' "$(printf '%s\n' $COMPONENTS | wc -l | tr -d ' ')"
    for c in $COMPONENTS; do printf '  "%s"\n' "$c"; done
    ;;

  list)
    c="${pos:-${component:-}}"
    if [ -n "$c" ]; then
      known "$c" || die "unknown component $c" "one of: $COMPONENTS"
      n=0; while IFS= read -r f; do [ -n "$f" ] || continue; n=$((n+1)); printf '  "%s","%s","%s"\n' "$c" "$(basename "$f")" "$(sed -n '1s/^## [^·]*· \([^ ]*\) ·.*/\1/p' "$f")"; done < <(notes_of "$c")
      [ "$n" -gt 0 ] || printf 'fixes: %s has no notes yet\n' "$c"
    else
      printf 'fixes[%d]{component,notes}:\n' "$(printf '%s\n' $COMPONENTS | wc -l | tr -d ' ')"
      for c in $COMPONENTS; do
        cnt=$(notes_of "$c" | grep -c . || true)
        printf '  "%s",%s\n' "$c" "$cnt"
      done
    fi
    ;;

  show)
    what="${pos:-${component:-}}"; [ -n "$what" ] || die "what shall I show?" "bin/fixes.sh show <component|file>"
    if [ -f "$what" ]; then f="$what"
    elif [ -f "$FIXES/$what" ]; then f="$FIXES/$what"
    else
      known "$what" || die "unknown component $what" "one of: $COMPONENTS"
      f="$(notes_of "$what" | head -1)"
      [ -n "$f" ] || { printf 'fixes: %s has no notes yet\n' "$what"; exit 0; }
    fi
    cat "$f"
    ;;

  record)
    [ -n "$component" ] && [ -n "$version" ] && [ -n "$title" ] \
      || die "record needs --component, --version and --title" \
             "bin/fixes.sh record --component=install --version=0.1.28 --title=\"…\""
    known "$component" || die "unknown component $component" "one of: $COMPONENTS"
    date="${date:-$(date -u +%Y-%m-%d)}"
    dir="$FIXES/$component"; mkdir -p "$dir"
    f="$dir/${version}-$(slugify "$title").md"
    [ -e "$f" ] && die "that note already exists: ${f#"$ROOT"/}" "bin/fixes.sh show ${f#"$ROOT"/}"
    {
      printf '## %s · %s · %s — %s\n\n' "$component" "$version" "$date" "$title"
      [ -n "$why" ] && printf '### Why\n%s\n\n' "$why"
      printf '### Files\n'
      if [ -n "$files" ]; then printf '%s' "$files" | tr ',' '\n' | sed 's/^ *//; s/^/- `/; s/$/`/'
      else printf -- '- *(none named)*\n'; fi
    } >"$f"
    printf 'fixes[1]{component,version,note}:\n  "%s","%s","%s"\n' "$component" "$version" "${f#"$ROOT"/}"
    ;;

  diff)
    [ -n "$component" ] || die "diff needs --component" "bin/fixes.sh diff --component=install --from=0.1.27 --to=0.1.28"
    known "$component" || die "unknown component $component"
    n=0
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      b="$(basename "$f")"
      case "$b" in
        "${from}"-*|"${to}"-*) n=$((n+1)); printf '\n'; cat "$f" ;;
      esac
    done < <(notes_of "$component")
    [ "$n" -gt 0 ] || printf 'fixes: nothing between %s and %s for %s\n' "$from" "$to" "$component"
    ;;

  validate)
    fails=0; checked=0
    [ -d "$FIXES" ] || { printf 'fixes: docs/fixes/ does not exist yet\n'; exit 0; }
    for d in "$FIXES"/*/; do
      [ -d "$d" ] || continue
      c="$(basename "$d")"
      known "$c" || { printf '  "%s","unknown component directory"\n' "$c"; fails=$((fails+1)); continue; }
      for f in "$d"*.md; do
        [ -e "$f" ] || continue
        checked=$((checked+1))
        hdr="$(sed -n '1p' "$f")"
        printf '%s' "$hdr" | grep -qE "^## ${c} · ([0-9]+\.[0-9]+\.[0-9]+[^ ]*|unversioned) · [0-9]{4}-[0-9]{2}-[0-9]{2} — .+" \
          || { printf '  "%s","malformed header: %s"\n' "${f#"$ROOT"/}" "$hdr"; fails=$((fails+1)); }
        grep -q '^### Files$' "$f" || { printf '  "%s","no Files section"\n' "${f#"$ROOT"/}"; fails=$((fails+1)); }
      done
    done
    if [ "$fails" = 0 ]; then printf 'fixes[1]{state,checked}:\n  "valid",%s\n' "$checked"
    else printf 'fixes[1]{state,failed}:\n  "invalid",%s\n' "$fails"; exit 1; fi
    ;;

  *) die "unknown action ${action:-}" "bin/fixes.sh [record|list|show|diff|validate|components]" ;;
esac
