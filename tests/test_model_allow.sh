#!/usr/bin/env bash
# test_model_allow.sh — the allow-list at the spawn door (2026-11-12).
#
# A throwaway home carries an allow-list with exactly the fleet's approved models:
# opencode-go/deepseek-v4.1-flash, the local rail (llama-swap/*, llamacpp-*/*) and,
# for the Claude harness, claude-opus-5-5. Then:
#
#   · a spawn asking for opencode-go/deepseek-v4-pro is refused, with the reason
#   · the same spawn with a dated grant succeeds, and the grant use is logged
#   · flash spawns as before
#   · a claude spawn with no --model gets claude-opus-5-5; --model opus does too
#   · a claude spawn asking for sonnet, or for another harness's model, is refused
#   · the resolver refuses a pro request and resolves `opus` for Claude
#
# Spawns run with --dry-run (nothing is created). A case whose harness is not on PATH
# is a clean skip, never a pass. Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SPAWN="$ROOT/bin/agents/einherjar-spawn.sh"
ALLOW="$ROOT/bin/model/model-allow.sh"
RESOLVE="$ROOT/bin/model/model-resolve.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-model-allow.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"
export YMIR_SETTINGS_DIR="$TMP/home/config"
export BROKK_STATE_OVERRIDE="$TMP/state"
export BROKK_DATA_OVERRIDE="$TMP/home/data"
export BROKK_CONFIG_OVERRIDE="$TMP/home/config"
unset YMIR_STATE_DIR
mkdir -p "$YMIR_SETTINGS_DIR" "$BROKK_STATE_OVERRIDE" "$BROKK_DATA_OVERRIDE/allowtest"

cat >"$YMIR_SETTINGS_DIR/agents.yaml" <<'YAML'
version: 1
harness: { local: pi, online: pi, local_providers: [llama-swap] }
default_model: opencode-go/deepseek-v4.1-flash
providers: { opencode-go: { models: [deepseek-v4.1-flash] } }
agents:
  brokk: { model: opencode-go/deepseek-v4.1-flash }
YAML
LIST="$YMIR_SETTINGS_DIR/models-allowed.yaml"
write_list() {  # [<grants block>]
  cat >"$LIST" <<YAML
version: 1
allow:
  - opencode-go/deepseek-v4.1-flash
  - llama-swap/*
  - llamacpp-*/*
  - claude/claude-opus-5-5
defaults:
  claude: claude-opus-5-5
${1:-grants: []}
YAML
}
write_list
printf '# Task\n\nPrint seated.\n\nIsolation: herdr — the test raises nothing\n\nDelivery contract: mode=local-only\n' \
  >"$BROKK_DATA_OVERRIDE/allowtest/brief.md"

