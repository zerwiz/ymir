#!/usr/bin/env bash
# test_registry_answers.sh — the registry answers in one read, and the two checks that keep it honest BIT (plan 312).
#
# The three faults this proves, each in a throwaway home under a temporary directory:
#   two rows on one port                        → red, and the finding names the port and BOTH rows
#   a row whose `script` does not exist         → red, and the finding names the row and the path
#   a listening door that no row names          → red, and the finding names the address and the port
#
# Plus the read the plan owes: `--answer <id>` says how a service is raised, what file runs, what port it owns, where it
# lives, which runbook to open and whether a stop is an incident — and a registry that fits its shape comes back green.
#
# NOTHING HERE TOUCHES THE LIVE REGISTRY. Every case runs with YMIR_HOME pointed at a temporary home. Two host reads
# are stubbed for the fixture, and named as stubs: `docker` (this test is about the registry's own checks, not about the
# containers on the host) and `ss` (the same for the host's sockets). The one case that must SEE a socket — the unnamed
# door — runs with the real `ss`, so that check is proved against a real bound socket, not a fiction.
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
AUDIT="$ROOT/bin/records/registry-audit.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
HOSTNAME_SHORT="$(hostname -s)"
fail=0
ok()   { printf 'ok   %s\n' "$1"; }
bad()  { printf 'FAIL %s\n' "$1"; fail=1; }
has()  { case "$2" in *"$1"*) return 0;; *) return 1;; esac; }

# the fixture's own PATH: a docker that sees nothing and an ss that reports no sockets, and the real tools it needs
mkdir -p "$T/fixture-bin" "$T/docker-only"
cat > "$T/fixture-bin/docker" <<'SH'
#!/usr/bin/env bash
# a fixture docker: this test is about the registry's own checks, not about the host's containers
exit 0
SH
cat > "$T/docker-only/docker" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$T/fixture-bin/ss" <<'SH'
#!/usr/bin/env bash
# a fixture ss: the host's own listening doors are not this fixture's subject; the socket case below uses the real one
exit 0
SH
chmod +x "$T/fixture-bin/docker" "$T/fixture-bin/ss" "$T/docker-only/docker"
REALPATH_BASE="/usr/local/bin:/usr/bin:/bin"
FIXPATH="$T/fixture-bin:$REALPATH_BASE"
SOCKPATH="$T/docker-only:$REALPATH_BASE"

# one kit, shared by the fixtures: a real script, a real dir, a real runbook
mkdir -p "$T/kit"
: > "$T/kit/alpha.sh"
: > "$T/kit/compose.yml"
: > "$T/alpha-runbook.md"
: > "$T/beta-runbook.md"

# home <dir> — a fixture home carrying only what the audit reads
home() {
  mkdir -p "$1/hodd/identity"
  cat > "$1/hodd/identity/services.yaml"
}

header() {
  cat <<YAML
version: 2
schema:
  version: 1
  shape: config/services.schema.json
  checked_by: bin/records/registry-audit.sh
  row: [id, name, host, unit, script, ports, dir, runbook, criticality, budget]
services:
YAML
}

# --------------------------------------------------------------------------------------------------------------------
# CASE 1 · a registry that fits its shape is GREEN
H1="$T/home-green"
home "$H1" <<YAML
$(header)
- id: alpha
  name: Alpha — the first door
  host: $HOSTNAME_SHORT
  unit: alpha.service
  script: $T/kit/alpha.sh
  ports: [4301]
  dir: $T/kit
  runbook: $T/alpha-runbook.md
  criticality: always
  budget: {measured_mb: 10, memory_ceiling_mb: 64, residency: always resident}
- id: beta
  name: Beta — the second door
  host: $HOSTNAME_SHORT
  compose: $T/kit/compose.yml
  ports: [4302]
  dir: $T/kit
  runbook: $T/beta-runbook.md
  criticality: wanted
  budget: 128Mi
