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
# THE DROP-INS ARE THE EFFECTIVE ANSWER. Omarchy and this house both write
# /etc/ssh/sshd_config.d/*.conf, and sshd reads them AFTER the base file — so an unprivileged
# audit that reads only /etc/ssh/sshd_config reported "PasswordAuthentication is at its default"
# on a machine that had said `no` twice. Measured 2026-11-10. The drop-ins are world-readable,
# so there is no excuse for not reading them.
SSHD_DROPS="$(src sshd-drops.out sh -c 'cat /etc/ssh/sshd_config.d/*.conf 2>/dev/null')"
# THE OPERATOR'S WORD, written down: a wide bind that is deliberate stops being a finding.
# One line per port: `<port> <why>`; `#` comments. Read from the home, never from the repo.
PORT_NOTE="${SECURITY_AUDIT_PORT_NOTE:-}"
if [ -z "$PORT_NOTE" ]; then
  # THE HOME IS RESOLVED, NEVER GUESSED (Rule 07): the one resolver answers, so this ward reads the
  # same note the rest of the house writes.
  _root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  # shellcheck disable=SC1091
  . "$_root/bin/vault/hoard-lib.sh" 2>/dev/null || true
  _home=""
  command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root _home 2>/dev/null || true
  [ -n "$_home" ] && [ -r "$_home/config/declared-ports.txt" ] && PORT_NOTE="$_home/config/declared-ports.txt"
fi
declared_why() {  # <port> -> the operator's reason, or empty
  [ -n "$PORT_NOTE" ] && [ -r "$PORT_NOTE" ] || return 0
  awk -v want="$1" 'BEGIN{IGNORECASE=0} /^[[:space:]]*#/ {next} $1==want { $1=""; sub(/^[[:space:]]+/,""); print; exit }' "$PORT_NOTE" 2>/dev/null
}
AUTHZ="$(src authz.out cat "$HOME/.ssh/authorized_keys")"
DOCKER_PS="$(src docker.out docker ps --format '{{.Names}}|{{.Ports}}')"
CFG_DIR="${FIXTURES:+$FIXTURES/cloudflared}"; [ -n "$CFG_DIR" ] || CFG_DIR="$HOME/.cloudflared"
CLIENTS="$(src clients.out bash "$SCRIPT_DIR/../desktop/hypr.sh" windows --json)"   # the one Hyprland door (plan 341.2)

findings=0 crit=0 high=0
NOTES=()
note_wide() { NOTES+=("$1|$2|$3"); }
F_ROWS=""
add() {  # <severity> <what> <detail> <remedy>
  local sev="$1" what="$2" detail="$3" remedy="$4"
  findings=$((findings+1))
  case "$sev" in CRITICAL) crit=$((crit+1));; HIGH) high=$((high+1));; esac
  F_ROWS="${F_ROWS}  \"${sev}\",\"${what}\",\"${detail}\",\"${remedy}\"\n"
}
none() { printf 'security-audit[1]{severity,what,detail,remedy}:\n  "none","","nothing above the floor","—"\n'; }
# A declared wide bind is not a fault, but it is not SILENCE either: the operator wrote a reason,
# and the report says so on every run, so the reason is read as often as the findings are.
notes_out() {
  [ "${#NOTES[@]}" -eq 0 ] && return 0
  # one line per port: an IPv4 and an IPv6 socket are the same door
  local uniq=(); local n
  for n in "${NOTES[@]}"; do
    case " ${uniq[*]:-} " in *" $n "*) continue ;; esac
    uniq+=("$n")
  done
  NOTES=("${uniq[@]}")
  printf 'security-audit-notes[%s]{port,process,why}:\n' "${#NOTES[@]}"
  for n in "${NOTES[@]}"; do
    IFS='|' read -r p pr w <<< "$n"
    printf '  "%s","%s","%s"\n' "$p" "$pr" "$w"
  done
}

