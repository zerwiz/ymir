#!/usr/bin/env bash
# test_agnostic_audit.sh — the agnostic audit BITES, and it never publishes the list.
#
# The law it guards (plan 287 §5/§6, RULES/04 and RULES/25): the public repository is 100 % agnostic —
# it carries the operator's craft and never his life, and it never assumes his fleet. The audit reads
# its words from the operator's HOME, so this canary never touches the real list: it builds its own
# home-shaped list out of INVENTED entries and its own throwaway repository, and proves the door on
# those. Nothing here is network, nothing here is the live tree.
#
# What is proved:
#   1. a planted name FAILS the census, and the report names the file and the line;
#   2. the word itself is NEVER printed — the finding names the entry by its position (RULES/18);
#   3. a lore-style HOST is judged only where it is used as a host: in prose it passes, the same
#      word after `ssh ` or in `host=` fails (plan 278's lesson);
#   4. the generic shapes: a documentation address and a placeholder tailnet host pass, a concrete
#      private address and a real tailnet host fail;
#   5. the WARD refuses only what is NEW: a word already on the base revision prints `inherited`
#      and exits 0, while a line this change adds exits 1 (plan 243 §3 part D);
#   6. no list at all is a clean skip that SAYS SO, and the generic shapes are still judged;
#   7. `--list` describes the classes and prints no word of the list.
#
# Exit: 0 every property holds · 1 a property broke.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/gates/agnostic-audit.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/test-agnostic-audit-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail=0
ok()  { printf 'PASS: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

[ -x "$DOOR" ] || { printf 'FAIL: %s is not executable (RULES/12: a door is executable)\n' "$DOOR"; exit 1; }

# ── the invented list, shaped exactly like the home's ───────────────────────────────────────────
DENY="$TMP/public-deny.txt"
cat >"$DENY" <<'DENY'
# an invented list: this canary never reads the operator's own
name:zedplanted
host:boxplanted
domain:planted.example
DENY

# ── a throwaway repository, with one clean file ─────────────────────────────────────────────────
REPO="$TMP/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q -b main
git -C "$REPO" -c user.email=canary@example.org -c user.name=canary commit -q --allow-empty -m base
printf 'A clean line.\nAnother clean line.\n' >"$REPO/clean.md"
printf 'export const PORT = 8080\n' >"$REPO/app.ts"
git -C "$REPO" add -A
git -C "$REPO" -c user.email=canary@example.org -c user.name=canary commit -q -m "clean tree"

run() { ( cd "$REPO" && bash "$DOOR" --root "$REPO" --deny "$DENY" "$@" 2>&1 ); }

# 1 & 2 — a planted name fails the census, and the word stays in the home.
printf 'fine\n\nSindri spoke to zedplanted about it.\n' >"$REPO/planted.md"
out="$(run)"; rc=$?
[ "$rc" = 1 ] && ok "a planted name fails the census (exit 1)" || bad "a planted name did not fail the census (exit $rc)"
case "$out" in *"planted.md:3"*) ok "the finding names the file and the line" ;; *) bad "the finding did not name planted.md:3" ;; esac
case "$out" in *zedplanted*) bad "the report PRINTED the denied word (RULES/18)" ;; *) ok "the report never prints the denied word" ;; esac
case "$out" in *"home entry 1"*) ok "the finding names the entry by its position" ;; *) bad "the finding did not name the entry's position" ;; esac
rm -f "$REPO/planted.md"

# 3 — a host-kind word is judged where it is used as a host, not in prose.
printf 'the boxplanted is a nice machine\n' >"$REPO/prose.md"
run >/dev/null 2>&1 && ok "a machine name in prose is not a host (plan 278)" \
  || bad "a machine name in prose was judged a host"
printf 'ssh boxplanted uptime\n' >"$REPO/host.md"
run >/dev/null 2>&1 && bad "a machine named after ssh was not judged a host" \
  || ok "a machine named after ssh is judged a host"
rm -f "$REPO/prose.md" "$REPO/host.md"

# 4 — the generic shapes.
printf 'see 192.0.2.5 and <host>.tailnet.ts.net\n' >"$REPO/docs.md"
run >/dev/null 2>&1 && ok "a documentation address and a placeholder tailnet host pass" \
  || bad "a documentation address or a placeholder tailnet host was refused"
# A planted address must not be a literal in THIS file: the audit would — correctly — flag it here.
LAN="$(printf '192.168.%s.%s' 44 9)"
printf 'it listens on %s\n' "$LAN" >"$REPO/lan.md"
run >/dev/null 2>&1 && bad "a concrete private address passed" || ok "a concrete private address fails"
TSHOST="mybox$(printf '.')ts.net"
printf 'reach it at %s\n' "$TSHOST" >"$REPO/ts.md"
run >/dev/null 2>&1 && bad "a real tailnet host passed" || ok "a real tailnet host fails"
rm -f "$REPO/docs.md" "$REPO/lan.md" "$REPO/ts.md"

# 5 — the ward refuses only what is NEW.
printf 'already zedplanted here\n' >"$REPO/old.md"
git -C "$REPO" add old.md
git -C "$REPO" -c user.email=canary@example.org -c user.name=canary commit -q -m "a word that was here before"
out="$(cd "$REPO" && bash "$DOOR" check old.md --root "$REPO" --deny "$DENY" --base HEAD 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "a word already on the base is not this push's to fix (exit 0)" \
  || bad "a word already on the base refused the push (exit $rc)"
case "$out" in *inherited*) ok "the inherited hit says so in the report" ;; *) bad "the inherited hit was not labelled" ;; esac
printf 'already zedplanted here\nand zedplanted again\n' >"$REPO/old.md"
(cd "$REPO" && bash "$DOOR" check old.md --root "$REPO" --deny "$DENY" --base HEAD >/dev/null 2>&1) \
  && bad "a NEW line carrying the word did not refuse the push" \
  || ok "a NEW line carrying the word refuses the push"
git -C "$REPO" checkout -q -- old.md

# 6 — no list is a clean skip that says so, and the generic shapes still run.
out="$(cd "$REPO" && bash "$DOOR" --root "$REPO" --deny "$TMP/absent.txt" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "a machine with no list passes a clean tree" || bad "a machine with no list failed a clean tree (exit $rc)"
case "$out" in *"NONE READ"*) ok "the run says aloud that it read no words" ;; *) bad "the run did not say it read no words" ;; esac
LAN2="$(printf '10.%s.%s.%s' 1 2 3)"
printf 'it listens on %s\n' "$LAN2" >"$REPO/lan2.md"
(cd "$REPO" && bash "$DOOR" --root "$REPO" --deny "$TMP/absent.txt" >/dev/null 2>&1) \
  && bad "the generic shapes did not run without a list" || ok "the generic shapes still run without a list"
rm -f "$REPO/lan2.md"

# 7 — the list is a description, not a publication.
out="$(cd "$REPO" && bash "$DOOR" --root "$REPO" --deny "$DENY" --list 2>&1)"
case "$out" in *zedplanted*|*boxplanted*|*planted.example*) bad "--list printed a word of the list" ;; *) ok "--list prints no word of the list" ;; esac
case "$out" in *"3 entries"*) ok "--list reports how many entries were read" ;; *) bad "--list did not report the count" ;; esac

[ "$fail" = 0 ] && printf 'test_agnostic_audit: every property holds\n'
exit "$fail"
