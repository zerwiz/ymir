#!/usr/bin/env bash
# test_container_hides_the_hoard.sh — a container Ymir ships never holds the vault.
#
# WHY (the security review, 2026-11-12, item 5; his words on the 15:08 mail): *"The container
# mount gives the container the secrets folder — key and encrypted file together. I masked it in my
# Quadlet; the shipped Quadlet should do the same."* He is right, and it is the one of his six finds
# that lives entirely in code: a container that mounts the operator's home can read
# `hodd/secrets/age.key` AND `hodd/secrets/platform.env.age` in the same breath, so it can decrypt
# the vault. The isolation boundary then protects nothing it was built to protect.
#
# The claims this test holds, all by reading the shipped shapes:
#   1. `deploy/quadlet/ymir.container` mounts the operator's home — so it owes the mask;
#   2. the mask (`Tmpfs=`) is exactly `<the home mount's container side>/hodd/secrets`, so the two
#      can never drift apart silently;
#   3. the mask is read-only and size-capped (an empty tmpfs, not a writable hole);
#   4. no shipped shape depends on `$HOME_SEAT`, an undefined variable — a mask or a mount written
#      from an unset variable lands on a literal path, which is a mask that hides nothing;
#   5. any OTHER shipped shape that mounts the home masks it too (today Compose mounts only the
#      checkout, and the test says so rather than assuming it).
#
# The live container proof — a raised container cannot list the folder — is owed on a Podman host
# and is named in the fix note; what this test can prove on every host is the shape.
#
# Usage: test_container_hides_the_hoard.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
Q="$ROOT/deploy/quadlet/ymir.container"
C="$ROOT/deploy/compose/compose.yaml"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

[ -r "$Q" ] || { printf 'FAIL deploy/quadlet/ymir.container is missing\n'; exit 1; }

printf 'container · the vault is not the container'"'"'s\n'

# ── the quadlet: the home mount, and the mask that matches it ────────────────
# The HOME mount is the one that ends at the operator's home itself — `.../Documents/<home>`, the
# shape this house uses (the older `Documents/Ymir`, the newer `Documents/ymirhome`). The harness
# config mount (`%h/.pi`) is a config path, not the home, and owes no mask.
home_dest=""
while IFS= read -r line; do
  dest="${line#*=}"; dest="${dest%%:*}"                       # strip :Z / :ro / options
  case "$dest" in
    */Documents/[A-Za-z]*) home_dest="$dest" ;;
  esac
done <<EOF
$(grep -E '^Volume=' "$Q")
EOF

if [ -n "$home_dest" ]; then
  ok "the quadlet mounts the operator's home ($home_dest) — and therefore owes a mask"
else
  bad "the quadlet mounts the operator's home" "no Volume= names a home path"
fi

want="${home_dest%/}/hodd/secrets"
mask=""
while IFS= read -r line; do
  p="${line#*=}"; p="${p%%:*}"
  [ "$p" = "$want" ] && mask="$line"
done <<EOF
$(grep -E '^Tmpfs=' "$Q")
EOF

if [ -n "$mask" ]; then
  ok "the vault is masked at $want (the home mount's own hodd/secrets)"
else
  bad "the vault is masked at $want" "$(grep -E '^Tmpfs=' "$Q" | tr '\n' ' ')"
fi

mask_opts="${mask##*:}"                    # the option list after the path
case ",$mask_opts," in
  *,ro,*) ok "the mask is read-only" ;;
  *) bad "the mask is read-only" "$mask" ;;
esac
case "$mask_opts" in
  *size=*) ok "the mask is size-capped (an empty tmpfs, not a disk)" ;;
  *) bad "the mask is size-capped" "$mask" ;;
esac

# ── no shipped shape writes a path from an undefined variable ────────────────
# `$HOME_SEAT` was used for the container-side path until 2026-11-16 and NOTHING in this repo
# defines it: every consumer of the env file would have had to invent it. A mask spelled from an
# unset variable is a mask over "whatever that literal string is". The scan reads the config shapes
# only (a unit, a compose file, a Containerfile) — prose that explains the removal is not a fault —
# and skips comment lines, where the fault is described rather than made.
stale=""
for f in "$Q" "$C" "$ROOT"/deploy/compose/*.yaml "$ROOT"/deploy/quadlet/*.container "$ROOT"/deploy/Containerfile; do
  [ -r "$f" ] || continue
  hit=$(grep -nE '\$\{?HOME_SEAT' "$f" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' || true)
  [ -n "$hit" ] && stale="$stale
$(basename "$f"): $hit"
done
if [ -z "$stale" ]; then
  ok "no shipped deploy shape depends on the undefined \$HOME_SEAT"
else
  bad "no shipped deploy shape depends on the undefined \$HOME_SEAT" "$stale"
fi

# ── the other shipped shapes owe the same when they mount the home ───────────
compose_mounts_home=0
if [ -r "$C" ]; then
  if grep -E '^\s+-' "$C" | grep -vE '^\s*#' | grep -E ':[^:]*/(home|Users)/|%h' | grep -vE '^\s*#' | grep -q .; then
    compose_mounts_home=1
  fi
  if [ "$compose_mounts_home" = 1 ]; then
    # it must then carry an active (uncommented) tmpfs mask over that mount's hodd/secrets
    if grep -E '^\s+-' "$C" | grep -vE '^\s*#' | grep -qE '/hodd/secrets'; then
      ok "Compose mounts the home and masks the vault too"
    else
      bad "Compose mounts the home and masks the vault too" "a home mount with no hodd/secrets mask"
    fi
  else
    ok "Compose mounts only the checkout, so it never holds the vault (the template for adding a home mount is beside it)"
  fi
else
  ok "no Compose shape is shipped"
fi

printf 'container hides the hoard: %s ok / %s fail\n' "$pass" "$fail"
[ "$fail" = 0 ]
