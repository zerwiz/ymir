#!/usr/bin/env bash
# test_hodd_set_entries.sh — the vault's writer reads WHOLE ENTRIES and proves what it
# writes (2026-11-20: `hodd-set.sh` took a 91-key vault to 75 in one write).
#
# Every case runs on a THROWAWAY age key and a temp home. The real vault is never
# opened, and no value is ever printed: a check reports ok/FAIL, never the secret.
#
# What is proved:
#   1. `--list` shows all 91 names of a vault holding an OpenSSH multi-line block plus a
#      quoted multi-line value — the block is one entry, its body is not counted.
#   2. set a new key        → 92, and every other entry is byte-identical.
#   3. replace a key        → still 91, and every other entry is byte-identical.
#   4. delete a key         → 90, and every other entry is byte-identical.
#   5. a write that would drop entries is REFUSED and the missing ones are named.
#   6. a stale plaintext beside the .age is never the source: the sealed 91 stay.
#   7. a sealed copy that will not decrypt is refused, and the plaintext is not used.
#   8. `bin/vault/hodd.sh` reads the same whole entries (a multi-line value intact).
#
# Usage: bash bin/vault/tests/test_hodd_set_entries.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(cd "$HERE/.." && pwd)"
DOOR="$VAULT/hodd-set.sh"
READER="$VAULT/hodd.sh"
PARSER="$VAULT/envfile.py"

pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
echo "test_hodd_set_entries"

