#!/usr/bin/env bash
# hoard-lib.sh — where the operator's HOME lives, and the two roots beneath it.
#
# The law (RULES/04-hoard.md): no private thing — not a name, a key, a plan, a
# schedule, a client, a note — ever sits inside this repo. It lives in ONE place
# the operator OWNS and CHOSE at installation, and every script resolves that
# place HERE, so the answer can never drift between them (Rule 07: configuration
# is never hardcoded; ONE documented default).
#
#   ymir_home_root   the chosen home        ($YMIR_HOME → the recorded choice → the default)
#   hoard_root       the hoard within it    ($YMIR_HOARD → <home>/hodd)
#   hoard_data_dir   this machine's records ($YMIR_DATA_DIR → <hoard>/data)
#   hoard_state_dir  runtime state          ($YMIR_STATE_DIR → <home>/state)
#   ymir_fleet_heart the fleet's heart      ($YMIR_HEART → the home's fleet.json `heart`)
#   ymir_plan_dir    the plan ledger        ($YMIR_PLAN_DIR → the single ledger under the home)
#
# The last two exist for the same reason as the rest: the REPOSITORY is public and
# ships to any operator, so it may not name this operator's machines or his realm
# (RULES/04, RULES/25). A caller that needs "the heart" or "the ledger" asks HERE;
# the answer is discovered from the home, and a home that records neither answers
# empty so the caller can name what to set instead of printing a stranger's host.
#
# The recorded choice is machine state, not user data: a path under
# `~/.config/ymir/` (the same place `engram-python` and `accounts.json` live), so
# a packaged install can be told where the home is without the home having to sit
# in the package. The tree is code; the home is the operator's.
#
# Source-safe, defines functions only; call `<fn> <result-var>`.
set -u

# Where a machine records its choices (never in the repo, never in the home).
YMIR_CONFIG_DIR="${YMIR_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/ymir}"
YMIR_HOME_DEFAULT="${YMIR_HOME_DEFAULT:-$HOME/Documents/ymirhome}"

ymir_home_record() {  # <result-var> — the home recorded at installation, or empty
  local result_var=${1-} f="$YMIR_CONFIG_DIR/home"
  [ -n "$result_var" ] || return 2
  if [ -r "$f" ]; then
    # Trim the EDGES only. `tr -d '[:space:]'` was here until 2026-11-11 and it
    # deleted the spaces INSIDE the path: a home at `/mnt/c/Users/<windows-profile>/ymirhome`
    # resolved as `/mnt/c/Users/AgentSeb/ymirhome`, and every door that tells the
    # operator their home is set was pointing at a directory that does not exist.
    # A Windows profile name very often carries a space, so this is not an edge case.
    # The `\r` strip is for a record written or edited on the Windows side.
    printf -v "$result_var" '%s' "$(head -n1 "$f" 2>/dev/null | sed 's/\r$//; s/^[[:space:]]*//; s/[[:space:]]*$//')"
  else
    printf -v "$result_var" '%s' ""
  fi
}

ymir_home_root() {  # <result-var> — the operator's home: env → recorded → default
  local result_var=${1-} rec=""
  [ -n "$result_var" ] || return 2
  if [ -n "${YMIR_HOME:-}" ]; then
    printf -v "$result_var" '%s' "$YMIR_HOME"; return 0
  fi
  ymir_home_record rec
  printf -v "$result_var" '%s' "${rec:-$YMIR_HOME_DEFAULT}"
}

ymir_home_record_set() {  # <path> — record the operator's choice (machine state)
  local home=${1-}
  [ -n "$home" ] || return 2
  mkdir -p "$YMIR_CONFIG_DIR" 2>/dev/null || return 1
  printf '%s\n' "$home" >"$YMIR_CONFIG_DIR/home" || return 1
}

hoard_root() {  # <result-var> — the hoard inside the home (may not exist yet)
  local result_var=${1-} home
  [ -n "$result_var" ] || return 2
  if [ -n "${YMIR_HOARD:-}" ]; then
    printf -v "$result_var" '%s' "$YMIR_HOARD"; return 0
  fi
  ymir_home_root home
  printf -v "$result_var" '%s' "$home/hodd"
}

hoard_env() {  # <result-var> — the platform env file inside the hoard
  local result_var=${1-} root
  [ -n "$result_var" ] || return 2
  hoard_root root
  printf -v "$result_var" '%s' "$root/secrets/platform.env"
}

# This machine's own records (operator, fleet, the host profile) and the runtime
# state (pids, logs, locks). Both live in the HOME — never in the code tree: a
# packaged install treats its tree as read-only and the next upgrade replaces it,
# so state written there is state lost. One documented default each; an env
# override wins, so a single machine can point a root elsewhere without a fork.
hoard_data_dir() {  # <result-var> — where this machine's records live
  local result_var=${1-} root
  [ -n "$result_var" ] || return 2
  hoard_root root
  printf -v "$result_var" '%s' "${YMIR_DATA_DIR:-$root/data}"
}

