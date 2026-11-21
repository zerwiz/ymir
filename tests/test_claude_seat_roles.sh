#!/usr/bin/env bash
# test_claude_seat_roles.sh — the Claude seat's permission profile is chosen by ROLE (RULES/08, 2026-11-21).
#
# Measured 2026-11-21: three judges approved PRs and were refused at the merge, because every Claude
# seat carried the worker profile, which denies `gh pr merge`. Now the judge (role forseti) is seated
# with .agents/harnesses/claude-judge.settings.json: the merge DOOR is allowed and raw merge is still
# denied, so the door's checks cannot be skipped. Every other role keeps the worker profile, which
# refuses both. This test holds:
#   1. the profile chosen for each role, by every road (claude_seat.py, claude-seat.sh, harness.py)
#   2. what each profile decides for a set of commands, with Claude Code's rule order (deny wins)
#   3. the two profiles differ ONLY in the merge door (env and every other rule stay in step)
#   4. the wiring: herdr-run.sh passes the role, the review spawn seats the judge as forseti,
#      einherjar-spawn.sh takes --role and records it
#   5. the door's own refusals (red, pending, moved head, hold) — the door's suite, when it is here
#
# Run: bash tests/test_claude_seat_roles.sh   ·   exit 0 all pass, 1 a failure.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }
WORKER="$ROOT/.agents/harnesses/claude-worker.settings.json"
JUDGE="$ROOT/.agents/harnesses/claude-judge.settings.json"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
unset YMIR_SEAT_ROLE

# ── 1. the profile, by role, by every road ─────────────────────────────────────────────────────
for pair in "forseti:$JUDGE" "FORSETI:$JUDGE" "sindri:$WORKER" ":$WORKER" "bragi:$WORKER"; do
  role="${pair%%:*}"; want="${pair#*:}"
  got="$(python3 "$ROOT/src/ymir_runtime/claude_seat.py" profile "$ROOT" "$role")"
  [ "$got" = "$want" ] && ok "claude_seat.py: role '${role:-none}' -> $(basename "$want")" || bad "claude_seat.py role '$role' gave $got"
  got="$("$ROOT/bin/seat/claude-seat.sh" profile "$role")"
  [ "$got" = "$want" ] && ok "claude-seat.sh: role '${role:-none}' -> $(basename "$want")" || bad "claude-seat.sh role '$role' gave $got"
done
got="$(YMIR_SEAT_ROLE=forseti "$ROOT/bin/seat/claude-seat.sh" profile)"
[ "$got" = "$WORKER" ] && ok "an inherited YMIR_SEAT_ROLE=forseti never chooses the judge's profile" || bad "env role gave $got"

"$ROOT/bin/seat/claude-seat.sh" settings "$TMP" "$TMP/judge.json" forseti >/dev/null 2>&1 \
  && grep -q 'judge-merge.sh' "$TMP/judge.json" && ok "settings <cwd> <out> forseti writes the judge's door into the seat" \
  || bad "settings for forseti did not carry the door"
"$ROOT/bin/seat/claude-seat.sh" args "$TMP" sonnet "$TMP/worker.json" sindri >/dev/null 2>&1 \
  && python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))["permissions"]; sys.exit(0 if not any("judge-merge.sh" in r for r in d["allow"]) else 1)' "$TMP/worker.json" \
  && ok "args … sindri writes the worker's profile (no door in its allow list)" || bad "args for a worker carried the door"

py_out="$(cd "$ROOT/src" && python3 - <<'PY'
from ymir_runtime import harness
print(harness.claude_worker_profile(None, "forseti").name)
print(harness.claude_worker_profile(None, "sindri").name)
print(harness.claude_worker_profile(None).name)
PY
)"
[ "$py_out" = $'claude-judge.settings.json\nclaude-worker.settings.json\nclaude-worker.settings.json' ] \
  && ok "harness.py chooses the same profile by role" || bad "harness.py: $py_out"

mkdir -p "$TMP/tree/.agents/harnesses"; cp "$WORKER" "$TMP/tree/.agents/harnesses/"
if python3 "$ROOT/src/ymir_runtime/claude_seat.py" profile "$TMP/tree" forseti >/dev/null 2>&1; then
  bad "a judge with no judge profile was given one (it must be refused, never handed the worker's)"
else
  ok "a judge whose profile is missing is refused, never quietly seated as a worker"
fi

# ── 2 + 3. what each profile decides (Claude Code: deny wins, then allow; dontAsk denies the rest) ──
python3 - "$WORKER" "$JUDGE" <<'PY' && ok "the decisions table and the in-step check hold (see above)" || bad "the decisions table or the in-step check failed (see above)"
import fnmatch, json, sys

