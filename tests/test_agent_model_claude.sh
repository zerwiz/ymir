#!/usr/bin/env bash
# test_agent_model_claude.sh — a Claude row is judged by Claude's allow-list, not pi's catalogue
# (2026-11-21).
#
# What happened: the judge's row (RULES/08) is `forseti: { model: opus, harness: claude }`.
# bin/model/agent-model.sh validated every row against pi's catalogue, which never lists a Claude
# model, so it printed "FINDING — overlay names opus for forseti, which THIS seat does not list"
# and resolved the fleet default (a pi model). The review spine then refused to seat Claude on a
# provider/model token, and no judge was seated for any PR.
#
# What this proves, on a throwaway tree, home and catalogue (no live door is touched):
#
#   · a row { model: opus, harness: claude } resolves to claude-opus-5-5 (the CLI's name);
#   · a Claude row naming a pi model is REFUSED by name (exit 3), never a fall-through;
#   · a Claude row with no model takes the allow-list's Claude default;
#   · YMIR_<AGENT>_MODEL naming a pi model for a Claude row is refused by name;
#   · --harness claude judges a row against Claude even when the row names no harness;
#   · a pi row still validates against the catalogue: listed resolves, unlisted falls through;
#   · --json carries the harness.
#
# Added after the judge's rework (PR #865): a pi caller of a Claude row's agent says so.
#   · --harness pi on a Claude row is judged by pi's catalogue, never handed a Claude name;
#   · --harness pi --tier strong on a Claude row resolves a pi model;
#   · --tier on a Claude row WITHOUT --harness is refused by name, never a silent drop;
#   · the pi callers of forseti (vidarr, garmr-bite, garmr/escalate, review-seat) pass --harness pi.
#
# Exit: 0 every case held · 1 a case failed.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-agent-model-claude.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

