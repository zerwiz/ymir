#!/usr/bin/env bash
# security-audit.sh — Vörðr's eyes: WHAT IS THIS MACHINE ACTUALLY EXPOSING?
#
# The fault this answers (2026-10-18): an agent measured the box by hand and found a
# public tunnel answering 200 with no login, sshd on every interface with password auth
# at its default, and a control plane allowed from anywhere — none of it watched by
# anything. "HOW SECURE are we handling our hardware and systems??" the Allfather asked.
# The answer must be a command, not an afternoon.
#
#   security-audit.sh [check] [--quiet] [--json] [--fixtures DIR]
#
# It MEASURES and it REPORTS. It changes nothing — closing a door is a decision, and a
# decision is the Allfather's (see bin/ward/harden.sh for the mends, written out).
#
# Every source is injectable for testing (`--fixtures DIR` reads recorded command
# outputs instead of running them), because a ward that can only be tested against the
# live machine is a ward nobody dares change.
#
# Exit: 0 nothing above the floor · 1 a HIGH or CRITICAL finding · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# The ONE resolver for the home (Rule 07 / Rule 22).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _w in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$ROOT/bin/vault/hoard-lib.sh"; do
    [ -r "$_w" ] && { . "$_w"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _w
fi
HOME_DIR=""
if [ -n "${YMIR_HOME:-}" ]; then HOME_DIR="$YMIR_HOME"
elif command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR
fi

QUIET=0 JSON=0 FIXTURES=""
while [ $# -gt 0 ]; do
  case "$1" in
    check) shift ;;
    --quiet|-q) QUIET=1; shift ;;
    --json) JSON=1; shift ;;
    --fixtures) FIXTURES="${2:?--fixtures needs a directory}"; shift 2 ;;
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown flag %s\nhelp: security-audit.sh [check] [--quiet] [--json] [--fixtures DIR]\n' "$1" >&2; exit 2 ;;
  esac
done

# ── the sources: a command, or a recorded fixture ─────────────────────────────
src() {  # <fixture-name> <command…>
  local name="$1"; shift
  if [ -n "$FIXTURES" ]; then
    [ -r "$FIXTURES/$name" ] && cat "$FIXTURES/$name" || true
    return 0
  fi
  "$@" 2>/dev/null || true
}

SS_OUT="$(src ss.out ss -tulnp)"
UFW_OUT="$(src ufw.out cat /etc/ufw/user.rules)"
UFW_DEFAULT="$(src ufw-default.out cat /etc/default/ufw)"
SSHD_T="$(src sshd-T.out sshd -T)"
SSHD_CONF="$(src sshd-conf.out cat /etc/ssh/sshd_config)"
AUTHZ="$(src authz.out cat "$HOME/.ssh/authorized_keys")"
DOCKER_PS="$(src docker.out docker ps --format '{{.Names}}|{{.Ports}}')"
CFG_DIR="${FIXTURES:+$FIXTURES/cloudflared}"; [ -n "$CFG_DIR" ] || CFG_DIR="$HOME/.cloudflared"
CLIENTS="$(src clients.out hyprctl clients -j)"

findings=0 crit=0 high=0
F_ROWS=""
add() {  # <severity> <what> <detail> <remedy>
  local sev="$1" what="$2" detail="$3" remedy="$4"
  findings=$((findings+1))
  case "$sev" in CRITICAL) crit=$((crit+1));; HIGH) high=$((high+1));; esac
  F_ROWS="${F_ROWS}  \"${sev}\",\"${what}\",\"${detail}\",\"${remedy}\"\n"
}
none() { printf 'security-audit[1]{severity,what,detail,remedy}:\n  "none","","nothing above the floor","—"\n'; }

# ── 1 · the doors: what listens, and for whom ─────────────────────────────────
# A wide bind is not automatically wrong — it is wrong when nothing says WHY.
wide_bind_is_named() {  # <port>
  local p="$1" why
  why="$(grep -rlsE "0\.0\.0\.0:?$p|:$p\b" "$ROOT/docs" "$ROOT/RULES" 2>/dev/null | head -1)"
  [ -n "$why" ]
}