def rule_matches(rule, cmd):
    if rule == "Bash":
        return True
    if not (rule.startswith("Bash(") and rule.endswith(")")):
        return False
    pat = rule[5:-1]
    if pat.endswith(":*") and "*" not in pat[:-2]:
        return cmd == pat[:-2] or cmd.startswith(pat[:-2] + " ") or cmd.startswith(pat[:-2])
    return fnmatch.fnmatchcase(cmd, pat.replace(":*", "*"))

def decide(profile, cmd):
    p = profile["permissions"]
    if any(rule_matches(r, cmd) for r in p["deny"]):
        return "deny"
    if any(rule_matches(r, cmd) for r in p["allow"]):
        return "allow"
    return "deny"

worker, judge = (json.load(open(f)) for f in sys.argv[1:3])
door = [
    "bin/forge/judge-merge.sh act pr-12-review",
    "./bin/forge/judge-merge.sh act pr-12-review",
    "bash bin/forge/judge-merge.sh act pr-12-review",
    "bin/agents/pr-seal.sh seal 12 --repo owner/repo --head " + "a" * 40,
]
raw = [
    "gh pr merge 12 --squash",
    "gh pr merge 12 -R owner/repo --merge --admin",
    "cd x && gh pr merge 12",
    "gh api -X PUT repos/owner/repo/pulls/12/merge",
    "gh -R owner/repo pr merge 12 --squash",
    "gh --repo owner/repo pr merge 12",
    "gh --repo=owner/repo pr merge 12",
    "gh api graphql -f query='mutation{mergePullRequest(input:{pullRequestId:\"x\"}){clientMutationId}}'",
    "gh api graphql -f query='mutation{mergeBranch(input:{}){clientMutationId}}'",
    "git merge origin/feature",
    "git push origin main",
    "git push --force origin eindri/x",
]
plain = ["git status --short", "gh pr view 12 --json state", "git diff origin/main...HEAD"]
fails = 0
def expect(name, profile, cmds, want):
    global fails
    for c in cmds:
        got = decide(profile, c)
        mark = "ok  " if got == want else "FAIL"
        if got != want:
            fails += 1
        print(f"  {mark} {name}: {c!r} -> {got} (want {want})")
expect("judge ", judge, door, "allow")
expect("judge ", judge, raw, "deny")
expect("judge ", judge, plain, "allow")
expect("worker", worker, door, "deny")
expect("worker", worker, raw, "deny")
expect("worker", worker, plain, "allow")

# in step: the judge is the worker with ONLY the door moved from deny to allow
door_rule = lambda r: "judge-merge.sh" in r or "pr-seal.sh seal" in r
if worker["env"] != judge["env"]:
    print("  FAIL the two profiles' env differ"); fails += 1
w_allow = [r for r in worker["permissions"]["allow"]]
j_allow = [r for r in judge["permissions"]["allow"] if not door_rule(r)]
w_deny = [r for r in worker["permissions"]["deny"] if not door_rule(r)]
j_deny = judge["permissions"]["deny"]
if w_allow != j_allow:
    print(f"  FAIL allow lists differ beyond the door: {set(w_allow) ^ set(j_allow)}"); fails += 1
if w_deny != j_deny:
    print(f"  FAIL deny lists differ beyond the door: {set(w_deny) ^ set(j_deny)}"); fails += 1
if any(door_rule(r) for r in j_deny):
    print("  FAIL the judge's profile denies its own door"); fails += 1
for must in ("Bash(gh pr merge:*)", "Bash(git merge:*)", "Bash(git push origin main:*)", "Agent", "Task"):
    if must not in j_deny:
        print(f"  FAIL the judge's profile lost {must}"); fails += 1
sys.exit(1 if fails else 0)
PY

# ── 4. the wiring ──────────────────────────────────────────────────────────────────────────────
# herdr-run.sh: ONLY an explicit --role chooses the profile. The role guessed from the brief maps
# "check", "ship" and "pr" to forseti (the judge's review of #870), and must never open the door.
grep -q 'claude-seat.sh" args "$SEAT_CWD" "$CLAUDE_MODEL" "$brief_dir/$NAME.claude-settings.json" "${ROLE_EXPLICIT:-}"' "$ROOT/bin/seat/herdr-run.sh" \
  && ok "herdr-run.sh hands only the EXPLICIT role to the profile chooser" || bad "herdr-run.sh does not pass the explicit role"
n_set="$(grep -c 'ROLE_EXPLICIT=\${' "$ROOT/bin/seat/herdr-run.sh")"
[ "$n_set" = 2 ] && grep -q -- '--role) ROLE=${2-}; ROLE_EXPLICIT=${2-}' "$ROOT/bin/seat/herdr-run.sh" \
  && ok "ROLE_EXPLICIT is set only by --role / --role= (the guess never writes it)" || bad "ROLE_EXPLICIT is written $n_set times"