# ── 1 · the doors: what listens, and for whom ─────────────────────────────────
# A wide bind is not automatically wrong — it is wrong when nothing says WHY.
wide_bind_is_named() {  # <port>
  local p="$1" why
  why="$(grep -rlsE "0\.0\.0\.0:?$p|:$p\b" "$ROOT/docs" "$ROOT/RULES" 2>/dev/null | head -1)"
  [ -n "$why" ]
}

# A wide bind says WHERE a door is, never WHO may knock. Two kinds of door answer a
# knock with no credential, and both were invisible to this ward until 2026-11-16:
#   · an MCP server — `initialize` is a complete and harmless request, and a server that
#     answers it without a token answers every tool it holds the same way;
#   · an SMB share — `guest ok` with `read only = No` is a writable door for anybody.
# Measured on the heart that day: :8319 and :8321 both completed an unauthenticated MCP
# handshake (`snotra` listed and read the meeting record's tools), and five CasaOS shares
# were guest-writable as root. Neither fact was in the report, because nothing asked.
MCP_PROBE='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"security-audit","version":"1"}}}'
# <port> → the server's own answer, or empty. A fixture `mcp-<port>.out` is used when given.
mcp_answer() {  # <port>
  local port="$1"
  if [ -n "$FIXTURES" ]; then
    [ -r "$FIXTURES/mcp-$port.out" ] && cat "$FIXTURES/mcp-$port.out"
    return 0
  fi
  command -v curl >/dev/null 2>&1 || return 0
  curl -s -m 2 -X POST "http://127.0.0.1:$port/mcp" \
    -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' \
    -d "$MCP_PROBE" 2>/dev/null | head -c 4000
}
# SMB shares, as `testparm -s` prints them (a fixture `smb.out` is used when given).
smb_shares() {
  if [ -n "$FIXTURES" ]; then
    [ -r "$FIXTURES/smb.out" ] && cat "$FIXTURES/smb.out"
    return 0
  fi
  command -v testparm >/dev/null 2>&1 || return 0
  testparm -s 2>/dev/null || true
}

WIDE_PORTS=()
SEEN_PORTS=()
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
    # `0.0.0.0:*` is a unix/raw socket or an ephemeral UDP one: no port, no door to knock on.
    case "$port" in ''|'*') continue ;; esac
    bind="${local_addr%:*}"
    proc="$(printf '%s' "$line" | sed -nE 's/.*users:\(\("([^"]+)".*/\1/p')"
    case "$bind" in
      0.0.0.0|\[::\]|\*|::) ;;
      *) continue ;;
    esac
    # ONE DOOR, ONE JUDGEMENT: a v4 and a v6 socket are the same service, and so are
    # two listeners whose peer column reads the same. Dedupe on the PORT, never on a
    # column of `ss` — the old `sort -u -k5,5` collapsed every wide bind that shared a
    # peer address, which is every one of them (measured 2026-11-16: :8319 and :8321
    # both vanished from the report in a fixture because their fifth column matched).
    case " ${SEEN_PORTS[*]:-} " in *" $port "*) continue ;; esac
    SEEN_PORTS+=("$port")
    case "$port" in 41641|5353) continue ;; esac
    case " ${WIDE_PORTS[*]:-} " in *" $port "*) ;; *) WIDE_PORTS+=("$port") ;; esac
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
      22)   if printf '%s' "$UFW_OUT" | grep -qE 'dport 22|dport 22$' && \
                printf '%s' "$UFW_OUT" | grep -E 'dport 22' | grep -qvE -- '-s |tailscale'; then
             add HIGH "ssh answers the whole network" "0.0.0.0:$port ($proc)" "ufw allows 22 with no source — narrow it to the LAN and tailscale0 (bin/ward/harden.sh plan)"
           elif [ -n "$(declared_why 22)" ]; then
             :
           else
             note_wide "22" "$proc" "sshd binds every interface; ufw restricts it to the LAN and the tailnet — a bind is not a door while the wall holds"
           fi ;;
      3888) add MEDIUM "the hall's SPA is on every interface" "0.0.0.0:$port ($proc)" "ufw does not allow it today; bind it to loopback or the tailnet so a firewall change cannot expose the UI" ;;
      3889|3881) add HIGH "the control plane is on every interface" "0.0.0.0:$port ($proc)" "ufw allows it from ANY address — narrow it to the tailnet and the tunnel (bin/ward/harden.sh plan)" ;;
      80|443|8000|8008|3003) add HIGH "a service is on every interface" "0.0.0.0:$port ($proc)" "name why it must be reachable, or bind it to the tailnet" ;;
      *)   why="$(declared_why "$port")"
           if [ -n "$why" ]; then
             note_wide "$port" "$proc" "declared: $why"
           else
             add MEDIUM "an unnamed wide bind" "0.0.0.0:$port ($proc)" "write down why it listens on every interface in config/declared-ports.txt, or bind it to loopback"
           fi ;;
    esac
  done < <(printf '%s\n' "$SS_OUT" | awk 'NR>1 && /LISTEN/')
