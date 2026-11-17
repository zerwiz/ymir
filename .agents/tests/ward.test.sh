#!/usr/bin/env bash
# ward.test.sh — the warden's eyes, hands and report, proved against FIXTURES.
#
# Every source the audit reads is injectable (--fixtures), so the cases are recorded
# machine states rather than this machine's mood: a clean box must pass, an open door
# must fail, and the mend that could lock the operator out must REFUSE.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUDIT="$ROOT/bin/ward/security-audit.sh"
HARDEN="$ROOT/bin/ward/harden.sh"
VERDR="$ROOT/bin/ward/verdr.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── fixtures: a CLEAN box ─────────────────────────────────────────────────────
CLEAN="$TMP/clean"; mkdir -p "$CLEAN"
cat >"$CLEAN/ss.out" <<'EOF'
State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
LISTEN 0      4096       127.0.0.1:4602       0.0.0.0:*     users:(("python3",pid=1,fd=6))
EOF
cat >"$CLEAN/ufw.out" <<'EOF'
-A ufw-user-input -p tcp --dport 22 -s 192.0.2.0/24 -j ACCEPT
-A ufw-user-input -i tailscale0 -p tcp --dport 22 -j ACCEPT
EOF
printf 'DEFAULT_INPUT_POLICY="DROP"\n' >"$CLEAN/ufw-default.out"
printf 'passwordauthentication no\npermitrootlogin prohibit-password\n' >"$CLEAN/sshd-T.out"
printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIexamplekey heimdall\n' >"$CLEAN/authz.out"
printf 'lynis\n' >"$CLEAN/watchers.out"
printf '\n' >"$CLEAN/docker.out"

out="$(YMIR_HOME="$TMP/home" bash "$AUDIT" check --fixtures "$CLEAN" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "a clean box passes the audit" || bad "clean box rc=$rc: $out"
printf '%s' "$out" | grep -q '"none"' && ok "and it says so plainly" || bad "clean box output: $out"

# ── fixtures: an OPEN box ─────────────────────────────────────────────────────
OPEN="$TMP/open"; mkdir -p "$OPEN/cloudflared"
cat >"$OPEN/ss.out" <<'EOF'
State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
LISTEN 0      4096         0.0.0.0:3889       0.0.0.0:*     users:(("bun",pid=2,fd=7))
EOF
cat >"$OPEN/ufw.out" <<'EOF'
-A ufw-user-input -p tcp --dport 22 -j ACCEPT
-A ufw-user-input -p tcp --dport 3889 -j ACCEPT
EOF
printf 'DEFAULT_INPUT_POLICY="DROP"\n' >"$OPEN/ufw-default.out"
printf 'passwordauthentication yes\npermitrootlogin yes\n' >"$OPEN/sshd-T.out"
printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIexamplekey heimdall\n' >"$OPEN/authz.out"
cat >"$OPEN/cloudflared/config-random.yml" <<'EOF'
tunnel: x
ingress:
  - hostname: random.example.org
    service: http://127.0.0.1:3891
  - service: http_status:404
EOF

printf '200\n' >"$OPEN/probe-random.example.org.out"      # a recorded public answer: no auth
out="$(YMIR_HOME="$TMP/home2" bash "$AUDIT" check --fixtures "$OPEN" 2>&1)"; rc=$?
[ "$rc" = 1 ] && ok "an open box FAILS the audit (exit 1)" || bad "open box rc=$rc"
printf '%s' "$out" | grep -q '"CRITICAL"' && ok "…with a CRITICAL severity in the report" || bad "no CRITICAL: $out"
printf '%s' "$out" | grep -q 'sshd accepts PASSWORDS' && ok "…and the password policy is named" || bad "password finding missing"
printf '%s' "$out" | grep -q 'dport 22 with no source' && ok "…and the world's ssh door is named" || bad "ufw finding missing"
printf '%s' "$out" | grep -q 'control plane' && ok "…and the wide control plane is named" || bad "wide bind missing"

# a wide bind is reported, a loopback bind is not
printf '%s' "$out" | grep -q '0.0.0.0:4602' && bad "a loopback bind was reported" || ok "loopback binds are not findings"

