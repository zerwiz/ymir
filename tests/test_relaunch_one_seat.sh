#!/usr/bin/env bash
# test_relaunch_one_seat.sh — a relaunch never opens a second pane beside the errand's seat.
#
# 2026-11-12: the spawner's one-agent guard asked `herdr agent-status`, a verb herdr does not
# have, so it never refused, and a relaunch put a second worker into two live worktrees
# (w5W beside w5K, w5X beside w5M). The guard now reads `herdr pane list`. A fake `herdr` on
# PATH answers with one pane in the errand's worktree, in four states:
#
#   working agent         → refused (exit 3)
#   idle agent            → refused (exit 3) unless FORCE_RELAUNCH=1
#   bare shell            → the plan reuses that pane (no second pane)
#   no pane at all        → the plan proceeds (a fresh seat)
#
# Runs with --dry-run, so nothing is created. Needs claude on PATH (the harness that needs no
# catalogue); without it the test is a clean skip. Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SPAWN="$ROOT/bin/agents/einherjar-spawn.sh"
if ! command -v claude >/dev/null 2>&1 || [ ! -f "$ROOT/.agents/harnesses/claude-worker.settings.json" ]; then
  printf 'skip  relaunch one seat (claude or its worker profile is absent)\n'; exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-relaunch.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
ID=relaunchtest
export YMIR_HOME="$TMP/home"
export YMIR_SETTINGS_DIR="$TMP/home/config"
export BROKK_STATE_OVERRIDE="$TMP/state"
export BROKK_DATA_OVERRIDE="$TMP/home/data"
export BROKK_CONFIG_OVERRIDE="$TMP/home/config"
unset YMIR_STATE_DIR FORCE_RELAUNCH
WT="$TMP/wt"
mkdir -p "$YMIR_SETTINGS_DIR" "$BROKK_STATE_OVERRIDE" "$BROKK_DATA_OVERRIDE/$ID" "$WT" "$TMP/bin"
printf 'version: 1\nallow: [claude/claude-opus-5-5]\ndefaults: {claude: claude-opus-5-5}\ngrants: []\n' \
  >"$YMIR_SETTINGS_DIR/models-allowed.yaml"
printf '# Task\n\nPrint seated.\n\nIsolation: herdr — the test raises nothing\n' >"$BROKK_DATA_OVERRIDE/$ID/brief.md"
printf 'id=%s\nkind=scout\nharness=claude\nraw_launch=\nmodel=claude-opus-5-5\nworktree=%s\nproject=%s\n' \
  "$ID" "$WT" "$ROOT" >"$BROKK_STATE_OVERRIDE/$ID.meta"

# the fake herdr: `pane list` answers from $FAKE_PANES; every other verb is a no-op
cat >"$TMP/bin/herdr" <<'SH'
#!/usr/bin/env bash
if [ "${1-}" = pane ] && [ "${2-}" = list ]; then
  printf '{"id":"cli:pane:list","result":{"panes":[%s],"type":"pane_list"}}\n' "${FAKE_PANES:-}"
fi
exit 0
SH
chmod +x "$TMP/bin/herdr"
export PATH="$TMP/bin:$PATH"

pane() {  # <agent|-> <status>
  local agent=""
  [ "$1" != - ] && agent="\"agent\":\"$1\","
  printf '{%s"agent_status":"%s","cwd":"%s","foreground_cwd":"%s","pane_id":"w9:p1","workspace_id":"w9"}' "$agent" "$2" "$WT" "$WT"
}
run() { "$SPAWN" "$ID" --relaunch --dry-run --backend tmux 2>&1; }

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$(printf '%s' "$2" | head -3 | tr '\n' ' ')"; }

out="$(FAKE_PANES="$(pane claude working)" run)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'an agent is working' && ok "a working seat refuses the relaunch" || bad "a working seat refuses the relaunch" "$out"

out="$(FAKE_PANES="$(pane claude idle)" run)"; rc=$?
[ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'still has its seat w9:p1' && ok "an idle seat refuses without FORCE_RELAUNCH" || bad "an idle seat refuses without FORCE_RELAUNCH" "$out"

out="$(FORCE_RELAUNCH=1 FAKE_PANES="$(pane claude idle)" run)"; rc=$?
[ "$rc" = 0 ] && ok "FORCE_RELAUNCH replaces an idle seat" || bad "FORCE_RELAUNCH replaces an idle seat" "$out"

out="$(FAKE_PANES="$(pane - unknown)" run)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'seat: reuses w9:p1' && ok "a bare shell seat is reused, no second pane" || bad "a bare shell seat is reused, no second pane" "$out"

out="$(FAKE_PANES="" run)"; rc=$?
[ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q 'seat: reuses' && ok "no seat left: a fresh one is planned" || bad "no seat left: a fresh one is planned" "$out"

printf '\nrelaunch-one-seat: %s ok · %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
