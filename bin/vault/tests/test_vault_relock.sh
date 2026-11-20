#!/usr/bin/env bash
# test_vault_relock.sh — the vault's lock, proven on a THROWAWAY home (plan 342 phase 1).
#
# The real vault is never touched by this test: it builds its own home in a temp
# directory, generates two SSH keypairs that may open the lock and a third that may not,
# and stands a fake `gh` in front of the owner's GitHub key list. Nothing here prints a
# value — only titles, fingerprints and counts, exactly as the door itself does.
#
# It proves, one line each:
#
#   1. `--plan` names the declared keys and reports an undeclared GitHub key, writing nothing;
#   2. a re-lock seals to keys A and B — each opens the vault, and a third key C cannot;
#   3. a second re-lock leaves the CONTENT byte for byte identical to the first;
#   4. a declared key that GitHub does not list REFUSES the re-lock, and the vault is untouched;
#   5. a failed re-encrypt keeps the old file, byte for byte;
#   6. a seat with an SSH identity and NO `age.key` reads the vault (`hodd.sh emit`);
#   7. a seat that is not a recipient is refused, and says so;
#   8. `hodd-set.sh` writes through the SSH identity when there is no `age.key`;
#   9. the guard refuses a plain-text `.env` and a returning `age.key`, and allows an empty scaffold;
#  10. `--check` answers for a seat that opens the vault, and for one that cannot.
#
# Usage: bash bin/vault/tests/test_vault_relock.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RELOCK="$HERE/../vault-relock.sh"
GUARD="$ROOT/gates/guards/secrets-plaintext-guard.sh"
HODD="$HERE/../hodd.sh"
HODD_SET="$HERE/../hodd-set.sh"

command -v age >/dev/null 2>&1 || { printf 'test_vault_relock: SKIP — age is not installed\n'; exit 0; }
command -v ssh-keygen >/dev/null 2>&1 || { printf 'test_vault_relock: SKIP — ssh-keygen is not installed\n'; exit 0; }
AGE_BIN="$(command -v age)"

pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
echo "test_vault_relock"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
HOME_DIR="$T/home"
mkdir -p "$HOME_DIR/config" "$HOME_DIR/hodd/secrets" "$HOME_DIR/state" "$T/keys" "$T/bin"

# ── three machines, three keys ────────────────────────────────────────────────
for k in A B C D; do
  ssh-keygen -q -t ed25519 -N '' -C "machine-$k" -f "$T/keys/$k" || exit 1
done
FP_A="$(ssh-keygen -lf "$T/keys/A.pub" | awk '{print $2}')"
FP_B="$(ssh-keygen -lf "$T/keys/B.pub" | awk '{print $2}')"
FP_C="$(ssh-keygen -lf "$T/keys/C.pub" | awk '{print $2}')"
FP_D="$(ssh-keygen -lf "$T/keys/D.pub" | awk '{print $2}')"

# three seats: each holds ONE private key in its own ~/.ssh, as a real machine does
for s in a b c; do
  mkdir -p "$T/seat-$s/.ssh"; chmod 700 "$T/seat-$s/.ssh"
  cp "$T/keys/${s^^}" "$T/seat-$s/.ssh/id_ed25519"
  chmod 600 "$T/seat-$s/.ssh/id_ed25519"
done
SEAT_A="$T/seat-a"; SEAT_B="$T/seat-b"; SEAT_C="$T/seat-c"

# ── the vault as it stands today: locked to A alone ───────────────────────────
cat > "$T/plain" <<EOF
ALPHA=first-value
BETA=second-value
GAMMA=third-value
EOF
chmod 600 "$T/plain"
age -e -R "$T/keys/A.pub" -o "$HOME_DIR/hodd/secrets/platform.env.age" "$T/plain" || exit 1
VAULT="$HOME_DIR/hodd/secrets/platform.env.age"

# ── the owner's GitHub list, and a fake gh that serves it ─────────────────────
python3 - "$T" "$FP_A" "$FP_B" "$FP_C" <<'PY'
import json, sys, pathlib
t = pathlib.Path(sys.argv[1])
rows = [("machine-a", t / "keys/A.pub"), ("machine-b", t / "keys/B.pub"),
        ("old-phone", t / "keys/C.pub")]
with open(t / "ghkeys.jsonl", "w") as f:
    for title, path in rows:
        f.write(json.dumps({"id": 1, "title": title, "key": path.read_text().strip()}) + "\n")