command -v age >/dev/null 2>&1 || { echo "  SKIP age is not installed"; exit 0; }
command -v age-keygen >/dev/null 2>&1 || { echo "  SKIP age-keygen is not installed"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "  SKIP python3 is not installed"; exit 0; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
H="$T/home"
SEC="$H/hodd/secrets"
mkdir -p "$SEC"
chmod 700 "$H" "$H/hodd" "$SEC"
age-keygen -o "$SEC/age.key" 2>/dev/null || { echo "  FAIL age-keygen"; exit 1; }
chmod 600 "$SEC/age.key"
RECIP="$(age-keygen -y "$SEC/age.key")"

# ── the fixture: 89 plain keys + one armoured block + one quoted multi-line value = 91 ──
# The block's own header and footer are ASSEMBLED from two pieces, so that this public file
# never carries the literal a private key begins with: `bin/gates/guards/public-guard.py`
# refuses that shape in the tree (RULES/04), and it is right to.
SEED="$T/seed.env"
BLOCK_KIND="OPENSSH PRIVATE KEY"
BLOCK_OPEN="-----BEGIN $BLOCK_KIND-----"
BLOCK_CLOSE="-----END $BLOCK_KIND-----"
{
  printf '# a fixture vault — every value here is invented\n\n'
  i=1
  while [ "$i" -le 89 ]; do
    printf 'FIXTURE_KEY_%03d=value-%03d\n' "$i" "$i"
    i=$((i + 1))
  done
  printf 'FIXTURE_PEM=%s\n' "$BLOCK_OPEN"
  printf '%s\n' "Zml4dHVyZS1ub3QtYS1yZWFsLWtleS0xMTExMTExMTExMTExMTExMTExMTExMTExMTExMT"
  printf '%s\n' "ExMTExMTExMTEx"
  printf '%s\n' "$BLOCK_CLOSE"
  printf 'FIXTURE_QUOTED="first line\nsecond line"\n'
} > "$SEED"
age -e -r "$RECIP" -o "$SEC/platform.env.age" "$SEED" || { echo "  FAIL could not seal the fixture"; exit 1; }
cp "$SEED" "$T/seed-copy.env"          # a byte-identical copy of what the vault holds
SEED_COUNT="$(python3 "$PARSER" count "$T/seed-copy.env")"

[ "$SEED_COUNT" = 91 ] && ok "the fixture holds 91 entries (89 plain + a PEM block + a quoted value)" \
  || bad "the fixture holds $SEED_COUNT entries, not 91"

door() { YMIR_HOME="$H" bash "$DOOR" "$@"; }
read_door() { YMIR_HOME="$H" bash "$READER" "$@"; }
vault_now() { age -d -i "$SEC/age.key" "$SEC/platform.env.age"; }

# ── 1. --list shows every name, and no value ────────────────────────────────────────
out="$(door --list 2>/dev/null)"
n="$(printf '%s\n' "$out" | grep -c . || true)"
[ "$n" = 91 ] && ok "--list prints 91 names" || bad "--list printed $n names, not 91"
printf '%s\n' "$out" | grep -qx "FIXTURE_PEM" && printf '%s\n' "$out" | grep -qx "FIXTURE_KEY_089" \
  && ok "--list names the PEM key and the last plain key" || bad "--list missed a name"
printf '%s\n' "$out" | grep -q "value-001" && bad "--list printed a VALUE" || ok "--list printed no value"

# ── 2. set a new key → 92, every other entry byte-identical ──────────────────────────
out="$(printf 'brand-new-secret' | door --stdin NEW_FIXTURE_KEY 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && ok "a new key is written" || bad "setting a new key exited $rc"
[ "$(python3 "$PARSER" count <(vault_now))" = 92 ] && ok "the vault holds 92 entries" \
  || bad "the vault holds $(python3 "$PARSER" count <(vault_now)) entries, not 92"
printf '%s' "$out" | grep -q '"91 → 92"' && ok "the report says 91 → 92" || bad "the report did not say 91 → 92: $out"
vault_now > "$T/after-new.env"
python3 "$PARSER" diff "$T/seed-copy.env" "$T/after-new.env" --except NEW_FIXTURE_KEY >/dev/null \
  && ok "every other entry is byte-identical after the new key" || bad "an untouched entry changed"
[ "$(door --get NEW_FIXTURE_KEY)" = "brand-new-secret" ] && ok "--get returns the new value" || bad "--get did not return the new value"
[ "$(stat -c '%a' "$SEC/platform.env.age")" = 600 ] && ok "the sealed file is mode 600" || bad "the sealed file is not 600"

# ── 3. replace a key → still 91, every other entry byte-identical ────────────────────
out="$(door FIXTURE_KEY_001 replaced-value 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && ok "a key is replaced" || bad "replacing a key exited $rc"
[ "$(python3 "$PARSER" count <(vault_now))" = 92 ] && ok "the vault still holds 92 entries" \
  || bad "the vault holds $(python3 "$PARSER" count <(vault_now)) entries, not 92"
printf '%s' "$out" | grep -q '"92 → 92"' && ok "the report says 92 → 92" || bad "the report did not say 92 → 92: $out"
vault_now > "$T/after-replace.env"
python3 "$PARSER" diff "$T/after-new.env" "$T/after-replace.env" --except FIXTURE_KEY_001 >/dev/null \
  && ok "every other entry is byte-identical after the replace" || bad "an untouched entry changed"
[ "$(door --get FIXTURE_KEY_001)" = "replaced-value" ] && ok "--get returns the replaced value" || bad "the value was not replaced"

# a multi-line value survives a round trip through the vault's writer and reader
door --get FIXTURE_PEM > "$T/pem.read" 2>/dev/null
[ "$(head -1 "$T/pem.read")" = "$BLOCK_OPEN" ] \
  && [ "$(tail -1 "$T/pem.read")" = "$BLOCK_CLOSE" ] \
  && [ "$(grep -c . "$T/pem.read")" = 4 ] \
  && ok "--get returns the whole PEM block (BEGIN, body, END), not its first line" \
  || bad "--get did not return the whole PEM block"
[ "$(door --get FIXTURE_QUOTED 2>/dev/null | wc -l | tr -d ' ')" = 2 ] \
  && ok "--get returns the whole quoted value (2 lines)" || bad "--get truncated the quoted value"

# ── 4. delete a key → 90, every other entry byte-identical ───────────────────────────
out="$(door --del FIXTURE_KEY_002 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && ok "a key is deleted" || bad "deleting a key exited $rc"
[ "$(python3 "$PARSER" count <(vault_now))" = 91 ] && ok "the vault holds 91 entries" \
  || bad "the vault holds $(python3 "$PARSER" count <(vault_now)) entries, not 91"
vault_now > "$T/after-del.env"
python3 "$PARSER" diff "$T/after-replace.env" "$T/after-del.env" --except FIXTURE_KEY_002 >/dev/null \
  && ok "every other entry is byte-identical after the delete" || bad "an untouched entry changed"
door --del FIXTURE_KEY_002 >/dev/null 2>&1; rc=$?
[ "$rc" = 3 ] && ok "deleting an absent key exits 3" || bad "deleting an absent key exited $rc"

# ── 5. a write that would drop entries is refused, and the missing ones are named ────
python3 "$PARSER" del "$T/seed-copy.env" FIXTURE_KEY_010 --out "$T/lost1.env"
python3 "$PARSER" del "$T/lost1.env" FIXTURE_KEY_011 --out "$T/lost2.env"
out="$(python3 "$PARSER" guard --before "$T/seed-copy.env" --after "$T/lost2.env" \
        --key NEW_FIXTURE_KEY --action set 2>&1)"; rc=$?
[ "$rc" = 1 ] && ok "a write that drops entries is refused" || bad "a lossy write was allowed (rc=$rc)"
printf '%s' "$out" | grep -q "FIXTURE_KEY_010" && printf '%s' "$out" | grep -q "FIXTURE_KEY_011" \
  && ok "the refusal names the entries that would go missing" || bad "the refusal named no entries: $out"
printf '%s' "$out" | grep -q "value-010" && bad "the refusal printed a value" || ok "the refusal printed names only"

# ── 6. a STALE plaintext beside the .age is never the source (the 2026-11-20 fault) ──
printf 'STALE_ONE=1\nSTALE_TWO=2\nSTALE_THREE=3\n' > "$SEC/platform.env"
before_count="$(python3 "$PARSER" count <(vault_now))"
out="$(printf 'sealed-wins' | door --stdin FROM_SEALED 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && ok "a write succeeds with a stale plaintext beside the vault" || bad "the write exited $rc"
[ "$(python3 "$PARSER" count <(vault_now))" = "$((before_count + 1))" ] \
  && ok "the write added exactly one entry — the stale plaintext was NOT the source" \
  || bad "the vault holds $(python3 "$PARSER" count <(vault_now)) entries, not $((before_count + 1))"
vault_now > "$T/after-stale.env"
python3 "$PARSER" diff "$T/after-del.env" "$T/after-stale.env" --except FROM_SEALED >/dev/null \
  && ok "the sealed entries survived the stale plaintext" || bad "the stale plaintext leaked into the write"
rm -f "$SEC/platform.env"

# ── 7. a sealed copy that will not decrypt is refused, never replaced by the plaintext ─
mkdir -p "$T/broken/hodd/secrets"
cp "$SEC/age.key" "$T/broken/hodd/secrets/age.key"
printf 'not an age file at all\n' > "$T/broken/hodd/secrets/platform.env.age"
printf 'PLAINTEXT_FALLBACK=should-never-be-read\n' > "$T/broken/hodd/secrets/platform.env"
out="$(YMIR_HOME="$T/broken" bash "$DOOR" --list 2>&1)"; rc=$?
[ "$rc" != 0 ] && ok "a sealed copy that will not decrypt is refused" || bad "the door read the plaintext instead"
printf '%s' "$out" | grep -q "should-never-be-read" && bad "the plaintext value was printed" || ok "no plaintext value was served"
out="$(YMIR_HOME="$T/broken" bash "$READER" names secrets/platform.env 2>&1)"; rc=$?
[ "$rc" != 0 ] && ok "the reader refuses the same way (no silent fallback)" || bad "the reader served the plaintext"
[ -s "$T/broken/hodd/secrets/platform.env.age" ] && ok "the unreadable sealed copy was left alone" || bad "the sealed copy was replaced"

# ── 7b. a block whose END was lost does not swallow the entries below it ─────────────
# (measured on the real vault 2026-11-20: one entry is a BEGIN line with no body and no
# END, and a block reader that scans to the next END takes five live entries with it.)
mkdir -p "$T/lost/hodd/secrets"
cp "$SEC/age.key" "$T/lost/hodd/secrets/age.key"
{
  printf '# fixture\n'
  printf 'BEFORE_KEY=1\n'
  printf 'TRUNCATED_BLOCK=%s\n' "$BLOCK_OPEN"
  printf 'AFTER_ONE=2\nAFTER_TWO=3\n'
  printf 'GOOD_BLOCK=%s\n' "$BLOCK_OPEN"
  printf 'ZmFrZQ==\n'
  printf '%s\n' "$BLOCK_CLOSE"
  printf 'LAST_KEY=4\n'
} > "$T/lost.env"
[ "$(python3 "$PARSER" count "$T/lost.env")" = 6 ] \
  && ok "an unterminated block is one entry, and the entries below it are still counted" \
  || bad "an unterminated block swallowed its neighbours: $(python3 "$PARSER" count "$T/lost.env") entries"
[ "$(python3 "$PARSER" unterminated "$T/lost.env")" = "TRUNCATED_BLOCK" ] \
  && ok "the unterminated block is named (names only)" || bad "the unterminated block was not named"
age -e -r "$RECIP" -o "$T/lost/hodd/secrets/platform.env.age" "$T/lost.env"
out="$(printf 'kept' | YMIR_HOME="$T/lost" bash "$DOOR" --stdin SAFE_KEY 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "a vault with an unterminated block can still be written safely" || bad "the write exited $rc"
[ "$(YMIR_HOME="$T/lost" bash "$DOOR" --get AFTER_TWO 2>/dev/null)" = "3" ] \
  && ok "the entries below the unterminated block survived the write" || bad "entries below the block were lost"
printf '%s' "$out" | grep -q "TRUNCATED_BLOCK" && ok "the write warns, naming the block" || bad "the warning did not name the block"

# ── 8. the reader parses the same whole entries ─────────────────────────────────────
out="$(read_door names secrets/platform.env 2>/dev/null)"
[ "$(printf '%s\n' "$out" | grep -c . || true)" = "$(python3 "$PARSER" count <(vault_now))" ] \
  && ok "hodd.sh names reads the same entries the writer sees" || bad "the two doors disagree on the count"
read_door emit secrets/platform.env > "$T/emit.sh" 2>/dev/null
( set -u; . "$T/emit.sh" 2>/dev/null; printf '%s' "${FIXTURE_PEM:-}" ) > "$T/pem.emitted"
[ "$(head -1 "$T/pem.emitted")" = "$BLOCK_OPEN" ] \
  && ok "hodd.sh emit carries the whole PEM block into the shell" || bad "emit truncated the PEM block"

# ── the real vault was never touched ───────────────────────────────────────────────
[ ! -e "$HOME/Documents/ymirhome/hodd/secrets/platform.env.age.bak-test" ] \
  && ok "no backup was written beside the real vault" || bad "the test wrote beside the real vault"

printf '\n%s\n' "$([ "$fail" -eq 0 ] && echo "all cases passed ($pass)" || echo "a case failed ($pass passed, $fail failed)")"
[ "$fail" -eq 0 ]