if [ -n "$SS_OUT" ]; then
  # TCP only, deduped, and the benign wide binds skipped: a ward that reports every
  # browser's ephemeral port is a ward nobody reads. (mDNS 5353, tailscaled 41641,
  # and browser sockets above 32768 are noise, not doors.)
  while IFS= read -r line; do
    # The local address by PATTERN, not by column: `ss` column counts drift between
    # builds (and a fixture written by hand has no columns at all).
    local_addr="$(printf '%s' "$line" | grep -oE '(0\.0\.0\.0|\[::\]|\*|::|127\.0\.0\.1):[0-9*]+' | head -1)"
    [ -n "$local_addr" ] || continue
    port="${local_addr##*:}"
    bind="${local_addr%:*}"
    proc="$(printf '%s' "$line" | sed -nE 's/.*users:\(\("([^"]+)".*/\1/p')"
    case "$bind" in
      0.0.0.0|\[::\]|\*|::) ;;
      *) continue ;;
    esac
    case "$port" in 41641|5353) continue ;; esac
    case "$proc:$port" in
      *:5*) ;;                                   # below 32768: keep looking at it
      *) case "$port" in
           3[3-9][0-9][0-9][0-9]|[4-6][0-9][0-9][0-9][0-9]) continue ;;   # ephemeral range
         esac ;;
    esac
    case "$proc" in chromium|brave|firefox|chrome|code) case "$port" in
        3[3-9][0-9][0-9][0-9]|*) ;; esac ;; esac
    case "$port" in
      8080) add MEDIUM "the model rail is on every interface" "0.0.0.0:$port ($proc)" "it is keyed and restricted in ufw — keep it that way; a firewall slip exposes a model service" ;;
      22)   add HIGH "ssh on every interface" "0.0.0.0:$port ($proc)" "ufw allows 22 from ANY source — narrow it to the LAN and tailscale0 (bin/ward/harden.sh plan)" ;;
      3888) add MEDIUM "the hall's SPA is on every interface" "0.0.0.0:$port ($proc)" "ufw does not allow it today; bind it to loopback or the tailnet so a firewall change cannot expose the UI" ;;
      3889|3881) add HIGH "the control plane is on every interface" "0.0.0.0:$port ($proc)" "ufw allows it from ANY address — narrow it to the tailnet and the tunnel (bin/ward/harden.sh plan)" ;;
      80|443|8000|8008|3003) add HIGH "a service is on every interface" "0.0.0.0:$port ($proc)" "name why it must be reachable, or bind it to the tailnet" ;;
      *)   add MEDIUM "an unnamed wide bind" "0.0.0.0:$port ($proc)" "write down why it listens on every interface, or bind it to loopback" ;;
    esac
  done < <(printf '%s\n' "$SS_OUT" | awk 'NR>1 && /LISTEN/' | sort -u -k5,5)
fi

# ── 2 · the wall: does ufw actually cover those doors ─────────────────────────
if [ -n "$UFW_OUT" ]; then
  case "$UFW_DEFAULT" in
    *DEFAULT_INPUT_POLICY=\"DROP\"*) : ;;
    *) add HIGH "the firewall's default policy is not DROP" "$(printf '%s' "$UFW_DEFAULT" | grep -E '^DEFAULT_INPUT' | head -1)" "set DEFAULT_INPUT_POLICY=\"DROP\" in /etc/default/ufw" ;;
  esac
  # an allow with no source is an allow from anywhere
  while IFS= read -r rule; do
    [ -n "$rule" ] || continue
    port="$(printf '%s' "$rule" | sed -nE 's/.*--dport ([0-9]+).*/\1/p')"
    [ -n "$port" ] || continue
    case "$rule" in
      *"-s "*) continue ;;                     # source-restricted
      *"-i tailscale0"*) continue ;;           # tailnet only
    esac
    case "$port" in
      53317) add MEDIUM "a peer-transfer port answers the whole network" "ufw: --dport $port with no source (LocalSend)" "keep it if the operator uses it deliberately — write that down here and in the port note" ;;
      *)     add HIGH "a port is allowed from ANY address" "ufw: --dport $port with no source" "narrow it to the LAN subnet and tailscale0, or say why the world may knock" ;;
    esac
  done < <(printf '%s\n' "$UFW_OUT" | grep -E 'dport' | sort -u || true)
fi

# ── 3 · the lock: how sshd would let somebody in ──────────────────────────────
if [ -n "$SSHD_T" ]; then
  PA="$(printf '%s' "$SSHD_T" | sed -nE 's/^passwordauthentication (.*)/\1/ip' | head -1)"
  RK="$(printf '%s' "$SSHD_T" | sed -nE 's/^permitrootlogin (.*)/\1/ip' | head -1)"
  KEYCOUNT="$(printf '%s\n' "$AUTHZ" | grep -c '^ssh-' || true)"
  [ "$PA" = "yes" ] && add HIGH "sshd accepts PASSWORDS" "PasswordAuthentication yes (compiled default: no drop-in overrides it)" "keys only: a drop-in with 'PasswordAuthentication no' (bin/ward/harden.sh plan --sshd)"
  [ "$KEYCOUNT" = "0" ] && add CRITICAL "no ssh key is authorized" "authorized_keys holds no 'ssh-' line" "seat a key BEFORE turning passwords off, or you will lock yourself out"
  case "$RK" in yes) add HIGH "root may log in with a password" "PermitRootLogin yes" "set it to prohibit-password" ;; esac