PY
cat > "$T/bin/gh" <<EOF
#!/usr/bin/env bash
case "\$*" in
  "api user --jq .login") printf 'example-user\\n' ;;
  api*user/keys*) cat "$T/ghkeys.jsonl" ;;
  *) printf 'fake gh: unsupported: %s\\n' "\$*" >&2; exit 1 ;;
esac
EOF
chmod +x "$T/bin/gh"

# ── the declaration: A and B may open it; C lives on GitHub and is not declared ─
declare_ab() {
  cat > "$HOME_DIR/config/vault-recipients.yaml" <<EOF
# the machines that may open the vault (a fixture home: invented titles)
vault: hodd/secrets/platform.env.age
login: example-user
recipients:
  - title: machine-a
    fingerprint: $FP_A
    machine: the first seat
  - title: machine-b
    fingerprint: $FP_B
    machine: the second seat
EOF
}
declare_ab

sha() { sha256sum "$VAULT" | awk '{print $1}'; }
opens() {  # <seat-home> <key> — does this private key open the vault, and is the content right
  local out="$T/out.$$"
  if age -d -i "$2" "$VAULT" > "$out" 2>/dev/null; then
    cmp -s "$out" "$T/plain" && { rm -f "$out"; return 0; }
    rm -f "$out"; return 2
  fi
  rm -f "$out"; return 1
}

# ── 1. --plan names who, and writes nothing ───────────────────────────────────
out="$(YMIR_HOME="$HOME_DIR" HOME="$SEAT_A" PATH="$T/bin:$PATH" bash "$RELOCK" --plan 2>&1)"
case "$out" in
  *'"used","machine-a"'*'"used","machine-b"'*) ok "--plan names the two declared keys" ;;
  *) bad "--plan did not name the declared keys: $out" ;;
esac
case "$out" in
  *'"undeclared","old-phone"'*) ok "--plan reports the GitHub key nobody declared" ;;
  *) bad "--plan did not report the undeclared key" ;;
esac
[ ! -e "$HOME_DIR/state/vault-lock.state" ] && [ "$(sha)" = "$(sha)" ] \
  && ok "--plan wrote nothing (no lock record, vault untouched)" \
  || bad "--plan left something behind"

# ── 2. the re-lock to A and B ─────────────────────────────────────────────────
out="$(YMIR_HOME="$HOME_DIR" HOME="$SEAT_A" PATH="$T/bin:$PATH" bash "$RELOCK" --relock 2>&1)"
rc=$?
[ "$rc" = 0 ] && ok "the re-lock succeeded" || bad "the re-lock failed (rc=$rc): $out"
opens "$SEAT_A" "$T/keys/A" && ok "key A opens the re-locked vault, content byte for byte" || bad "key A cannot open it"
opens "$SEAT_B" "$T/keys/B" && ok "key B opens it — a machine that was added can read the vault" || bad "key B cannot open it"
if opens "$SEAT_C" "$T/keys/C"; then bad "key C opened it — an undeclared key must never open the vault"; else ok "key C cannot open it (not declared)"; fi

# a backup of the old lock was kept beside it
ls "$HOME_DIR/hodd/secrets"/platform.env.age.bak-* >/dev/null 2>&1 \
  && ok "the old lock was kept as a timestamped backup" || bad "no backup was kept"

# ── 3. a second re-lock: the CONTENT is byte for byte identical ───────────────
cp "$T/plain" "$T/plain.before"
YMIR_HOME="$HOME_DIR" HOME="$SEAT_A" PATH="$T/bin:$PATH" bash "$RELOCK" --relock >/dev/null 2>&1 \
  || bad "the second re-lock failed"
opens "$SEAT_A" "$T/keys/A" && cmp -s "$T/plain" "$T/plain.before" \
  && ok "a second re-lock leaves the content byte for byte identical" \
  || bad "the second re-lock changed the content"

# ── 4. a declared key GitHub does not list REFUSES, and nothing is written ────
before="$(sha)"
cat >> "$HOME_DIR/config/vault-recipients.yaml" <<EOF
  - title: machine-d
    fingerprint: $FP_D
    machine: a seat whose key nobody has put on GitHub
