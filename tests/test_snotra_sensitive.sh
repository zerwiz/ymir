#!/usr/bin/env bash
# Synthetic tests for the sensitive gate, provenance and evidence bundle. No real data.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export YMIR_HOME="$T/home"; mkdir -p "$YMIR_HOME/hodd/identity" "$YMIR_HOME/hodd/life/meetings"
pass=0; fail=0
ok(){ pass=$((pass+1)); printf 'ok\t%s\n' "$1"; }
bad(){ fail=$((fail+1)); printf 'FAIL\t%s\n' "$1"; }

mk(){ mkdir -p "$T/$1"; printf 'synthetic transcript\n' > "$T/$1/transcript.md"; printf '{"meeting":{"title":"Synthetic"}}\n' > "$T/$1/record.json"; }

# held, restricted
mk held
cat > "$T/held/classification.yaml" <<'YML'
classification: restricted-patent
hold: true
YML
bash "$ROOT/bin/time/snotra/snotra-provenance.sh" seal "$T/held" >/dev/null
if bash "$ROOT/bin/gates/guards/sensitive-gate.sh" "$T/held" --surface trello >/dev/null 2>&1; then bad "held trello allowed"; else ok "held trello refused"; fi
if bash "$ROOT/bin/gates/guards/sensitive-gate.sh" "$T/held" --surface private >/dev/null 2>&1; then ok "held private allowed"; else bad "held private refused"; fi
# unheld, no classification
mk open
bash "$ROOT/bin/time/snotra/snotra-provenance.sh" seal "$T/open" >/dev/null
if bash "$ROOT/bin/gates/guards/sensitive-gate.sh" "$T/open" --surface trello >/dev/null 2>&1; then ok "open trello allowed"; else bad "open trello refused"; fi
# tamper
echo changed >> "$T/open/transcript.md"
if bash "$ROOT/bin/time/snotra/snotra-provenance.sh" verify "$T/open" >/dev/null 2>&1; then bad "tamper passed verify"; else ok "tamper refused"; fi
# evidence bundle
bash "$ROOT/bin/time/snotra/snotra-evidence.sh" timestamp "$T/held" >/dev/null
bash "$ROOT/bin/time/snotra/snotra-evidence.sh" certify "$T/held" --reviewer "Test Reviewer" >/dev/null
[ -f "$T/held/timestamp/timestamp.json" ] && ok "timestamp written" || bad "timestamp missing"
[ -f "$T/held/certified-copy.md" ] && ok "certified copy written" || bad "certified copy missing"
printf 'test_snotra_sensitive: %d pass, %d fail\n' "$pass" "$fail"
[ "$fail" = 0 ]