fi

# ── 1b · the doors that say "come in" themselves ──────────────────────────────
# A wide bind is a location. These two are the doors that hand out their own key:
# an MCP that completes `initialize` with no token, and an SMB share open to guests.
if [ "${#WIDE_PORTS[@]}" -gt 0 ]; then
  for wp in "${WIDE_PORTS[@]}"; do
    [ -n "$wp" ] || continue
    answer="$(mcp_answer "$wp")"
    case "$answer" in
      *'"serverInfo"'*)  servername="$(printf '%s' "$answer" | sed -nE 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1)"
                          add HIGH "an MCP answers without a credential" "0.0.0.0:$wp (${servername:-unknown server}) completed an unauthenticated MCP initialize" "bind it to loopback, or put a token in front of every tool it holds; a network is not a credential" ;;
      *'"error"'*)       : ;;   # gated: the server refused the handshake, so the door is shut
    esac
  done
fi

SMB_OUT="$(smb_shares)"
if [ -n "$SMB_OUT" ]; then
  # Each share is a `[name]` header followed by its keys. Both keys are judged, and
  # `force user = root` is named in the detail because it is what makes the write a
  # write as root — the difference between a nuisance and a takeover.
  while IFS="$(printf '\t')" read -r share mode as_root where; do
    [ -n "$share" ] || continue
    if [ "$mode" = write ]; then
      add HIGH "an SMB share is open to guests and writable" "[$share]$as_root → $where" "set 'guest ok = no' on the share (and never 'force user = root' on a write path), or stop samba"
    else
      add MEDIUM "an SMB share is open to guests" "[$share] read-only → $where" "set 'guest ok = no' unless the share is meant for the whole house"
    fi
  done < <(printf '%s\n' "$SMB_OUT" | awk '
    function emit() {
      if (name != "" && guest == "yes")
        printf "%s\t%s\t%s\t%s\n", name, (rw == "yes" ? "write" : "read"), root, path
      name = ""; guest = ""; rw = ""; root = ""; path = ""
    }
    /^\[/ { emit(); name = $0; gsub(/^\[|\]$/, "", name); next }
    /^[[:space:]]*guest ok[[:space:]]*=/ { if ($0 ~ /[Yy]es/) guest = "yes"; next }
    /^[[:space:]]*read only[[:space:]]*=/ { if ($0 ~ /[Nn]o/) rw = "yes"; next }
    /^[[:space:]]*force user[[:space:]]*=/ { if ($0 ~ /root/) root = " as root"; next }
    /^[[:space:]]*path[[:space:]]*=/ { path = $0; sub(/^[^=]*=[[:space:]]*/, "", path); next }
    /^[[:space:]]*$/ { emit() }
    END { emit() }' 2>/dev/null || true)
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
      53317) if [ -n "$(declared_why 53317)" ]; then
               note_wide "53317" "LocalSend" "declared: $(declared_why 53317)"
             else
               add MEDIUM "a peer-transfer port answers the whole network" "ufw: --dport $port with no source (LocalSend)" "keep it if the operator uses it deliberately — write it in config/declared-ports.txt"
             fi ;;
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
  # No sshd -T (no root): read the BASE FILE **and the drop-ins**, which is where the answer
  # actually lives. The last word wins, as it does for sshd.
  PA_EFF="$(printf '%s\n%s\n' "$SSHD_CONF" "$SSHD_DROPS" | sed -nE 's/^[[:space:]]*PasswordAuthentication[[:space:]]+([a-zA-Z]+).*/\1/ip' | tail -1)"
  case "$PA_EFF" in
    no|NO)   : ;;   # keys only — nothing to report
    yes|YES) add HIGH "sshd accepts PASSWORDS" "PasswordAuthentication yes (base file or a drop-in)" "keys only: a drop-in with 'PasswordAuthentication no' (bin/ward/harden.sh plan)" ;;
    *) case "$SSHD_CONF" in
         *'#PasswordAuthentication yes'*) add MEDIUM "the sshd password policy is at its default" "no drop-in sets PasswordAuthentication; the compiled default applies" "run the audit with root for the effective value: sudo bin/ward/security-audit.sh" ;;
       esac ;;
  esac
