#!/usr/bin/env bash
# pi-door.sh — the door a SEAT THE OPERATOR STARTS BY HAND passes through.
#
# WHY (measured 2026-11-11). `pi`, typed in ~/ymir, printed forty-four lines of
# "Tool X conflicts with ~/ymir-runtime/.pi/extensions/…" and loaded nothing it had
# been asked to load. pi's loader (dist/core/extensions/loader.js) takes BOTH
# `<cwd>/.pi/extensions` and every directory named in `~/.pi/agent/settings.json`
# `extensions[]`, and de-duplicates on `path.resolve(p)` alone — so two checkouts of
# the same repository are two homes, every tool registers twice, and pi refuses every
# extension it would otherwise load. RULES/13: two load paths seats nobody.
#
# A DISPATCHED worker never hit this: bin/agents/einherjar-spawn.sh hands every pane
# the shape from bin/seat/pi-launcher.sh (`-ne` plus one `-e` per pin, from the
# worktree). The seat the Allfather starts himself had no such door. This is it.
#
# ONE DECISION, made per launch, and the seat keeps its doors either way:
#
#   the caller turned discovery off (-ne/--no-extensions) -> through, untouched
#       A LONE `-e` IS NOT THAT (measured 2026-11-13): Sessrúmnir spawns
#       `pi … -e <its own permissions extension>` and no `-ne`, so discovery stayed ON,
#       both trees loaded, every tool collided and the seat never started. `-e` adds an
#       extension; only `-ne` says "the caller owns the set".
#   <cwd>/.pi/extensions is absent                      -> through, untouched
#   the settings name that same directory               -> through, untouched (pi de-duplicates)
#   the settings name ANOTHER checkout's tree           -> discovery off (-ne), the cwd's
#                                                          own tree named once, the seat's
#                                                          npm packages carried explicitly
#
# It is installed as `~/.pi/agent/bin/pi` (first on PATH) by
# bin/seat/harness-extensions-install.sh, which copies this file and reports the copy
# stale when it has moved. A copy, never a symlink: a symlink into a checkout would
# lose the door the moment that branch is switched.
#
#   bin/seat/pi-door.sh [pi args…]     # what `pi` does, with one home
#   bin/seat/pi-door.sh --why          # the decision this door would make here, and why
#
# Exit: 0 ok (else the exec'd pi's own status) · 2 usage.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SETTINGS="${YMIR_PI_SETTINGS:-$HOME/.pi/agent/settings.json}"

usage() { sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; }

physical() { ( cd "$1" 2>/dev/null && pwd -P ); }

# The extension home this cwd makes pi discover, or nothing.
cwd_tree() {  # <cwd>
  [ -d "$1/.pi/extensions" ] || return 0
  physical "$1/.pi/extensions"
}

# Every existing `*.pi/extensions` directory the seat's settings name, one per line.
settings_trees() {
  [ -f "$SETTINGS" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  PI_SETTINGS="$SETTINGS" python3 -c 'import json,os
try:
    d=json.load(open(os.environ["PI_SETTINGS"]))
except Exception:
    raise SystemExit(0)
for e in (d.get("extensions") or []):
    if not isinstance(e,str) or e[:1] in ("-","+"):
        continue
    if not e.endswith(".pi/extensions"):
        continue
    p=os.path.expanduser(e)
    if os.path.isdir(p):
        print(p)' 2>/dev/null
}

# The pins a tree yields, in pi's own layout (RULES/13): a directory extension is its
# index.ts (or index.js); a flat file is itself; README.md and lib/ are not extensions.
tree_entries() {  # <tree>
  local tree=$1 p b
  for p in "$tree"/*; do
    [ -e "$p" ] || continue
    b="$(basename "$p")"
    case "$b" in README.md|lib) continue ;; esac
    if [ -d "$p" ]; then
      if [ -f "$p/index.ts" ]; then printf '%s\n' "$p/index.ts"
      elif [ -f "$p/index.js" ]; then printf '%s\n' "$p/index.js"; fi
    else
      case "$b" in *.ts|*.js) printf '%s\n' "$p" ;; esac
    fi
  done
}

# The packages the seat declares. `--no-extensions` turns discovery off, and discovery
# is what would have carried them — so the door names them too.
settings_packages() {
  [ -f "$SETTINGS" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  PI_SETTINGS="$SETTINGS" python3 -c 'import json,os
try:
    d=json.load(open(os.environ["PI_SETTINGS"]))
except Exception:
    raise SystemExit(0)
for x in (d.get("packages") or []):
    print(x)' 2>/dev/null
}

# The binary a bare `pi` would have been — never this door, which sits on PATH.
real_pi() {
  if [ -n "${PI_REAL_BIN:-}" ]; then printf '%s' "$PI_REAL_BIN"; return 0; fi
  local p
  p="$(PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vxF -- "$SELF_DIR" | paste -sd: -)" \
      command -v pi 2>/dev/null)"
  [ -n "$p" ] || return 1
  printf '%s' "$p"
}

run_real() {  # <args…>
  local bin
  bin="$(real_pi)" || {
    printf 'pi-door: no pi on PATH (this door is on PATH; the harness behind it is not)\n' >&2
    exit 1
  }
  exec "$bin" "$@"
}

decide() {  # prints: "pass<TAB>-<TAB>reason" | "onehome<TAB>tree<TAB>reason"
  local tree other owns=0 a
  for a in "$@"; do
    # ONLY the no-discovery flag means the caller owns the extension set. `-e` alone
    # adds one extension and leaves discovery on — the 2026-11-13 seat fault.
    case "$a" in -ne|--no-extensions) owns=1 ;; esac
  done
  tree="$(cwd_tree "$PWD")"
  [ "$owns" = 1 ] && { printf 'pass\t-\t%s' 'the caller already names its extensions'; return 0; }
  [ -n "$tree" ] || { printf 'pass\t-\t%s' 'this directory carries no .pi/extensions tree'; return 0; }
  other=""
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    [ "$(physical "$t")" = "$tree" ] && continue
    other="$t"; break
  done < <(settings_trees)
  [ -n "$other" ] || { printf 'pass\t-\t%s' 'the settings name no other extensions tree'; return 0; }
  printf 'onehome\t%s\tthe settings also name %s' "$tree" "$other"
}

if [ "${1-}" = "--why" ] || [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
  if [ "${1-}" = "--why" ]; then
    IFS="$(printf '\t')" read -r verdict a b < <(decide)
    printf 'pi-door[1]{verdict,tree,reason}:\n  "%s","%s","%s"\n' "$verdict" "${a-}" "${b-}"
    if bin="$(real_pi)"; then printf 'pi binary: %s\n' "$bin"; else printf 'pi binary: NOT ON PATH\n'; fi
    exit 0
  fi
  usage
  exit 0
fi

IFS="$(printf '\t')" read -r verdict tree reason < <(decide "$@")
case "$verdict" in
  onehome)
    argv=()
    while IFS= read -r pin; do
      [ -n "$pin" ] && argv+=(-e "$pin")
    done < <(tree_entries "$tree"; settings_packages)
    [ "${PI_DOOR_VERBOSE:-0}" = 1 ] && \
      printf 'pi-door: one home -> %s (%s pins) — %s\n' "$tree" "${#argv[@]}" "$reason" >&2
    run_real -ne ${argv[@]+"${argv[@]}"} "$@"
    ;;
  *)
    [ "${PI_DOOR_VERBOSE:-0}" = 1 ] && printf 'pi-door: through — %s\n' "${tree-}" >&2
    run_real "$@"
    ;;
esac
