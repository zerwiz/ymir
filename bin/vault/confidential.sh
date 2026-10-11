#!/usr/bin/env bash
# confidential.sh — a session where vault work has no route off the vault (Rule 16).
#
#   bin/vault/confidential.sh start [--tier local|none|remote] [--airlock] [--sandbox] [--name N] [-- CMD…]
#   bin/vault/confidential.sh stop
#   bin/vault/confidential.sh status
#
# A confidential session confines the work to the vault: the workdir lives inside the
# mount, every off-vault record door (the well, tickets, runes, the daily log) is
# turned OFF, the model tier is explicit (local-on-machine / none / remote), and the
# isolation is chosen:
#   --airlock  bwrap --unshare-net: an INTERACTIVE shell with no network at all
#   --sandbox  Utgard (sandcastle/docker): a SEALED ONE-SHOT — read-only rootfs, only
#              the vault workdir mounted, no network, CPU/RAM/timeout caps
# While it is live, `confidential-guard` refuses to commit anything outside the vault.
# Sealed by default; the vault is opened by the operator, never by an agent.
set -u
VERSION="1.0.0"

# --- the hoard resolver (Rule 04/07) ---------------------------------------
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _hc="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_hc" ] || break
    if [ -r "$_hc/bin/vault/hoard-lib.sh" ]; then . "$_hc/bin/vault/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_hc/hoard-lib.sh" ]; then . "$_hc/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _hc="$(cd "$_hc/.." 2>/dev/null && pwd)"
  done
  unset _hc _i
fi

_ymir_home=""
command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root _ymir_home
[ -n "$_ymir_home" ] || { printf 'error: cannot resolve the operator home — bin/vault/hoard-lib.sh is missing\n' >&2; exit 2; }

# the repo root (for the Utgard door)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"

VAULT_MNT="${YMIR_VAULT_MNT:-$HOME/Vault}"
MAPPER="hnitbjorg"
STATE="${YMIR_STATE_DIR:-$_ymir_home/state}"
MARKER="$STATE/confidential.session"
WORKROOT="$VAULT_MNT/confidential"
LOCAL_MODEL="${YMIR_CONFIDENTIAL_MODEL:-http://127.0.0.1:8080/v1}"