YAML
out="$(YMIR_HOME="$H1" PATH="$FIXPATH" bash "$AUDIT" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "a registry that fits its shape is green (exit 0)" || bad "clean registry exited $rc: $out"
has "RESULT   green" "$out" && ok "the report says green" || bad "no green line: $out"

# --------------------------------------------------------------------------------------------------------------------
# CASE 2 · TWO ROWS ON ONE PORT IS A FAULT, named by port and by both rows
H2="$T/home-port"
home "$H2" <<YAML
$(header)
- id: alpha
  name: Alpha — the first door
  host: somewhere-else
  unit: alpha.service
  script: /srv/alpha.sh
  ports: [4321]
  dir: /srv
  runbook: hodd/docs/runbooks/gimle.md
  criticality: always
  budget: 64Mi
- id: beta
  name: Beta — the second door
  host: somewhere-else
  unit: beta.service
  script: /srv/beta.sh
  ports: [4321]
  dir: /srv
  runbook: hodd/docs/runbooks/gimle.md
  criticality: wanted
  budget: 64Mi
YAML
out="$(YMIR_HOME="$H2" PATH="$FIXPATH" bash "$AUDIT" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && ok "two rows on one port is red (exit 1)" || bad "duplicate port exited $rc, not 1: $out"
has "port 4321 is owned by 2 rows: alpha, beta" "$out" && ok "the finding names the port and both rows" \
  || bad "the duplicate-port finding does not name the rows: $out"

# --------------------------------------------------------------------------------------------------------------------
# CASE 3 · A ROW WHOSE `script` DOES NOT EXIST IS A FAULT, named by row and by path
H3="$T/home-missing-script"
home "$H3" <<YAML
$(header)
- id: alpha
  name: Alpha — the first door
  host: $HOSTNAME_SHORT
  unit: alpha.service
  script: $T/kit/alpha.sh
  ports: [4301]
  dir: $T/kit
  runbook: $T/alpha-runbook.md
  criticality: always
  budget: 64Mi
- id: share-door
  name: The share door — a symlink into a tree that is gone
  host: $HOSTNAME_SHORT
  unit: gimle-share.service
  script: $T/kit/gone.sh
  ports: [4303]
  dir: $T/kit
  runbook: $T/alpha-runbook.md
  criticality: always
  budget: 64Mi
YAML
out="$(YMIR_HOME="$H3" PATH="$FIXPATH" bash "$AUDIT" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && ok "a missing script is red (exit 1)" || bad "missing script exited $rc, not 1: $out"
has "share-door" "$out" && has "\`script: $T/kit/gone.sh\` does not exist" "$out" \
  && ok "the finding names the row and the path" || bad "the missing-path finding is not named: $out"

# --------------------------------------------------------------------------------------------------------------------
# CASE 3b · a SYMLINK whose target is gone is named as that, because that is how the share door died unseen
ln -s "$T/kit/never-there.sh" "$T/kit/links-to-a-gone-tree.sh"
H3b="$T/home-broken-link"
home "$H3b" <<YAML
$(header)
- id: share-door
  name: The share door
  host: $HOSTNAME_SHORT
  unit: gimle-share.service
  script: $T/kit/links-to-a-gone-tree.sh
  ports: [4303]
  dir: $T/kit
  runbook: $T/alpha-runbook.md
  criticality: always
  budget: 64Mi
YAML
out="$(YMIR_HOME="$H3b" PATH="$FIXPATH" bash "$AUDIT" 2>&1)"
has "is a symlink into a tree that is GONE" "$out" && has "$T/kit/never-there.sh" "$out" \
  && ok "a broken symlink is named, with the target it points at" || bad "the broken symlink is not named: $out"