# ── the doors that hand out their own key (2026-11-16) ────────────────────────
# A wide bind is a location; these two kinds of door say "come in" themselves, and
# nothing asked them until the heart's second audit. All three sources are fixtures,
# so the judgement is proved without knocking on a live door.
DOORS="$TMP/doors"; mkdir -p "$DOORS/cloudflared"
cat >"$DOORS/ss.out" <<'EOF'
State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
LISTEN 0      2048         0.0.0.0:8319       0.0.0.0:*     users:(("mcp-proxy",pid=3,fd=9))
LISTEN 0      511          0.0.0.0:8321       0.0.0.0:*     users:(("node",pid=4,fd=21))
LISTEN 0      50           0.0.0.0:445        0.0.0.0:*
EOF
printf 'DEFAULT_INPUT_POLICY="DROP"\n' >"$DOORS/ufw-default.out"
printf 'passwordauthentication no\npermitrootlogin prohibit-password\n' >"$DOORS/sshd-T.out"
printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIexamplekey heimdall\n' >"$DOORS/authz.out"
printf 'lynis\n' >"$DOORS/watchers.out"
printf '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","serverInfo":{"name":"snotra","version":"0.1.0"}}}\n' >"$DOORS/mcp-8321.out"
printf '{"error":"a token is required"}\n' >"$DOORS/mcp-8319.out"      # gated: not a finding
cat >"$DOORS/smb.out" <<'EOF'
[global]
	map to guest = Bad User

[Models]
	guest ok = Yes
	read only = No
	force user = root
	path = /srv/Models

[Reference]
	guest ok = No
	path = /srv/Reference
EOF
cat >"$DOORS/cloudflared/config-ssh-lan.yml" <<'EOF'
tunnel: x
ingress:
  - hostname: laptop.example.org
    service: ssh://192.0.2.10:22
  - service: http_status:404
EOF

dout="$(YMIR_HOME="$TMP/home5" bash "$AUDIT" check --fixtures "$DOORS" 2>&1)"; drc=$?
[ "$drc" = 1 ] && ok "a box whose doors hand out their own key FAILS" || bad "doors rc=$drc"
printf '%s' "$dout" | grep -q 'an MCP answers without a credential.*8319' && bad "a gated MCP was reported" || ok "a gated MCP is not a finding"
printf '%s' "$dout" | grep -q 'an MCP answers without a credential' && ok "…an unauthenticated MCP is named" || bad "unauthenticated MCP missing: $dout"
printf '%s' "$dout" | grep -q 'snotra' && ok "…with the server's own name" || bad "MCP server name missing"
printf '%s' "$dout" | grep -q 'an SMB share is open to guests and writable' && ok "…a guest-writable SMB share is a HIGH" || bad "SMB finding missing"
printf '%s' "$dout" | grep -q 'as root' && ok "…and 'force user = root' is named" || bad "force user not named"
printf '%s' "$dout" | grep -qi '\[Reference\]' && bad "a keyed share was reported" || ok "a keyed SMB share is not a finding"
printf '%s' "$dout" | grep -q 'publishes an ssh door' && ok "…a tunnel that dials ssh is named" || bad "ssh tunnel finding missing"
printf '%s' "$dout" | grep -q 'laptop.example.org' && ok "…with the hostname it publishes" || bad "ssh tunnel hostname missing"

# ── the mends are written out and NOT applied ─────────────────────────────────
out="$(bash "$HARDEN" plan 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "harden plan prints without changing anything" || bad "harden plan rc=$rc"
printf '%s' "$out" | grep -q 'revert' && ok "…and every mend carries its revert line" || bad "no revert line: $out"
printf '%s' "$out" | grep -q 'PasswordAuthentication' && ok "…and the sshd mend is spelled out" || bad "sshd mend missing"

# the mend that can lock the operator out REFUSES without the loud flag
bash "$HARDEN" apply --ufw >/dev/null 2>&1; rc=$?
[ "$rc" = 3 ] && ok "narrowing ufw is REFUSED without the explicit flag" || bad "ufw mend rc=$rc (want 3)"

# chmod-only mend works without root
printf 'secret\n' >"$TMP/home3-secret" 2>/dev/null || true
mkdir -p "$TMP/home3/hodd/secrets"; printf 'x\n' >"$TMP/home3/hodd/secrets/platform.env"; chmod 644 "$TMP/home3/hodd/secrets/platform.env"
YMIR_HOME="$TMP/home3" bash "$HARDEN" apply --ssh-keys-perm >/dev/null 2>&1
[ "$(stat -c '%a' "$TMP/home3/hodd/secrets/platform.env")" = "600" ] && ok "the secrets mend sets 600" || bad "secrets mend did not chmod"

# ── the report is written where records live ──────────────────────────────────
YMIR_HOME="$TMP/home4" bash "$VERDR" report --no-alert >"$TMP/ward-verdr.out" 2>&1
f="$(ls -1 "$TMP/home4/hodd/memory/ward"/*.md 2>/dev/null | head -1)"
[ -n "$f" ] && ok "Vörðr writes a dated report into the home" || bad "no report written: $(cat "$TMP/ward-verdr.out")"
[ -n "$f" ] && grep -q 'the warden.s report' "$f" && ok "…and the report is the warden's" || bad "report content: $(head -3 "$f" 2>/dev/null)"
[ -n "$f" ] && grep -q 'The mends' "$f" && ok "…and it carries the mends, unapplied" || bad "mends missing from the report"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
