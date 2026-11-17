#!/usr/bin/env bash
# test_plan_door_knows_where.sh — the plan door knows where it belongs (plan 311).
#
# The five proofs the plan owes, each one run against a THROWAWAY home seeded from the shape
# `hodd/AGENTS.example.md` teaches. Nothing here reads or writes the operator's real ledger:
# every case runs with YMIR_HOME pointed at a mktemp tree that the trap removes.
#
#   1 · one door files three plans into three different scopes, each index row in the same act
#   2 · a plan about the heart files onto the heart's shelf from THIS machine (--host zerwizserver)
#   3 · a project the registry does not know is refused, with the two shelves it might have meant named
#   4 · work belonging to Gimlé or to Trello is named as such instead of being filed in the ymir ledger
#   5 · a shelf carrying two pad widths is reported
#
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
P="$ROOT/bin/records/plan.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# ── the throwaway home, in the shape the home's own example teaches ──────────────
mkdir -p "$T/hodd/identity" "$T/hodd/data" "$T/hodd/plans" \
         "$T/hodd/machines/heimdall/plans" "$T/hodd/machines/zerwizserver/plans" \
         "$T/svartalfaheim/whynotproductions/projects/ymir/plans" \
         "$T/svartalfaheim/acme/projects/widget/plans"
[ -f "$ROOT/hodd/AGENTS.example.md" ] && cp "$ROOT/hodd/AGENTS.example.md" "$T/hodd/AGENTS.md"
for d in "$T/hodd/plans" "$T/hodd/machines/heimdall/plans" "$T/hodd/machines/zerwizserver/plans" \
         "$T/svartalfaheim/whynotproductions/projects/ymir/plans" "$T/svartalfaheim/acme/projects/widget/plans"; do
  printf '| # | Plan | State |\n|---|---|---|\n' > "$d/README.md"
done

# the registries the door must read — the same two the real home keeps
cat > "$T/hodd/identity/projects.yaml" <<'YAML'
projects:
- id: ymir-platform
  name: Ymir
  realm: whynotproductions
  records:
    in_home:
      plans: svartalfaheim/whynotproductions/projects/ymir/plans/
- id: widget
  name: Widget
  realm: acme
- id: gimle
  name: Gimlé
  realm: whynotproductions
YAML
cat > "$T/hodd/identity/services.yaml" <<'YAML'
version: 2
services:
- id: gate
  name: Authelia — the gate
  host: zerwizserver
- id: board
  name: Plane — the board
  host: zerwizserver
YAML
cat > "$T/hodd/data/fleet.json" <<'JSON'
{"heart": "zerwizserver", "hosts": {"heimdall": {"folder": "hodd/machines/heimdall"},
 "zerwizserver": {"folder": "hodd/machines/zerwizserver"}}}
JSON

run() { YMIR_HOME="$T" YMIR_HOARD="$T/hodd" YMIR_OFFLINE=1 YMIR_REALM=elsewhere YMIR_PROJECT=nothing \
        YMIR_HOST=heimdall bash "$P" "$@" 2>&1; }
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
row() { grep -q "$1" "$2/README.md" 2>/dev/null; }

Y="$T/svartalfaheim/whynotproductions/projects/ymir/plans"
H="$T/hodd/machines/heimdall/plans"
Z="$T/hodd/machines/zerwizserver/plans"
PR="$T/hodd/plans"
W="$T/svartalfaheim/acme/projects/widget/plans"

# ── 1 · one door, three scopes, each index row in the same act ───────────────────
out="$(run new one --title "One" --scope project --project widget)"
[ -f "$W/001-one.md" ] && row '001-one.md' "$W" \
  && ok "scope project: the plan and its index row land on the project's shelf" || bad "project scope: $out"
out="$(run new two --title "Two" --scope machine --host zerwizserver)"
[ -f "$Z/001-two.md" ] && row '001-two.md' "$Z" \
  && ok "scope machine: the plan and its index row land on the machine's shelf" || bad "machine scope: $out"
out="$(run new three --title "Three" --scope personal)"
[ -f "$PR/001-three.md" ] && row '001-three.md' "$PR" \
  && ok "scope personal: the plan and its index row land on hodd/plans/" || bad "personal scope: $out"

# ── 2 · the heart's shelf, from this machine ─────────────────────────────────────
out="$(run new heart-desk --title "The desk on the heart" --scope machine --host zerwizserver)"
[ -f "$Z/002-heart-desk.md" ] && ! ls "$H" | grep -q heart-desk \
  && ok "--host zerwizserver files it on the heart's shelf, not this machine's" || bad "the host was assumed: $out"
