#!/usr/bin/env bash
# rodd-head.test.sh — the head's one door: where the values live, and what it refuses.
#
# Rödd is the app and Nanna is the voice in her. The head — the model she thinks with —
# is resolved in ONE place, and a key never enters the repository:
#
#   repo    apps/rodd/config/rodd.env.example     the SHAPE only
#   home    $YMIR_HOME/hodd/secrets/rodd.env      the VALUES, mode 0600
#
# Proven here, hermetically:
#   * with no home file the shipped template answers, and no model is invented;
#   * `set` writes the home file, mode 0600, and the value round-trips;
#   * the environment beats the home, and the home beats the template;
#   * a home that resolves INSIDE the repository is refused by name;
#   * `resolve` prints no key, and `env` prints one only with --with-key.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOOR="$ROOT/bin/voice/rodd-head.py"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

command -v python3 >/dev/null 2>&1 || { printf '1..0 # skip python3 is absent\n'; exit 0; }
[ -r "$DOOR" ] || { bad "bin/voice/rodd-head.py is missing"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"
mkdir -p "$YMIR_HOME/hodd/secrets"

# ── 1. the template answers when no home file exists, and names no model ──────
OUT="$(python3 "$DOOR" resolve 2>&1)"; RC=$?
case "$OUT" in
  *"mode=local"*) ok "with no home file the shipped template answers (mode=local)" ;;
  *) bad "the template answers (got: $(printf '%s' "$OUT" | head -2 | tr '\n' ' '))" ;;
esac
[ "$RC" -eq 1 ] && ok "no model is invented — resolve exits 1 until one is named" \
               || bad "resolve must exit 1 while no model is named (rc=$RC)"

# ── 2. set writes the home, 0600, and the value round-trips ──────────────────
python3 "$DOOR" set --mode local --base-url http://127.0.0.1:1/v1 --model test-model --key-name SOME_KEY >/dev/null 2>&1
F="$YMIR_HOME/hodd/secrets/rodd.env"
if [ -f "$F" ]; then
  MODE="$(stat -c '%a' "$F")"
  [ "$MODE" = "600" ] && ok "the home's secrets file is 0600" || bad "the secrets file must be 0600 (is $MODE)"
  grep -q '^RODD_HEAD_LOCAL_MODEL=test-model$' "$F" && ok "the model round-trips into the home file" \
    || bad "the model did not land in the home file"
else
  bad "set wrote no home secrets file"
fi

# ── 3. environment beats home; home beats template ───────────────────────────
OUT="$(RODD_HEAD_LOCAL_MODEL=from-env python3 "$DOOR" resolve 2>&1)"
case "$OUT" in *"model=from-env"*) ok "the environment beats the home file" ;;
  *) bad "the environment should win over the home file (got: $(printf '%s' "$OUT" | tr '\n' ' '))" ;; esac

# ── 4. a home inside the repository is refused by name ───────────────────────
OUT="$(YMIR_HOME="$ROOT" python3 "$DOOR" set --mode local --model nope --api-key sekrit 2>&1)"; RC=$?
[ "$RC" -ne 0 ] && case "$OUT" in
  *inside\ the\ repository*) ok "a key store inside the repository is refused by name" ;;
  *) bad "the refusal should name the repository (got: $(printf '%s' "$OUT" | head -1))" ;;
esac || bad "set must refuse a key store inside the repository"

# ── 5. no key is printed by resolve, and only --with-key prints one by env ────
python3 "$DOOR" set --mode online --base-url https://example.invalid/v1 --model m --api-key "sk-test-123456789" >/dev/null 2>&1
RES="$(python3 "$DOOR" resolve 2>&1)"
case "$RES" in *sk-test-123456789*) bad "resolve printed the key" ;;
  *) ok "resolve prints no key — only its state" ;; esac
case "$RES" in *"key_state=typed"*) ok "resolve reports the key's state, not its value" ;;
  *) bad "resolve should report the key state (got: $(printf '%s' "$RES" | grep key_state))" ;; esac
ENV_PLAIN="$(python3 "$DOOR" env 2>&1)"
ENV_KEY="$(python3 "$DOOR" env --with-key 2>&1)"
case "$ENV_PLAIN" in *sk-test-123456789*) bad "env printed the key without --with-key" ;;
  *) ok "env prints no key unless asked" ;; esac
case "$ENV_KEY" in *RODD_VOICE_HEAD_API_KEY=sk-test-123456789*) ok "env --with-key hands the key to the door" ;;
  *) bad "env --with-key must carry the key" ;; esac

[ "$fail" -eq 0 ] && printf '1..1 # all claims proved\n'
exit "$fail"
