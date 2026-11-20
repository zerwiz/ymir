#!/usr/bin/env bash
# The mocks gate's probe — proving it BITES and that it only excuses vocabulary.
#
# The defect this test exists for: the mocks row in `compliance-check.sh` was an inline pipeline with no test,
# so every exclusion it grew arrived as a false red on legitimate code (a filename, a tool's NAME, a kind
# vocabulary, a refusal string) and each was judged by eye. A gate that cannot be tested drifts into either a
# decoration or a nuisance. This proves both halves in one run:
#
#   · a real stub in shipped code is CAUGHT, and the gate exits non-zero;
#   · the excused shapes — a comment, `PUBLIC=`, the KIND list, the `consumer:`/`todo:` pair, Pi's own tool
#     names in the two ymir-mcp doors, a `todo.md` path, and the advantage audit's own vocabulary — are
#     excused, and the gate exits zero;
#   · and the excuses are NARROW: a lone `todo`, a stub in a file that merely resembles the mcp doors, and a
#     `placeholder` in an ordinary door are all still caught.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCAN="$ROOT/.agents/skills/galdr-ymirsystem/scripts/mocks-scan.sh"

fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

[ -x "$SCAN" ] || [ -f "$SCAN" ] || { bad "the scanner is missing at $SCAN"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/clean/bin/seat" "$TMP/clean/bin/mcp" "$TMP/clean/bin/door" "$TMP/clean/bin/collab/kit/scripts" \
         "$TMP/stub/bin/door" "$TMP/narrow/bin/seat" "$TMP/narrow/bin/door"

# ── the excused shapes: every one of these is legitimate, and none may be reported ───────────────
cat > "$TMP/clean/bin/door/legit.sh" <<'SH'
#!/usr/bin/env bash
# this header may say it: the shape invited a placeholder once, and the guard now refuses it
PUBLIC=1
kinds="seeded · stub · defaulted · optional · generated"
# consumer: the smithy   todo: §3
SH
printf 'def todo(action="list"):\n    return "no todo here"\n' > "$TMP/clean/bin/seat/ymir-mcp.py"
printf 'def todo(action="list"):\n    return "no todo here"\n' > "$TMP/clean/bin/mcp/ymir-mcp.py"
printf 'HIS_FILE = Path("hodd/life/personal/me/todo.md")\n' > "$TMP/clean/bin/door/day.py"
printf 'return "PLACEHOLDER", "a placeholder is not evidence"\n' > "$TMP/clean/bin/collab/kit/scripts/advantage-audit.sh"
if bash "$SCAN" "$TMP/clean" >/dev/null 2>&1; then
  ok "the excused shapes pass (comment · PUBLIC= · kind list · consumer/todo pair · mcp names · todo.md · audit vocabulary)"
else
  bad "the scan reported a legitimate shape: $(bash "$SCAN" "$TMP/clean" 2>&1 | head -n1)"
fi

# ── a real stub: caught ─────────────────────────────────────────────────────────────────────────
printf 'def handler():\n    return "stub - the real work is not here"\n' > "$TMP/stub/bin/door/half.py"
if bash "$SCAN" "$TMP/stub" >/dev/null 2>&1; then
  bad "a real stub was NOT caught"
else
  ok "a real stub is caught (and the gate exits non-zero)"
fi

# ── a DECLARED FIXTURE is excused, and a stub beside it is not ───────────────────────────────────
    # bin/seat/tests/test_seat_reap.sh stands a `herdr` in a temp dir so the seat CLOSER can be
    # proved without touching a live workspace. The scan names that one file; a `stub` in the
    # directory NEXT to it must still be caught, or the excuse has become a hole.
mkdir -p "$TMP/fixture/bin/seat/tests" "$TMP/fixture/bin/door"
printf 'export STUB_DIR="$T/stub"; # the fixture herdr answers from here\n' > "$TMP/fixture/bin/seat/tests/test_seat_reap.sh"
if bash "$SCAN" "$TMP/fixture" >/dev/null 2>&1; then
  ok "a declared fixture (bin/seat/tests/test_seat_reap.sh) is excused"
else
  bad "the declared fixture was reported: $(bash "$SCAN" "$TMP/fixture" 2>&1 | head -n1)"
fi
printf 'handler = "stub"\n' > "$TMP/fixture/bin/door/neighbour.sh"
if bash "$SCAN" "$TMP/fixture" >/dev/null 2>&1; then
  bad "the fixture excuse leaked: a stub beside it was not caught"
else
  ok "the fixture excuse stays narrow: a stub in the same tree is still caught"
fi

# ── the excuses are narrow ──────────────────────────────────────────────────────────────────────
printf 'x = "todo"\n' > "$TMP/narrow/bin/door/lone.py"
printf 'def todo(action="list"):\n    pass\n' > "$TMP/narrow/bin/seat/ymir-mcp-extra.py"
printf 'msg = "a placeholder value"\n' > "$TMP/narrow/bin/door/other.sh"
caught="$(bash "$SCAN" "$TMP/narrow" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$caught" = "3" ]; then
  ok "the excuses stay narrow: a lone todo, a look-alike door and an ordinary placeholder are all caught"
else
  bad "the excuses leaked: expected 3 findings, got $caught"
fi

# ── the live tree: this very checkout must be clean by its own gate ─────────────────────────────
if bash "$SCAN" "$ROOT" >/dev/null 2>&1; then
  ok "the shipped tree passes its own scan"
else
  bad "the shipped tree fails its own scan: $(bash "$SCAN" "$ROOT" 2>/dev/null | head -n1)"
fi

exit "$fail"