grep -q '^host: zerwizserver' "$Z/002-heart-desk.md" \
  && ok "the plan's header names the host it was filed for" || bad "header does not name the host: $out"
out="$(run route why-the-heart-dies --title "why the heart dies: oom, swap, kernel limits on zerwizserver")"
case "$out" in *'"machine","machine","zerwizserver"'*) ok "the router reads the host out of the words";;
  *) bad "router did not route machine work: $out";; esac
out="$(run new bad --title "Bad" --scope machine --host nosuchbox)"
case "$out" in *"no machine called nosuchbox"*"zerwizserver"*) ok "an unknown host is refused, and the fleet's names are printed";;
  *) bad "unknown host not refused by name: $out";; esac
[ -e "$T/hodd/machines/nosuchbox" ] && bad "a shelf was made for a host the fleet does not know" \
  || ok "no shelf was made for an unknown host"

# ── 3 · an unknown project is refused, and the shelves it might have meant are named ──
out="$(run new x --title "X" --project giml)"
case "$out" in *"REFUSED"*"no project folder called giml"*) ok "a project the registry does not know is refused";;
  *) bad "unknown project not refused: $out";; esac
case "$out" in *"it might have meant  gimle"*) ok "the refusal names the registry's near name (gimle)";;
  *) bad "no candidate named: $out";; esac
case "$out" in *"or the house's own ledger — svartalfaheim/whynotproductions/projects/ymir/plans"*)
  ok "the refusal names the other shelf it might have meant (the ymir ledger)";;
  *) bad "the second shelf is not named: $out";; esac
[ -e "$T/svartalfaheim/acme/projects/giml" ] && bad "a shelf was made for an unknown project" \
  || ok "nothing was filed for the refused project"

# ── 4 · Gimlé and Trello are named as such, never filed in the ymir ledger ───────
out="$(run route gimle-plans --title "where the Gimlé gate and its hosted surfaces keep their runbooks")"
case "$out" in *'"gimle"'*"a plan here would be read by nobody; open it there"*)
  ok "Gimlé's work is named as Gimlé's";; *) bad "Gimlé not named: $out";; esac
out="$(run route move-card --title "move the card to the done queue on the board")"
case "$out" in *'"card"'*"this is a card, not a plan — the board holds it"*)
  ok "a card is named as a card, not a plan";; *) bad "card not named: $out";; esac
before="$(ls "$Y" | wc -l)"
out="$(run new gimle-thing --title "the Gimlé gate and its hosted surfaces")"
case "$out" in *"REFUSED"*) ok "new refuses Gimlé's work rather than filing it here";; *) bad "Gimlé filed: $out";; esac
out="$(run new a-card --title "the card in the queue on the board")"
case "$out" in *"REFUSED"*) ok "new refuses a card rather than filing it here";; *) bad "card filed: $out";; esac
[ "$(ls "$Y" | wc -l)" = "$before" ] && ok "the ymir ledger gained nothing from either refusal" \
  || bad "the ymir ledger gained a plan from a refusal"
out="$(run new the-fleet --title "the fleet's arms and the ledger")"
[ -f "$Y/001-the-fleet.md" ] && ok "Ymir's own work still files on the ymir ledger, by the registry" || bad "ymir work misfiled: $out"

# ── 5 · one pad width per shelf, and a shelf with two shapes is reported ─────────
mkdir -p "$T/hodd/machines/omarchy/plans"
printf '| # | Plan | State |\n|---|---|---|\n' > "$T/hodd/machines/omarchy/plans/README.md"
: > "$T/hodd/machines/omarchy/plans/0002-two-shapes.md"
: > "$T/hodd/machines/omarchy/plans/005-the-other-shape.md"
out="$(run check)"; rc=$?
case "$out" in *'hodd/machines/omarchy/plans","005,0002"'*) ok "a shelf with two pad widths is reported";;
  *) bad "mixed widths not reported: $out";; esac
[ "$rc" = 1 ] && ok "check exits nonzero on a shelf with two shapes" || bad "check exit was $rc"
out="$(run check --quiet 2>/dev/null)"; true
# a shelf that already carries three digits keeps three, never gains a second shape
out="$(run new four --title "Four" --scope machine --host zerwizserver)"
[ -f "$Z/003-four.md" ] && ok "the door adopts the shelf's own pad width (003, not 0003)" || bad "pad width: $out"

exit "$fail"
