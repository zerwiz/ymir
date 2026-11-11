#!/usr/bin/env bash
# The ward for bin/seat/pi-door.sh — one extension home for a seat started by hand.
#
# The law it guards (RULES/13): two load paths seats nobody. pi's own loader
# (dist/core/extensions/loader.js) takes `<cwd>/.pi/extensions` AND every directory named
# in the seat's settings `extensions[]`, and de-duplicates on `path.resolve(p)` alone, so
# a session started in one checkout while the settings name ANOTHER checkout registers
# every tool twice and loads nothing. Measured 2026-11-11: 44 conflicts, seat unusable.
#
# The door's contract, asserted here with a fake `pi` that prints its argv:
#   1. a colliding tree is opened with discovery OFF and the cwd's own pins named once
#   2. a caller that already names its extensions is handed through untouched
#   3. a settings entry for the SAME tree is handed through (pi de-duplicates it itself)
#   4. no tree, or no settings entry, is handed through untouched
#   5. README.md and lib/ are not extensions, and the seat's npm packages are carried
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
door="$here/../pi-door.sh"
ok=0; fail=0
t() { local n=$1; shift; if "$@" >/tmp/.pd.$$ 2>&1; then ok=$((ok+1)); printf 'ok   %s\n' "$n"; else fail=$((fail+1)); printf 'FAIL %s\n' "$n"; sed -n 1,6p /tmp/.pd.$$ | sed 's/^/     /'; fi; rm -f /tmp/.pd.$$; }
bad() { printf '%s\n' "$*" >&2; return 1; }

[ -x "$door" ] || { printf 'FAIL the door is not executable: %s\n' "$door"; exit 1; }

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

# A fake harness on PATH: it only prints the argv the door handed it.
mkdir -p "$work/bin"
cat >"$work/bin/pi" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@"
FAKE
chmod +x "$work/bin/pi"

# This checkout: a flat pin, a directory pin, and two things that are NOT pins.
mkdir -p "$work/mine/.pi/extensions/constellation" "$work/mine/.pi/extensions/lib"
: >"$work/mine/.pi/extensions/elder.ts"
: >"$work/mine/.pi/extensions/constellation/index.ts"
: >"$work/mine/.pi/extensions/lib/helper.ts"
printf '# not an extension\n' >"$work/mine/.pi/extensions/README.md"
mkdir -p "$work/bare"

# Another checkout of the same repository, named by the seat's settings.
mkdir -p "$work/other/.pi/extensions"
: >"$work/other/.pi/extensions/elder.ts"

# <cwd> <extensions-json> [args…] -> the argv the fake harness received
door_out() {
  local cwd=$1 ext=$2; shift 2
  printf '{"defaultProvider":"x","packages":["npm:pi-mcp-adapter"],"extensions":[%s]}\n' "$ext" >"$work/settings.json"
  ( cd "$cwd" && YMIR_PI_SETTINGS="$work/settings.json" PATH="$work/bin:$PATH" exec bash "$door" "$@" )
}

first_line() { head -1; }
has() { grep -qxF -- "$2" "$1"; }  # <file> <line>

# A "no settings tree" variant: no `extensions` key at all.
door_out_no_entry() {
  local cwd=$1; shift
  printf '{"packages":[]}\n' >"$work/settings.json"
  ( cd "$cwd" && YMIR_PI_SETTINGS="$work/settings.json" PATH="$work/bin:$PATH" exec bash "$door" "$@" )
}

case_collision() {
  door_out "$work/mine" "\"$work/other/.pi/extensions\"" --list-models >"$work/out" || return 1
  first_line <"$work/out" | grep -qx -- '-ne' || bad "first arg is not -ne: $(first_line <"$work/out")"
  has "$work/out" "$work/other/.pi/extensions" && bad "the other checkout was named as a pin"
  has "$work/out" "$work/mine/.pi/extensions/elder.ts" || bad "the flat pin was not named"
  has "$work/out" "$work/mine/.pi/extensions/constellation/index.ts" || bad "the directory pin was not named"
  grep -qF 'lib/helper.ts' "$work/out" && bad "lib/ was loaded as a pin"
  grep -qF 'README.md' "$work/out" && bad "README.md was loaded as a pin"
  has "$work/out" "npm:pi-mcp-adapter" || bad "the seat package was dropped"
  has "$work/out" "--list-models" || bad "the caller's args were lost"
  return 0
}

case_caller_owns() {
  door_out "$work/mine" "\"$work/other/.pi/extensions\"" -ne -e /x.ts >"$work/out" || return 1
  first_line <"$work/out" | grep -qx -- '-ne' || bad "not handed through: $(first_line <"$work/out")"
  has "$work/out" "$work/mine/.pi/extensions/elder.ts" && bad "the door added pins to a caller-led argv"
  return 0
}

case_same_tree() {
  door_out "$work/mine" "\"$work/mine/.pi/extensions\"" --list-models >"$work/out" || return 1
  first_line <"$work/out" | grep -qx -- '--list-models' || bad "the door rewrote a single home: $(first_line <"$work/out")"
  return 0
}

case_no_tree() {
  door_out "$work/bare" "\"$work/other/.pi/extensions\"" --version >"$work/out" || return 1
  first_line <"$work/out" | grep -qx -- '--version' || bad "not handed through: $(first_line <"$work/out")"
  return 0
}

case_no_entry() {
  door_out_no_entry "$work/mine" --version >"$work/out" || return 1
  first_line <"$work/out" | grep -qx -- '--version' || bad "not handed through: $(first_line <"$work/out")"
  return 0
}

case_why() {
  printf '{"packages":[],"extensions":["%s"]}\n' "$work/other/.pi/extensions" >"$work/settings.json"
  ( cd "$work/mine" && YMIR_PI_SETTINGS="$work/settings.json" PATH="$work/bin:$PATH" exec bash "$door" --why ) >"$work/out" || return 1
  grep -q 'onehome' "$work/out" || bad "verdict missing: $(cat "$work/out")"
  grep -qF "$work/mine/.pi/extensions" "$work/out" || bad "the home is not named: $(cat "$work/out")"
  grep -qF "$work/other/.pi/extensions" "$work/out" || bad "the other tree is not named: $(cat "$work/out")"
  return 0
}

case_missing_harness() {
  out="$( cd "$work/mine" && YMIR_PI_SETTINGS="$work/settings.json" PATH=/usr/bin:/bin bash "$door" --version 2>&1 )" && \
    bad "a missing harness exited 0"
  printf '%s' "$out" | grep -q 'no pi on PATH' || bad "silent failure: $out"
  return 0
}

t "a colliding tree opens with one home" case_collision
t "a caller that names its extensions is handed through" case_caller_owns
t "a settings entry for the same tree is handed through" case_same_tree
t "a directory with no tree is handed through" case_no_tree
t "settings naming no tree are handed through" case_no_entry
t "--why names the collision and the home" case_why
t "a missing harness is refused in words" case_missing_harness

printf '\n%s passed, %s failed\n' "$ok" "$fail"
[ "$fail" -eq 0 ]