T="$TMP/tree"
mkdir -p "$T/bin/model" "$T/bin/seat" "$T/bin/vault" "$T/src/ymir_runtime" "$T/RULES" "$T/.pi"
cp "$ROOT/bin/model/agent-model.sh" "$ROOT/bin/model/model-allow.sh" "$T/bin/model/"
cp "$ROOT/bin/seat/claude-seat.sh" "$T/bin/seat/"
cp "$ROOT/bin/vault/hoard-lib.sh" "$T/bin/vault/"
cp "$ROOT/src/ymir_runtime/allow.py" "$ROOT/src/ymir_runtime/claude_seat.py" "$T/src/ymir_runtime/"
# A catalogue shaped like bin/model/catalog.sh: pi lists these and no Claude model.
cat >"$T/bin/model/catalog.sh" <<'SH'
#!/usr/bin/env bash
printf 'catalog[3]{provider,model,context,max_out}:\n'
printf '  "opencode-go","deepseek-v4.1-flash","1M","64K"\n'
printf '  "llama-swap","qwen-local","256K","32K"\n'
printf '  "opencode-go","deepseek-v4-pro","1M","64K"\n'
SH
chmod +x "$T"/bin/model/*.sh "$T"/bin/seat/*.sh

H="$TMP/home"; CFG="$H/config"
mkdir -p "$CFG" "$H/hodd" "$H/state"
cat >"$CFG/models-allowed.yaml" <<'YAML'
version: 1
allow:
  - opencode-go/deepseek-v4.1-flash
  - llama-swap/*
  - claude/claude-opus-5-5
  - claude/claude-sonnet-5-5
defaults:
  claude: claude-sonnet-5-5
grants: []
YAML
cat >"$CFG/agents.yaml" <<'YAML'
default_model: opencode-go/deepseek-v4.1-flash
agents:
  forseti: { model: opus, harness: claude }
  wrongjudge: { model: opencode-go/deepseek-v4.1-flash, harness: claude }
  barejudge: { harness: claude }
  smith: { model: llama-swap/qwen-local }
  ghost: { model: nowhere/unlisted-model }
  plain: { model: opus }
YAML

export YMIR_HOME="$H" YMIR_SETTINGS_DIR="$CFG" YMIR_STATE_DIR="$H/state"
unset YMIR_FORSETI_MODEL YMIR_SMITH_MODEL 2>/dev/null || true
AM="$T/bin/model/agent-model.sh"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$(printf '%s' "$2" | head -3 | tr '\n' ' ')"; }

out="$(bash "$AM" forseti --plain 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = claude-opus-5-5 ] \
  && ok "opus on claude resolves to claude-opus-5-5" || bad "opus on claude did not resolve (rc=$rc)" "$out"

out="$(bash "$AM" wrongjudge --plain 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q "REFUSED.*opencode-go/deepseek-v4.1-flash.*harness 'claude'" \
  && ok "a claude row with a pi model is refused by name" || bad "a claude row with a pi model was not refused (rc=$rc)" "$out"

out="$(bash "$AM" barejudge --plain 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = claude-sonnet-5-5 ] \
  && ok "a claude row with no model takes the allow-list's claude default" || bad "no claude default (rc=$rc)" "$out"

out="$(YMIR_FORSETI_MODEL=opencode-go/deepseek-v4.1-flash bash "$AM" forseti --plain 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'YMIR_FORSETI_MODEL' \
  && ok "a pi model in YMIR_FORSETI_MODEL is refused for a claude row" || bad "env override was not refused (rc=$rc)" "$out"

out="$(YMIR_FORSETI_MODEL=claude-opus-5-5 bash "$AM" forseti --plain 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = claude-opus-5-5 ] \
  && ok "YMIR_FORSETI_MODEL=claude-opus-5-5 is honoured" || bad "claude env override failed (rc=$rc)" "$out"

out="$(bash "$AM" plain --harness claude --plain 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = claude-opus-5-5 ] \
  && ok "--harness claude judges a harness-less row against claude" || bad "--harness claude failed (rc=$rc)" "$out"

out="$(bash "$AM" smith --plain 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = llama-swap/qwen-local ] \
  && ok "a pi row listed in the catalogue resolves" || bad "a listed pi row did not resolve (rc=$rc)" "$out"

out="$(bash "$AM" ghost --plain 2>"$TMP/ghost.err")"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = opencode-go/deepseek-v4.1-flash ] && grep -q 'FINDING' "$TMP/ghost.err" \
  && ok "an unlisted pi row is a finding and falls through to the default" || bad "pi catalogue validation changed (rc=$rc)" "$out $(cat "$TMP/ghost.err")"

out="$(bash "$AM" plain --plain 2>"$TMP/plain.err")"; rc=$?
[ "$out" = opencode-go/deepseek-v4.1-flash ] && grep -q 'FINDING' "$TMP/plain.err" \
  && ok "'opus' on a pi row is still judged by pi's catalogue" || bad "a pi row skipped the catalogue (rc=$rc)" "$out"

out="$(bash "$AM" forseti --harness pi --plain 2>"$TMP/hpi.err")"; rc=$?
[ "$rc" -eq 0 ] && [ "$out" = opencode-go/deepseek-v4.1-flash ] && grep -q 'FINDING' "$TMP/hpi.err" \
  && ok "--harness pi on a claude row is judged by pi's catalogue, never a Claude name" || bad "--harness pi on a claude row (rc=$rc)" "$out $(cat "$TMP/hpi.err")"

out="$(bash "$AM" forseti --harness pi --tier strong --plain 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^opencode-go/' \
  && ok "--harness pi --tier strong on a claude row resolves a pi model" || bad "--harness pi --tier strong (rc=$rc)" "$out"

out="$(bash "$AM" forseti --tier strong --plain 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q "REFUSED.*harness 'claude'.*--harness pi" \
  && ok "--tier on a claude row without --harness is refused by name" || bad "--tier on a claude row was not refused (rc=$rc)" "$out"

# The pi callers of the forseti row name their harness, so none of them can be handed a Claude name.
for f in bin/ward/vidarr-agent.sh bin/ward/garmr-bite.sh bin/ward/garmr/escalate.py bin/forge/review-seat.sh; do
  calls="$(grep -n 'forseti' "$ROOT/$f" | grep -v '^[0-9]*:[[:space:]]*#' | grep -- 'plain')"
  if [ -n "$calls" ] && ! printf '%s\n' "$calls" | grep -vqE -- '--harness"?,? "?pi'; then
    ok "$f asks for forseti with --harness pi"
  else
    bad "$f asks for forseti without --harness pi" "${calls:-no forseti call found}"
  fi
done

out="$(bash "$AM" forseti --json 2>&1)"
printf '%s' "$out" | grep -q '"harness":"claude"' && printf '%s' "$out" | grep -q '"model":"claude-opus-5-5"' \
  && ok "--json carries the harness" || bad "--json lacks the harness" "$out"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