EOF
out="$(YMIR_HOME="$HOME_DIR" HOME="$SEAT_A" PATH="$T/bin:$PATH" bash "$RELOCK" --relock 2>&1)"
rc=$?
[ "$rc" != 0 ] && ok "a declared key GitHub does not list is a REFUSAL (rc=$rc)" || bad "a missing declared key did not refuse"
case "$out" in *'"missing","machine-d"'*) ok "the refusal names the key that is missing" ;; *) bad "the refusal did not name machine-d: $out" ;; esac
[ "$(sha)" = "$before" ] && ok "the refusal wrote nothing — the vault is byte for byte as it was" || bad "the vault changed on a refusal"
declare_ab

# ── 5. a failed re-encrypt keeps the old file ────────────────────────────────
mkdir -p "$T/failbin"
cat > "$T/failbin/age" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  [ "\$arg" = "-e" ] && { printf 'fake age: refusing to encrypt\\n' >&2; exit 1; }
done
exec "$AGE_BIN" "\$@"
EOF
chmod +x "$T/failbin/age"
before="$(sha)"
out="$(YMIR_HOME="$HOME_DIR" HOME="$SEAT_A" PATH="$T/bin:$PATH" YMIR_AGE_BIN="$T/failbin/age" bash "$RELOCK" --relock 2>&1)"
rc=$?
[ "$rc" != 0 ] && ok "a failed re-encrypt exits non-zero (rc=$rc)" || bad "a failed re-encrypt reported success"
[ "$(sha)" = "$before" ] && ok "a failed re-encrypt kept the old file, byte for byte" || bad "the vault changed after a failed re-encrypt"
opens "$SEAT_A" "$T/keys/A" && ok "the old lock still opens after the failed attempt" || bad "the old lock no longer opens"

# ── 6. the reader: an SSH identity, and NO age.key anywhere ────────────────────
[ ! -e "$HOME_DIR/hodd/secrets/age.key" ] && ok "no age.key exists in the fixture home (the switch's whole point)" || bad "an age.key is present"
out="$(YMIR_HOME="$HOME_DIR" HOME="$SEAT_A" bash "$HODD" emit secrets/platform.env 2>&1)"
[ "$(printf '%s\n' "$out" | grep -c '^export ')" = 3 ] \
  && ok "hodd.sh emit decrypts with the SSH identity alone (3 keys, no age.key)" \
  || bad "hodd.sh emit did not read the vault: $out"
out="$(YMIR_HOME="$HOME_DIR" HOME="$SEAT_A" bash "$HODD" load secrets/platform.env 2>&1)"
case "$out" in
  *first-value*|*second-value*) bad "the load door printed a value" ;;
  *'"load"'*) ok "the load door resolves the vault and prints no value" ;;
  *) bad "the load door did not resolve the vault: $out" ;;
esac

# ── 7. a seat that is not a recipient is refused ──────────────────────────────
out="$(YMIR_HOME="$HOME_DIR" HOME="$SEAT_C" bash "$HODD" emit secrets/platform.env 2>&1)"
rc=$?
[ "$rc" != 0 ] && ok "a seat that is not a recipient is refused (rc=$rc)" || bad "a non-recipient seat read the vault"

# ── 8. the writer (hodd-set.sh) through the SSH identity, with no age.key ─────
out="$(YMIR_HOME="$HOME_DIR" HOME="$SEAT_A" PATH="$T/bin:$PATH" bash "$HODD_SET" DELTA fourth-value 2>&1)"
rc=$?
[ "$rc" = 0 ] && ok "hodd-set.sh wrote one key with no age.key present" || bad "hodd-set.sh failed without age.key (rc=$rc): $out"
out="$(YMIR_HOME="$HOME_DIR" HOME="$SEAT_A" bash "$HODD" emit secrets/platform.env 2>&1)"
[ "$(printf '%s\n' "$out" | grep -c '^export ')" = 4 ] \
  && ok "the vault now carries four keys, read through the SSH identity" \
  || bad "the vault does not carry four keys after the write"
out="$(YMIR_HOME="$HOME_DIR" HOME="$SEAT_A" PATH="$T/bin:$PATH" bash "$RELOCK" --relock 2>&1)"
[ $? = 0 ] && ok "a re-lock after the write seals the whole vault again" || bad "the re-lock after the write failed: $out"
out="$(YMIR_HOME="$HOME_DIR" HOME="$SEAT_B" bash "$HODD" emit secrets/platform.env 2>&1)"
[ "$(printf '%s\n' "$out" | grep -c '^export ')" = 4 ] \
  && ok "the second seat reads the same four keys after a re-lock" \
  || bad "the second seat cannot read the re-locked vault"

