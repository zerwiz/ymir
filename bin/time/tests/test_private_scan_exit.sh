#!/usr/bin/env bash
# test_private_scan_exit.sh — a finding is work in the queue, not a broken job; a scan that cannot run still says so.
#
# WHY (2026-11-20). The sweep is scheduled twice a day and exited 1 whenever it found anything, so every finding rang
# the operator's phone as a cron FAILURE — sixty-three of them, all his own domain names written into the public tree
# — twice a day, for as long as nobody had time to triage. The findings are already written where work lives: the
# queue and the brief. A scan that RAN now exits 0; a scan that could not run exits 2 and names the fault.
#
# Everything runs against a fixture: a throwaway repository whose engine, notifier and spawner are stubs, so no
# errand is ever raised and the real tree is never swept.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/time/nornir-job-private-scan.sh"
pass=0; fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; fail=$((fail+1)); }
rc_is() { local want=$1 got=$2 label=$3; [ "$got" = "$want" ] && ok "$label (rc=$got)" || bad "$label (wanted rc=$want, got $got)"; }
has() { local needle=$1 file=$2 label=$3; grep -q -- "$needle" "$file" 2>/dev/null && ok "$label" || bad "$label" "no \"$needle\" in $file"; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
REPO="$T/repo"; HOME_DIR="$T/home"
mkdir -p "$REPO/bin/gates" "$REPO/bin/vault" "$REPO/bin/forge" "$REPO/bin/notify" "$REPO/bin/agents" \
         "$HOME_DIR/hodd" "$HOME_DIR/state"
git init -q "$REPO"
printf 'stub\n' >"$REPO/stub.txt"
git -C "$REPO" add stub.txt
git -C "$REPO" -c user.email=t@example.org -c user.name=t commit -qm stub

# the home resolver, as the real one is asked
cat >"$REPO/bin/vault/hoard-lib.sh" <<'LIB'
ymir_home_root() { printf '%s' "$YMIR_HOME"; }
LIB
# the warden lib: this fixture machine may act
cat >"$REPO/bin/forge/warden-lib.sh" <<'LIB'
warden_begin() { return 0; }
warden_require_door() { return 0; }
LIB
# the ONE engine, stubbed to report exactly one finding
cat >"$REPO/bin/gates/agnostic-audit.sh" <<'AUD'
#!/usr/bin/env bash
printf 'leaked-in-the-tree.txt:1\n'
printf '  "x","1","1","27","0"\n'
exit 1
AUD
chmod +x "$REPO/bin/gates/agnostic-audit.sh"
printf '#!/usr/bin/env bash\nexit 0\n' >"$REPO/bin/notify/send.sh"; chmod +x "$REPO/bin/notify/send.sh"
# the spawner is a stub on purpose: a test must never raise an errand
cat >"$REPO/bin/agents/einherjar-spawn.sh" <<'SPAWN'
#!/usr/bin/env bash
printf 'would-spawn %s\n' "$*" >&2
exit 0
SPAWN
chmod +x "$REPO/bin/agents/einherjar-spawn.sh"

run() { YMIR_REPO="$REPO" YMIR_HOME="$HOME_DIR" timeout 120 bash "$DOOR" "$@" 2>&1; }

# ── 1 · scheduled, with a finding: work is queued, and the job is not a failure ──
out="$(run)"; rc=$?
rc_is 0 "$rc" "a scheduled scan with findings exits 0"
case "$out" in *"1 finding(s)"*) ok "it prints the count" ;; *) bad "it prints the count" "$out" ;; esac
has "1 finding(s)" "$HOME_DIR/state/private-scan/queue.md" "the queue carries the finding"
has "twice-daily sweep found 1 thing" "$HOME_DIR/hodd/data/private-scan/brief.md" "the brief is written for the errand"

# ── 2 · the same finding, for a caller that gates ──
out="$(run --fail-on-findings)"; rc=$?
rc_is 1 "$rc" "--fail-on-findings turns a finding into exit 1"

# ── 3 · --report says the same thing and is not a failure either ──
out="$(run --report)"; rc=$?
rc_is 0 "$rc" "--report with findings exits 0"

# ── 4 · a scan that cannot run is still non-zero, and names the fault ──
out="$(YMIR_REPO="$REPO" YMIR_HOME="" timeout 60 bash "$DOOR" 2>&1)"; rc=$?
rc_is 2 "$rc" "no home to write the queue to"
case "$out" in *"no Ymir home resolves"*) ok "it names the fault" ;; *) bad "it names the fault" "$out" ;; esac

# ── 5 · a missing repository is also a scan that cannot run ──
out="$(YMIR_REPO="$T/nowhere" YMIR_HOME="$HOME_DIR" timeout 60 bash "$DOOR" 2>&1)"; rc=$?
rc_is 2 "$rc" "no repository at the named path"

# ── 6 · clean is still clean, and still silent about failure ──
cat >"$REPO/bin/gates/agnostic-audit.sh" <<'AUD'
#!/usr/bin/env bash
printf ''
exit 0
AUD
chmod +x "$REPO/bin/gates/agnostic-audit.sh"
out="$(run)"; rc=$?
rc_is 0 "$rc" "a clean scan exits 0"
case "$out" in *clean*) ok "it says clean" ;; *) bad "it says clean" "$out" ;; esac

printf 'private-scan-exit: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