say() { printf '%s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

vault_open() { cryptsetup status "$MAPPER" >/dev/null 2>&1 && mountpoint -q "$VAULT_MNT"; }

cmd_start() {
  local tier="local" airlock=0 sandbox=0 name="" ; name="session-$$"
  local -a CMD=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --tier) tier="${2:?--tier needs local|none|remote}"; shift 2 ;;
      --airlock) airlock=1; shift ;;
      --sandbox) sandbox=1; shift ;;
      --name) name="${2:?--name needs a value}"; shift 2 ;;
      --) shift; CMD=("$@"); break ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  case "$tier" in local|none|remote) ;; *) die "unknown tier '$tier' (use local|none|remote)" ;; esac

  if [ "${YMIR_CONFIDENTIAL_ASSUME_OPEN:-0}" != 1 ]; then
    vault_open || die "the vault is not open — run: bin/vault/hnitbjorg.sh open"
  fi
  local workdir="$WORKROOT/$name"
  mkdir -p "$workdir" || die "could not make the session dir inside the vault"
  chmod 700 "$WORKROOT" "$workdir" 2>/dev/null || true
  mkdir -p "$STATE"
  printf 'mount=%s\ntier=%s\nairlock=%s\nstarted=%s\n' "$VAULT_MNT" "$tier" "$airlock" "$(date -Is)" > "$MARKER"

  # The session environment: the boundary, made of settings.
  local -a envs=(
    "YMIR_CONFIDENTIAL=1"
    "YMIR_CONFIDENTIAL_TIER=$tier"
    "YMIR_CONFIDENTIAL_WORK=$workdir"
    # every off-vault record door, turned off or pointed inside the session
    "ENGRAM_DB=$workdir/.mem.engram"
    "YMIR_BROKK_OFFLINE=1"
  )
  case "$tier" in
    local)
      envs+=("LLM_PROVIDER=generic-openai"
             "GENERIC_OPEN_AI_BASE_PATH=$LOCAL_MODEL"
             "GENERIC_OPEN_AI_API_KEY=sk-no-key-required"
             "OPENAI_BASE_URL=$LOCAL_MODEL"
             "YMIR_NO_REMOTE=1")
      say "model tier: LOCAL ONLY ($LOCAL_MODEL) — no remote endpoint is configured" ;;
    none)
      envs+=("YMIR_NO_MODEL=1")
      say "model tier: NONE — no model is reachable from this session" ;;
    remote)
      say "model tier: REMOTE — the operator's configured provider is allowed" ;;
  esac

  say "confidential session '$name' — working in $workdir"
  say "no well · no tickets · no runes · no daily log · nothing outside the vault may be committed"
  [ "$airlock" = 1 ] && say "AIRLOCK: no network at all (bwrap --unshare-net)"

  # --- the sealed one-shot: Utgard (the sandcastle/docker engine), only this workdir
  # mounted, read-only rootfs, no network. Paths are the CONTAINER's, not the host's.
  if [ "$sandbox" = 1 ]; then
    [ "${#CMD[@]}" -gt 0 ] || die "--sandbox needs a command after -- (it is a one-shot, not a shell)"
    [ -x "$ROOT/bin/forge/utgard.sh" ] || die "the Utgard door is missing: bin/forge/utgard.sh"
    say "SANDBOX: Utgard — read-only rootfs, only '$workdir' mounted, no network"
    exec "$ROOT/bin/forge/utgard.sh" run "$workdir" --network none -- \
      env "YMIR_CONFIDENTIAL=1" "YMIR_CONFIDENTIAL_TIER=$tier" "YMIR_CONFIDENTIAL_WORK=/sandbox/workspace" \
          "ENGRAM_DB=/sandbox/workspace/.mem.engram" "YMIR_BROKK_OFFLINE=1" "${CMD[@]}"
  fi

  local -a runner=()
  if [ "$airlock" = 1 ]; then
    command -v bwrap >/dev/null 2>&1 || die "bwrap (bubblewrap) is required for --airlock"
    runner=(bwrap --unshare-net --dev-bind / / --chdir "$workdir" env "${envs[@]}")
  else
    runner=(env "${envs[@]}")
  fi

  if [ "${#CMD[@]}" -gt 0 ]; then
    if [ "$airlock" = 1 ]; then exec "${runner[@]}" "${CMD[@]}"; else cd "$workdir" && exec "${runner[@]}" "${CMD[@]}"; fi
  else
    if [ "$airlock" = 1 ]; then exec "${runner[@]}" bash; else cd "$workdir" && exec "${runner[@]}" bash; fi
  fi
}

cmd_stop() {
  [ -f "$MARKER" ] && rm -f "$MARKER" && printf 'confidential[1]{action,state}:\n  "stop","session closed"\n' \
    || printf 'confidential[1]{action,state}:\n  "stop","no session was live"\n'
}

cmd_status() {
  if [ -f "$MARKER" ]; then
    local tier mount
    tier="$(sed -n 's/^tier=//p' "$MARKER")"; mount="$(sed -n 's/^mount=//p' "$MARKER")"
    printf 'confidential[3]{state,tier,mount}:\n  "live","%s","%s"\n' "$tier" "$mount"
  else
    printf 'confidential[3]{state,tier,mount}:\n  "none","-","-"\n'
  fi
}

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="$1"; shift || true
case "$ACTION" in
  start)  cmd_start "$@" ;;
  stop)   cmd_stop "$@" ;;
  status) cmd_status "$@" ;;
  *) die "unknown action: $ACTION — help: $(basename "$0") --help" ;;
esac