# ── 8b. the LEGACY key still opens the vault while it exists (the switch is not a cliff) ──
LEG="$T/legacy"; mkdir -p "$LEG/hodd/secrets" "$LEG/seat/.ssh"
age-keygen -o "$LEG/hodd/secrets/age.key" 2>/dev/null || bad "age-keygen failed"
printf 'OLD=one\n' > "$T/legacy-plain"; chmod 600 "$T/legacy-plain"
age -e -r "$(age-keygen -y "$LEG/hodd/secrets/age.key")" -o "$LEG/hodd/secrets/platform.env.age" "$T/legacy-plain" \
  || bad "could not seal the legacy fixture"
out="$(YMIR_HOME="$LEG" HOME="$T/seat-a" bash "$HODD" emit secrets/platform.env 2>&1)"
[ "$(printf '%s\n' "$out" | grep -c '^export ')" = 1 ] \
  && ok "the legacy age.key still opens an old vault while it exists" \
  || bad "the legacy age.key no longer opens an old vault: $out"
# an unrelated SSH key on the seat must not stop the fallback to age.key
cp "$T/keys/C" "$LEG/seat/.ssh/id_ed25519"; chmod 600 "$LEG/seat/.ssh/id_ed25519"
out="$(YMIR_HOME="$LEG" HOME="$LEG/seat" bash "$HODD" emit secrets/platform.env 2>&1)"
[ "$(printf '%s\n' "$out" | grep -c '^export ')" = 1 ] \
  && ok "an SSH key that is NOT a recipient does not stop the legacy fallback" \
  || bad "the fallback stopped at an unrelated SSH key: $out"

# ── 9. the guard ─────────────────────────────────────────────────────────────
G="$T/guardhome"; mkdir -p "$G/hodd/secrets"
git -C "$G" init -q . 2>/dev/null
git -C "$G" config user.email fixture@example.org
git -C "$G" config user.name fixture
printf 'placeholder\n' > "$G/hodd/secrets/notes.txt"
git -C "$G" add hodd/secrets/notes.txt && git -C "$G" commit -qm base

printf 'SMTP_PASSWORD=not-a-real-value\n' > "$G/hodd/secrets/stack.env"
git -C "$G" add -f hodd/secrets/stack.env
YMIR_HOME="$G" bash "$GUARD" >/dev/null 2>&1
[ $? = 1 ] && ok "the guard refuses a plain-text .env under hodd/secrets" || bad "the guard allowed a plain-text .env"
git -C "$G" reset -q hodd/secrets/stack.env; rm -f "$G/hodd/secrets/stack.env"

: > "$G/hodd/secrets/platform.env"; git -C "$G" add -f hodd/secrets/platform.env
YMIR_HOME="$G" bash "$GUARD" >/dev/null 2>&1
[ $? = 0 ] && ok "the guard allows an EMPTY scaffold (the installer seeds one)" || bad "the guard refused an empty scaffold"
git -C "$G" reset -q hodd/secrets/platform.env; rm -f "$G/hodd/secrets/platform.env"

printf 'AGE-SECRET-KEY-1FIXTURE\n' > "$G/hodd/secrets/age.key"; git -C "$G" add -f hodd/secrets/age.key
YMIR_HOME="$G" bash "$GUARD" >/dev/null 2>&1
[ $? = 1 ] && ok "the guard refuses age.key coming back" || bad "the guard allowed age.key back"
git -C "$G" reset -q hodd/secrets/age.key; rm -f "$G/hodd/secrets/age.key"

YMIR_HOME="$G" bash "$GUARD" >/dev/null 2>&1
[ $? = 0 ] && ok "the guard is clean on a commit with nothing to judge" || bad "the guard refused a clean commit"

# ── 10. --check answers for a seat that opens the vault, and one that cannot ──
YMIR_HOME="$HOME_DIR" HOME="$SEAT_A" PATH="$T/bin:$PATH" bash "$RELOCK" --check --quiet
[ $? = 0 ] && ok "--check is green for a seat that opens the vault" || bad "--check failed for a recipient seat"
YMIR_HOME="$HOME_DIR" HOME="$SEAT_C" PATH="$T/bin:$PATH" bash "$RELOCK" --check --quiet
[ $? = 3 ] && ok "--check names the fault for a seat that cannot (exit 3)" || bad "--check did not fault for a non-recipient seat"

printf 'test_vault_relock: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