fi

# ── 4 · the tunnels: what we publish to the world ─────────────────────────────
if [ -d "$CFG_DIR" ]; then
  for f in "$CFG_DIR"/config-*.yml; do
    [ -r "$f" ] || continue
    hn="$(sed -nE 's/^[[:space:]]*-[[:space:]]*hostname:[[:space:]]*(.*)/\1/p' "$f" | head -1)"
    svc="$(sed -nE 's#^[[:space:]]*service:[[:space:]]*(http[s]?://.*|ssh://.*)#\1#p' "$f" | head -1)"
    [ -n "$hn" ] || continue
    # A tunnel that dials ssh is not a web surface with a login to check: it is a door
    # into a shell, published from this host, and no probe below can judge it.
    case "$svc" in
      ssh://*)
        ssh_all="$(sed -nE 's#^[[:space:]]*service:[[:space:]]*ssh://(.*)$#\1#p' "$f" | tr '\n' ' ')"
        add HIGH "a PUBLIC tunnel publishes an ssh door" "$hn → ssh://${ssh_all% }" "take the ingress out: ssh is reached by key and by the tailnet, never published from another machine's tunnel"
        continue ;;
    esac
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
[ "$have_any" = 0 ] && { [ -x "$SCRIPT_DIR/host-watch.sh" ] && "$SCRIPT_DIR/host-watch.sh" status >/dev/null 2>&1 && have_any=1; }
# A hand cannot run fail2ban, crowdsec, lynis or aide — no root, no systemd, no log
# syslog. The lawful question is whether ANYTHING looks at the host on a cycle and
# leaves a record, so the house watcher counts, and is named when it is the one.
WATCHER_NOTE="no fail2ban/crowdsec/lynis/aide/osquery/falco installed"
if [ "$have_any" = 1 ] && [ -x "$SCRIPT_DIR/host-watch.sh" ] && "$SCRIPT_DIR/host-watch.sh" status >/dev/null 2>&1; then
  WATCHER_NOTE="bin/ward/host-watch.sh — the house watcher, heartbeat fresh"
fi
[ "$have_any" = 0 ] && add HIGH "nothing watches this host" "$WATCHER_NOTE" "plan 81 S2-S3: a ban for brute force, and a file-integrity baseline; the hand's own watcher: bin/ward/host-watch.sh run"

# ── the report ────────────────────────────────────────────────────────────────
if [ "$JSON" = 1 ]; then
  printf '{"findings":%s,"critical":%s,"high":%s}\n' "$findings" "$crit" "$high"
else
  if [ "$QUIET" = 1 ] && [ "$crit" = 0 ] && [ "$high" = 0 ]; then
    none
    notes_out
  elif [ "$findings" = 0 ]; then
    none
    notes_out
  else
    printf 'security-audit[%s]{severity,what,detail,remedy}:\n' "$findings"
    printf '%b' "$F_ROWS" | grep -v '"NONE_LINE"'
    printf 'security-audit: %s finding(s) — %s critical, %s high\n' "$findings" "$crit" "$high"
    notes_out
  fi
fi

[ "$crit" -gt 0 ] || [ "$high" -gt 0 ] && exit 1
exit 0