# --------------------------------------------------------------------------------------------------------------------
# CASE 4 · A ROW MISSING A FIELD THE SHAPE REQUIRES IS A FINDING, never a pass (an unset criticality is not an answer)
H4="$T/home-no-criticality"
home "$H4" <<YAML
$(header)
- id: alpha
  name: Alpha — the first door
  host: $HOSTNAME_SHORT
  unit: alpha.service
  script: $T/kit/alpha.sh
  ports: [4301]
  dir: $T/kit
  runbook: $T/alpha-runbook.md
  budget: 64Mi
YAML
out="$(YMIR_HOME="$H4" PATH="$FIXPATH" bash "$AUDIT" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && has "alpha" "$out" && has "no \`criticality\`" "$out" \
  && ok "an unset criticality is a finding, not a pass" || bad "unset criticality not reported: $out"

# --------------------------------------------------------------------------------------------------------------------
# CASE 5 · A LISTENING DOOR THAT NO ROW NAMES IS A FAULT
# A socket is opened on a free port on every interface, so the check has something real to find. If it cannot be bound,
# the case reports a SKIP rather than a false pass.
PORT="$(python3 - <<'PY'
import socket
s = socket.socket(); s.bind(("0.0.0.0", 0)); print(s.getsockname()[1]); s.close()
PY
)"
python3 - "$PORT" <<'PY' &
import socket, sys, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", int(sys.argv[1]))); s.listen(1)
time.sleep(30)
PY
BINDER=$!
sleep 1
H5="$T/home-socket"
home "$H5" <<YAML
$(header)
- id: alpha
  name: Alpha — the first door
  host: $HOSTNAME_SHORT
  unit: alpha.service
  script: $T/kit/alpha.sh
  ports: [4301]
  dir: $T/kit
  runbook: $T/alpha-runbook.md
  criticality: always
  budget: 64Mi
YAML
out="$(YMIR_HOME="$H5" PATH="$SOCKPATH" bash "$AUDIT" 2>&1)"
kill "$BINDER" 2>/dev/null; wait "$BINDER" 2>/dev/null
has ":$PORT" "$out" && has "no row names" "$out" \
  && ok "a listening door that no row names is a finding, named by address and port" \
  || bad "the unnamed socket $PORT was not reported: $out"

# --------------------------------------------------------------------------------------------------------------------
# CASE 6 · THE ONE READ: --answer says it all for one named service, in one command
out="$(YMIR_HOME="$H1" PATH="$FIXPATH" bash "$AUDIT" --answer alpha 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "--answer exits 0 for a row that exists" || bad "--answer exited $rc: $out"
for want in "raises     unit alpha.service" "runs       $T/kit/alpha.sh  (exists)" "port       4301" \
            "dir        $T/kit  (exists)" "runbook    $T/alpha-runbook.md  (exists)" \
            "stop       a stop is an INCIDENT" "budget     64 MiB ceiling (measured 10 MiB)"; do
  has "$want" "$out" && ok "the one read answers: ${want%%  *}" || bad "the one read does not answer '$want': $out"
done
out="$(YMIR_HOME="$H1" PATH="$FIXPATH" bash "$AUDIT" --answer nosuch 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && has "no row with id 'nosuch'" "$out" && ok "an unknown id is refused, with the ids it does have" \
  || bad "unknown id was not refused ($rc): $out"

# --------------------------------------------------------------------------------------------------------------------
# CASE 7 · --quiet is one line and inherits the verdict
out="$(YMIR_HOME="$H1" PATH="$FIXPATH" bash "$AUDIT" --quiet 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ] && ok "--quiet is one line, and green is 0" \
  || bad "--quiet was not one line or not 0 ($rc): $out"
out="$(YMIR_HOME="$H2" PATH="$FIXPATH" bash "$AUDIT" --quiet 2>&1)"; rc=$?
[ "$rc" -eq 1 ] && has "port-twice" "$out" && ok "--quiet is one line, and red is 1" || bad "--quiet red was not 1: $out"

printf '\n%s\n' "$([ "$fail" -eq 0 ] && echo 'all registry-answers cases passed' || echo 'a registry-answers case FAILED')"
exit "$fail"