else
  # No sshd -T (no root): say what the file says, honestly.
  case "$SSHD_CONF" in
    *'#PasswordAuthentication yes'*) add MEDIUM "the sshd password policy is at its default" "sshd_config leaves PasswordAuthentication commented (compiled default applies)" "run the audit with root for the effective value: sudo bin/ward/security-audit.sh" ;;
  esac
fi

# ── 4 · the tunnels: what we publish to the world ─────────────────────────────
if [ -d "$CFG_DIR" ]; then
  for f in "$CFG_DIR"/config-*.yml; do
    [ -r "$f" ] || continue
    hn="$(sed -nE 's/^[[:space:]]*-[[:space:]]*hostname:[[:space:]]*(.*)/\1/p' "$f" | head -1)"
    svc="$(sed -nE 's/^[[:space:]]*service:[[:space:]]*(http.*)/\1/p' "$f" | head -1)"
    [ -n "$hn" ] || continue
    # The probe is a SOURCE like the others: a recorded answer (fixture
    # probe-<host>.out) is used when given, so the CRITICAL path is testable without
    # touching the internet.
    recorded=""
    [ -n "$FIXTURES" ] && [ -r "$FIXTURES/probe-$hn.out" ] && recorded="$(cat "$FIXTURES/probe-$hn.out")"
    code=""
    if [ -n "$recorded" ]; then
      code="$recorded"
    elif [ -z "$FIXTURES" ] && command -v curl >/dev/null 2>&1; then
      code="$(curl -s -o /dev/null -w '%{http_code}' -m 6 "https://$hn/" 2>/dev/null || printf '000')"
    fi
    if [ -z "$code" ]; then
      add MEDIUM "a public tunnel is configured" "https://$hn → $svc" "the harness could not probe it (offline or no curl) — check its auth by hand"
      continue
    fi
    case "$code" in
      200|204|301|302|307|308) add CRITICAL "a PUBLIC tunnel answers without a login" "https://$hn → $svc (HTTP $code, no auth challenge)" "put it behind a login (Cloudflare Access or the app's own gate), or take it down" ;;
      401|403)                 : ;;                 # gated is the goal: no finding
      *)                       add MEDIUM "a tunnel is configured but not answering" "https://$hn → $svc (HTTP $code)" "confirm it is meant to exist; an unexamined tunnel is a door nobody is watching" ;;
    esac
  done
fi

# ── 5 · the secrets at rest ───────────────────────────────────────────────────
if [ -n "$HOME_DIR" ] && [ -d "$HOME_DIR/hodd/secrets" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$(basename "$f")" in .*|*.age|*.pub|*.example) continue ;; esac
    mode="$(stat -c '%a' "$f" 2>/dev/null || printf '?')"
    case "$mode" in
      600|400) ;;
      *) add MEDIUM "a plaintext secret is group/world readable" "$(basename "$f") mode $mode" "chmod 600 it (the vault holds the encrypted copy)" ;;
    esac
  done < <(find "$HOME_DIR/hodd/secrets" -maxdepth 1 -type f 2>/dev/null)
fi

# ── 6 · the watchers: is anything even installed to notice? ───────────────────
have_any=0
WATCHERS="$(src watchers.out true)"
if [ -n "$WATCHERS" ]; then
  while IFS= read -r t; do [ -n "$t" ] && have_any=1; done < <(printf '%s\n' "$WATCHERS")
else
  for t in fail2ban-server crowdsec lynis aide osqueryd falco auditd; do
    command -v "$t" >/dev/null 2>&1 && have_any=1
  done
fi
[ "$have_any" = 0 ] && add HIGH "nothing watches this host" "no fail2ban/crowdsec/lynis/aide/osquery/falco installed" "plan 81 S2-S3: a ban for brute force, and a file-integrity baseline"

# ── the report ────────────────────────────────────────────────────────────────
if [ "$JSON" = 1 ]; then
  printf '{"findings":%s,"critical":%s,"high":%s}\n' "$findings" "$crit" "$high"
else
  if [ "$QUIET" = 1 ] && [ "$crit" = 0 ] && [ "$high" = 0 ]; then
    none
  elif [ "$findings" = 0 ]; then
    none
  else
    printf 'security-audit[%s]{severity,what,detail,remedy}:\n' "$findings"
    printf '%b' "$F_ROWS" | grep -v '"NONE_LINE"'
    printf 'security-audit: %s finding(s) — %s critical, %s high\n' "$findings" "$crit" "$high"
  fi
fi

[ "$crit" -gt 0 ] || [ "$high" -gt 0 ] && exit 1
exit 0