hoard_state_dir() {  # <result-var> — runtime state: ephemeral, outside the tree
  local result_var=${1-} home
  [ -n "$result_var" ] || return 2
  ymir_home_root home
  printf -v "$result_var" '%s' "${YMIR_STATE_DIR:-$home/state}"
}

# The operator's SETTINGS — the agent set, cron, the local env file with its
# credentials. Settings are the operator's, not the package's: a packaged tree is
# replaced on upgrade, and a credential must never sit in a tree that ships.
hoard_settings_dir() {  # <result-var> — the settings dir inside the home
  local result_var=${1-} home
  [ -n "$result_var" ] || return 2
  ymir_home_root home
  printf -v "$result_var" '%s' "${YMIR_SETTINGS_DIR:-$home/config}"
}

hoard_local_env() {  # <result-var> — the operator's env file (secrets, ports)
  local result_var=${1-} home
  [ -n "$result_var" ] || return 2
  ymir_home_root home
  printf -v "$result_var" '%s' "${YMIR_ENV_FILE:-$home/.env.local}"
}

ymir_fleet_heart() {  # <result-var> — the host the home's fleet registry names as the heart
  # $YMIR_HEART wins (a machine may be told), else the registry's `heart` key. Never a
  # literal host: a fleet of one, or a fleet with another heart, must not inherit ours.
  local result_var=${1-} home reg heart
  [ -n "$result_var" ] || return 2
  if [ -n "${YMIR_HEART:-}" ]; then
    printf -v "$result_var" '%s' "$YMIR_HEART"; return 0
  fi
  ymir_home_root home
  reg="${YMIR_FLEET_REGISTRY:-$home/hodd/data/fleet.json}"
  [ -r "$reg" ] || return 1
  heart="$(python3 - "$reg" <<'PY' 2>/dev/null
import json, sys
try:
    print((json.load(open(sys.argv[1])) or {}).get("heart") or "")
except Exception:
    print("")
PY
)"
  [ -n "$heart" ] || return 1
  printf -v "$result_var" '%s' "$heart"
}

ymir_plan_dir() {  # <result-var> — the canonical plan ledger, DISCOVERED inside the home
  # The ledger sits under a realm named by THIS operator, so the repository cannot
  # spell the path. It is found instead: exactly one `svartalfaheim/<realm>/projects/
  # <project>/plans` is the ledger; the older `workspace/<project>/plans` shape is
  # read only when the first shape has none (Rule 25: probe, never assume).
  # Exit: 0 one ledger · 1 none in this home · 2 more than one (name one with YMIR_PLAN_DIR).
  local result_var=${1-} project=${2:-ymir} home cand found=()
  [ -n "$result_var" ] || return 2
  if [ -n "${YMIR_PLAN_DIR:-}" ]; then
    printf -v "$result_var" '%s' "$YMIR_PLAN_DIR"; return 0
  fi
  ymir_home_root home
  for cand in "$home"/svartalfaheim/*/projects/"$project"/plans; do
    [ -d "$cand" ] && found+=("$cand")
  done
  if [ "${#found[@]}" -eq 0 ]; then
    for cand in "$home"/svartalfaheim/*/workspace/"$project"/plans; do
      [ -d "$cand" ] && found+=("$cand")
    done
  fi
  case "${#found[@]}" in
    0) return 1 ;;
    1) printf -v "$result_var" '%s' "${found[0]}" ;;
    *) return 2 ;;
  esac
}

ymir_house_domains() {  # <result-var> — space-separated domains the home declares as the house's own
  # A commit may be authored as a HOUSE identity (`<agent>@<house domain>`), and the record
  # shows such an author unmasked. WHICH domains are the house's is the operator's fact, so it
  # is read from his home ($YMIR_HOUSE_DOMAINS, else hodd/identity/house-domains.txt) and never
  # written here (RULES/04). A home that declares none answers 1: callers then allow only the
  # generic forms (`@ymir`, `@ymir.local`, `@users.noreply.github.com`).
  local result_var=${1-} home listing list
  [ -n "$result_var" ] || return 2
  if [ -n "${YMIR_HOUSE_DOMAINS:-}" ]; then
    printf -v "$result_var" '%s' "$YMIR_HOUSE_DOMAINS"; return 0
  fi
  ymir_home_root home
  listing="${YMIR_HOUSE_DOMAINS_FILE:-$home/hodd/identity/house-domains.txt}"
  [ -r "$listing" ] || return 1
  list="$(sed -e 's/#.*//' "$listing" | tr -d '[:blank:]' | grep -v '^$' | paste -sd' ' -)"
  [ -n "$list" ] || return 1
  printf -v "$result_var" '%s' "$list"
}

hoard_memory_store() {  # <result-var> — Kaia's engram store, ALWAYS in the hoard
  # The well is one memory and it lives in the hoard (hodd/memory) — never in
  # the tree, never in a migrated copy. Everything that reads the store resolves
  # through here so no script can point the well at a duplicate (Rule 04/07).
  local result_var=${1-} home
  [ -n "$result_var" ] || return 2
  ymir_home_root home
  printf -v "$result_var" '%s' "$home/hodd/memory/kaia.engram"
}