pass=0; fail=0; skip=0
ok()   { pass=$((pass+1)); printf 'ok    %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$(printf '%s' "$2" | head -3 | tr '\n' ' ')"; }
skip() { skip=$((skip+1)); printf 'skip  %s (%s)\n' "$1" "$2"; }
have() { command -v "$1" >/dev/null 2>&1; }
spawn() { "$SPAWN" allowtest "$ROOT" --scout --dry-run --backend tmux "$@" 2>&1; }
preflight_model() { printf '%s\n' "$1" | awk '/^preflight\[1\]/{getline; print; exit}' | cut -d'"' -f16; }

# ── the door ──
out="$("$ALLOW" check opencode-go/deepseek-v4-pro --harness pi)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$out" | grep -q '"refused"' && ok "door refuses pro" || bad "door refuses pro" "$out"
out="$("$ALLOW" check opencode-go/deepseek-v4.1-flash --harness pi)" && ok "door allows flash" || bad "door allows flash" "$out"
out="$("$ALLOW" check llama-swap/anything@iq3 --harness pi)" && ok "door allows the local rail" || bad "door allows the local rail" "$out"
out="$(YMIR_ALLOW_ANY=1 YMIR_MODEL_ALLOW=off "$ALLOW" check opencode-go/deepseek-v4-pro --harness pi)"
[ $? = 3 ] && ok "no variable bypasses the list" || bad "no variable bypasses the list" "$out"

# ── the resolver ──
out="$("$RESOLVE" resolve opencode-go/deepseek-v4-pro 2>&1)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'allow: refused' && ok "resolver refuses pro" || bad "resolver refuses pro" "$out"
out="$("$RESOLVE" resolve opus 2>&1)"
printf '%s' "$out" | grep -q '"claude","claude","claude-opus-5-5"' && ok "resolver resolves opus for Claude" || bad "resolver resolves opus for Claude" "$out"

# ── the spawner: pi ──
if have pi; then
  out="$(spawn --harness pi --model opencode-go/deepseek-v4-pro)"; rc=$?
  [ "$rc" != 0 ] && printf '%s' "$out" | grep -q "refused: model 'opencode-go/deepseek-v4-pro' is not on this fleet's allow-list" \
    && ok "spawn refuses pro, naming it" || bad "spawn refuses pro, naming it" "$out"
  if "$ROOT/bin/model/catalog.sh" --has opencode-go/deepseek-v4.1-flash >/dev/null 2>&1; then
    out="$(spawn --harness pi --model opencode-go/deepseek-v4.1-flash)"
    [ "$(preflight_model "$out")" = opencode-go/deepseek-v4.1-flash ] && ok "flash spawns as before" || bad "flash spawns as before" "$out"
  else
    skip "flash spawns as before" "this seat's catalogue does not list flash"
  fi
  if "$ROOT/bin/model/catalog.sh" --has opencode-go/deepseek-v4-pro >/dev/null 2>&1; then
    write_list "grants:
  - model: opencode-go/deepseek-v4-pro
    reason: the test's one deliberate pro launch
    granted_by: the test
    granted_at: 2026-11-12
    expires: 2999-01-01
    uses: 1"
    out="$(spawn --harness pi --model opencode-go/deepseek-v4-pro)"
    [ "$(preflight_model "$out")" = opencode-go/deepseek-v4-pro ] && printf '%s' "$out" | grep -q 'runs on a grant' \
      && ok "a dated grant lets pro spawn" || bad "a dated grant lets pro spawn" "$out"
    "$ALLOW" check opencode-go/deepseek-v4-pro --harness pi --for allowtest >/dev/null
    grep -q '"allowtest","pi","opencode-go/deepseek-v4-pro","granted"' "$BROKK_STATE_OVERRIDE/model-allow.log" \
      && ok "the grant use is logged" || bad "the grant use is logged" "$(cat "$BROKK_STATE_OVERRIDE/model-allow.log" 2>&1)"
    out="$("$ALLOW" check opencode-go/deepseek-v4-pro --harness pi --for another-errand)"
    [ $? = 3 ] && ok "a one-use grant is spent by one errand" || bad "a one-use grant is spent by one errand" "$out"
    write_list
  else
    skip "a dated grant lets pro spawn" "this seat's catalogue does not list pro"
  fi
else
  skip "pi spawns" "pi is not on PATH"
fi

# ── the spawner: claude ──
if have claude && [ -f "$ROOT/.agents/harnesses/claude-worker.settings.json" ]; then
  out="$(spawn --harness claude)"
  [ "$(preflight_model "$out")" = claude-opus-5-5 ] && ok "claude gets Opus 5.5 with no --model" || bad "claude gets Opus 5.5 with no --model" "$out"
  out="$(spawn --harness claude --model opus)"
  [ "$(preflight_model "$out")" = claude-opus-5-5 ] && ok "claude --model opus is Opus 5.5" || bad "claude --model opus is Opus 5.5" "$out"
  for m in sonnet haiku claude-fable-5-2 opencode-go/deepseek-v4.1-flash; do
    out="$(spawn --harness claude --model "$m")"; rc=$?
    [ "$rc" != 0 ] && printf '%s' "$out" | grep -q '^refused:' && ok "claude refuses $m" || bad "claude refuses $m" "$out"
  done
else
  skip "claude spawns" "claude or its worker profile is absent"
fi

printf '\nmodel-allow: %s ok · %s failed · %s skipped\n' "$pass" "$fail" "$skip"
[ "$fail" = 0 ]
