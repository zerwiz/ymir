#!/usr/bin/env bash
# test_main_red.sh — the alarm BITES, and it stays quiet where it must.
#
# The fault this guards (plan 243 §2): the gate on `main` was red for four consecutive commits
# and nothing in the house said so. A red main is survivable; a SILENT one is not, because every
# hand then pushes into it and every push fails for drift it did not cause.
#
# What is proved here, with no network at all:
#   1. a red log produces ONE issue whose title names the failing gate and whose body quotes the
#      ward's own finding — and the commit attribution runs without exploding;
#   2. a green log produces NOTHING (exit 1, no issue);
#   3. with no token the alarm says `unavailable` and NEVER calls `gh` — a half-wired door must
#      not silently invent an issue, and it must not silently pretend it filed one;
#   4. `close` does nothing (and says so) when main is green and nothing was open;
#   5. the workflow opens an issue for MAIN ONLY — a red pull request opens nothing.
#
# Exit: 0 every property holds · 1 a property broke.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 1
DOOR="$ROOT/bin/gates/main-red.sh"
WF="$ROOT/.github/workflows/ymir-gates.yml"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/test-main-red-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail=0
ok()   { printf 'PASS: %s\n' "$1"; }
bad()  { printf 'FAIL: %s\n' "$1"; fail=1; }

[ -x "$DOOR" ] || { printf 'FAIL: %s is not executable (RULES/12: a door is executable)\n' "$DOOR"; exit 1; }

# A log shaped exactly like the run that was red on 2026-11-11 — TOON rows, the gate's tail
# under its own row, PASS rows around them.
cat > "$TMP/red.log" <<'LOG'
ci_verify[4]{gate,status,detail}:
  "ward","PASS","the tree wards (runtime, defaults)"
  "weave","FAIL","every index names every rule, plan and feature page (plan 175)"
    features: broken-register.md is not catalogued
    weave: 3 drift(s)
  "inventory","FAIL","the bin/backend index is current"
    inventory --check: bin/gates/INDEX.md is STALE — run bin/gates/inventory.sh
  "workflows","PASS","every Actions workflow parses"
    guards[32]{ward,status,finding}:
      "weave-guard.sh","FAIL","weave-guard: 3 unindexed feature page(s) — see bin/records/weave.sh --check"
      "inventory-guard.sh","PASS",""
LOG

cat > "$TMP/green.log" <<'LOG'
ci_verify[4]{gate,status,detail}:
  "ward","PASS","the tree wards (runtime, defaults)"
  "weave","PASS","every index names every rule, plan and feature page (plan 175)"
  "workflows","PASS","every Actions workflow parses"
LOG

# ---- 1. a red log names the gate and quotes the ward -------------------------------------
if out="$(bash "$DOOR" report --log "$TMP/red.log" 2>&1)"; then
  case "$out" in
    *"title: main is red: weave"*) ok "the title names the first failing gate" ;;
    *) bad "the title does not name the failing gate: $(printf '%s' "$out" | head -1)" ;;
  esac
  case "$out" in
    *"bin/gates/INDEX.md is STALE"*) ok "the body quotes the gate's own finding, with the file" ;;
    *) bad "the body dropped the finding — a red main with no reason is the fault this door closes" ;;
  esac
  case "$out" in
    *"weave-guard.sh"*) ok "the failing WARD is carried, not only the gate" ;;
    *) bad "the failing ward is missing from the body" ;;
  esac
  case "$out" in
    *"## Who broke it"*) ok "the body attributes the commit" ;;
    *) bad "the body has no attribution section" ;;
  esac
  case "$out" in
    *"main-red"*) ok "the body names the label that owns the issue" ;;
    *) bad "the body does not name the main-red label" ;;
  esac
else
  bad "report exited non-zero on a red log: $(printf '%s' "$out" | tail -2)"
fi

# ---- 2. a green log files nothing --------------------------------------------------------
if out="$(bash "$DOOR" report --log "$TMP/green.log" 2>&1)"; then
  bad "report exited 0 on a GREEN log — it would file an issue for a healthy main"
else
  case "$out" in
    *"no FAIL row"*) ok "a green log files nothing, and says why" ;;
    *) bad "a green log said something other than 'no FAIL row': $out" ;;
  esac
fi

# ---- 3. no token: unavailable, and gh is NEVER called ------------------------------------
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_MARKER"
exit 0
GH
chmod +x "$TMP/bin/gh"
export GH_MARKER="$TMP/gh-called"
if out="$(PATH="$TMP/bin:$PATH" GH_TOKEN= GITHUB_TOKEN= bash "$DOOR" open --log "$TMP/red.log" 2>&1)"; then
  bad "open exited 0 with no token — it claims to have filed an issue it could not file"
else
  rc=$?
  if [ "$rc" -eq 3 ]; then ok "open with no token exits 3 (unavailable)"; else bad "open with no token exited $rc, expected 3"; fi
  case "$out" in
    *unavailable*) ok "open with no token says 'unavailable'" ;;
    *) bad "open with no token did not say 'unavailable': $out" ;;
  esac
fi
if [ -e "$GH_MARKER" ]; then bad "open called gh without a token"; else ok "open never called gh without a token"; fi

# ---- 4. green main with nothing open: close is a no-op that says so ----------------------
cat > "$TMP/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$*" in
  "issue list "*) printf ''; exit 0 ;;
esac
printf '%s\n' "$*" >> "$GH_MARKER"
exit 0
GH
chmod +x "$TMP/bin/gh"
rm -f "$GH_MARKER"
if out="$(PATH="$TMP/bin:$PATH" GH_TOKEN=fake bash "$DOOR" close --sha 0123456789abcdef 2>&1)"; then
  case "$out" in
    *"nothing to close"*) ok "close on a green main with nothing open is a clean no-op" ;;
    *) bad "close on a green main said: $out" ;;
  esac
else
  bad "close exited non-zero when nothing was open"
fi

# ---- 5. issues are opened for MAIN only --------------------------------------------------
if [ -r "$WF" ]; then
  opens="$(grep -c 'main-red.sh open' "$WF" || true)"
  mainguard="$(grep -c "github.ref == 'refs/heads/main'" "$WF" || true)"
  onpushmain="$(grep -c 'steps.gate.outcome == .failure. && github.event_name == .push.' "$WF" || true)"
  if [ "${opens:-0}" -eq 1 ] && [ "${mainguard:-0}" -ge 1 ] && [ "${onpushmain:-0}" -ge 1 ]; then
    ok "the workflow opens exactly one issue, guarded on a main push"
  else
    bad "the workflow's main-red guard is not exact (open calls=$opens, main guards=$mainguard, push guard=$onpushmain)"
  fi
  if grep -qE "pull_request.*main-red\.sh open|main-red\.sh open.*pull_request" "$WF"; then
    bad "a pull request can open a main-red issue"
  else
    ok "a red pull request opens no issue"
  fi
else
  bad "the workflow is missing: $WF"
fi

# ---- 6. the run page carries the verdict -------------------------------------------------
if out="$(bash "$DOOR" summary --log "$TMP/red.log" 2>&1)"; then
  case "$out" in
    *"**RED**"*weave*) ok "summary says RED and names the failing gate, for the run page" ;;
    *) bad "summary did not name the failing gate" ;;
  esac
else
  bad "summary exited non-zero"
fi

[ "$fail" -eq 0 ] || { printf 'test_main_red: a property broke\n' >&2; exit 1; }
printf 'test_main_red: the alarm bites where it must and is silent where it must\n'