guess="$("$ROOT/bin/agents/eindri-role.sh" choose "fix the broken gate check and ship the PR" 2>/dev/null | sed -n '2p' | sed -E 's/^ *"([^"]+)".*/\1/')"
got="$("$ROOT/bin/seat/claude-seat.sh" profile "")"
if [ "$guess" = forseti ] && [ "$got" = "$WORKER" ]; then
  ok "a coder brief guessed as '$guess' with no --role is seated with the worker profile"
elif [ "$guess" != forseti ]; then
  ok "the brief guessed '$guess'; with no --role the seat is the worker profile either way"
else
  bad "no explicit role gave $got"
fi
grep -q -- '--effort "$EFFORT" --role forseti )' "$ROOT/bin/agents/eindri-review-spawn.sh" \
  && grep -q -- '--effort $EFFORT --role forseti"' "$ROOT/bin/agents/eindri-review-spawn.sh" \
  && ok "the review spawn seats the judge as role forseti (the spawn and its printed line agree)" || bad "review spawn lacks --role forseti"

# einherjar-spawn.sh: --role parses, a bad role is refused, and the claude launch picks the judge's profile
out="$("$ROOT/bin/agents/einherjar-spawn.sh" x-review proj --scout --role 'a b' 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q -- '--role takes a figure name' \
  && ok "einherjar-spawn.sh refuses a role that is not a figure name" || bad "bad role not refused (rc=$rc): $out"
fn="$(sed -n '/^build_launch_command() {/,/^}/p' "$ROOT/bin/agents/einherjar-spawn.sh")"
shape="$(ROOT="$ROOT" HARNESS=claude MODEL=opus SEAT_ROLE=forseti bash -c "shell_quote() { printf \"'%s'\" \"\$1\"; }; $fn; build_launch_command /d/brief.md" 2>&1)"
printf '%s' "$shape" | grep -q 'claude-judge.settings.json' \
  && ok "einherjar-spawn.sh's claude launch carries the judge's profile for --role forseti" || bad "einherjar claude shape: $shape"
shape="$(ROOT="$ROOT" HARNESS=claude MODEL=opus SEAT_ROLE= bash -c "shell_quote() { printf \"'%s'\" \"\$1\"; }; $fn; build_launch_command /d/brief.md" 2>&1)"
printf '%s' "$shape" | grep -q 'claude-worker.settings.json' \
  && ok "einherjar-spawn.sh's claude launch carries the worker's profile with no role" || bad "einherjar claude shape: $shape"
grep -q '^SEAT_ROLE=$' "$ROOT/bin/agents/einherjar-spawn.sh" && ! grep -q 'export YMIR_SEAT_ROLE' "$ROOT/bin/agents/einherjar-spawn.sh" \
  && ok "einherjar-spawn.sh neither inherits nor exports a role" || bad "einherjar-spawn.sh inherits or exports YMIR_SEAT_ROLE"
grep -q "printf 'role=%s" "$ROOT/bin/agents/einherjar-spawn.sh" && grep -q 'SEAT_ROLE=$(meta_value "$META" role)' "$ROOT/bin/agents/einherjar-spawn.sh" \
  && ok "the role is recorded in the task record and a relaunch keeps it" || bad "role not recorded / not read on relaunch"
grep -q 'bin/forge/judge-merge.sh act {{REVIEW_ID}}' "$ROOT/.agents/assets/templates/review-brief.template.md" \
  && grep -qi 'denies raw `gh pr merge`' "$ROOT/.agents/assets/templates/review-brief.template.md" \
  && ok "the review brief teaches the door and names raw merge as refused" || bad "the review brief does not teach the door"

# ── 5. the door's own refusals ─────────────────────────────────────────────────────────────────
DOOR_SUITE="$ROOT/bin/forge/tests/test_judge_merge.sh"
if [ -f "$DOOR_SUITE" ]; then
  if dout="$(timeout 600 bash "$DOOR_SUITE" 2>&1)"; then
    ok "the door refuses red, pending, moved head and hold, and merges inside the judge's own seat ($(printf '%s' "$dout" | tail -1))"
  else
    bad "the door's suite failed: $(printf '%s' "$dout" | tail -5)"
  fi
else
  printf 'note the door (bin/forge/judge-merge.sh + pr-seal.sh seal --repo --head) is built by errand judge-merges (#863); its refusals are proven by %s once it lands\n' "${DOOR_SUITE#$ROOT/}"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
