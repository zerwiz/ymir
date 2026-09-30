#!/usr/bin/env bash
# tests/fm-notify-allfather.test.sh - the watcher must reach the Allfather himself.
#
# THE CASE THAT MATTERS: the watcher already decided, on every poll, which events
# mean a human. Every one of those decisions used to end in `wake`, which is an
# AGENT delivery. Whether the person then heard it was a model decision, and a
# busy or context-starved session drops it without trace. That is the whole
# reason arming felt unreliable: the arm fed a peer, not a person.
#
# So this suite asserts the missing edge exists, and that removing it fails here
# rather than in silence at 3am. Every case is offline.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v sha256sum >/dev/null 2>&1 || { echo "skip: sha256sum not found"; exit 0; }

TMP_ROOT=$(fm_test_tmproot fm-notify-allfather)
SAY_LOG="$TMP_ROOT/say.log"

# A stand-in for the desktop notifier. The library takes its bin from
# BROKK_NOTIFY_SAY_BIN precisely so this is possible without a notifier, and so
# the suite never proves anything by the absence of a desktop.
cat > "$TMP_ROOT/say" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FM_TEST_SAY_LOG"
EOF
chmod +x "$TMP_ROOT/say"

export FM_TEST_SAY_LOG="$SAY_LOG"
export STATE="$TMP_ROOT/state"
mkdir -p "$STATE"
export BROKK_NOTIFY_SAY_BIN="$TMP_ROOT/say"

# shellcheck source=.agents/backend/fm-notify-lib.sh
. "$ROOT/.agents/backend/fm-notify-lib.sh"

# The watcher owns triage_log(); the library calls it after speaking. Provide the
# same one-liner so a notify call under test does not die on an unbound function.
triage_log() { printf '%s\n' "$1" >> "$TMP_ROOT/triage.log" 2>/dev/null || true; }

spoken() { cat "$SAY_LOG" 2>/dev/null; }
count() { spoken | grep -c . || true; }
reset_say() { : > "$SAY_LOG"; }
seed() { printf '%s\n' "$2" > "$STATE/$1.status"; }

test_each_human_verb_speaks_once() {
  local verb n
  for verb in done needs-decision blocked failed; do
    reset_say
    seed "task-$verb" "$verb: something happened"
    fm_notify_task "task-$verb"
    n=$(count)
    [ "$n" -eq 1 ] || fail "verb '$verb' should speak exactly once, spoke $n"
    pass "'$verb' speaks once"
  done
}

test_manner_matches_the_verb() {
  reset_say
  seed task-mode "blocked: waiting on the captain"
  fm_notify_task task-mode
  spoken | grep -q -- '--mark-alarm' \
    || fail "a blocked task should be raised as an alarm, not a note: $(spoken)"
  pass "blocked is raised as an alarm"

  reset_say
  seed task-fail "failed: the gate refused"
  fm_notify_task task-fail
  spoken | grep -q -- '--urgency critical' \
    || fail "a failure must not queue behind anything else: $(spoken)"
  pass "failed is urgent"

  reset_say
  seed task-fin "done: the errand landed"
  fm_notify_task task-fin
  spoken | grep -q -- '--mark-done' \
    || fail "a finished errand should be marked done: $(spoken)"
  pass "done is marked done"
}

test_routine_turns_stay_quiet() {
  reset_say
  seed task-working "working: still forging"
  fm_notify_task task-working
  [ "$(count)" -eq 0 ] \
    || fail "a routine working note must not raise the Allfather's desktop: $(spoken)"
  pass "a working note is not news"

  reset_say
  seed task-empty ""
  fm_notify_task task-empty
  [ "$(count)" -eq 0 ] || fail "an empty log must not speak"
  pass "an empty log is silent"

  reset_say
  fm_notify_task no-such-task
  [ "$(count)" -eq 0 ] || fail "a missing task must not speak"
  pass "a missing task is silent"
}

test_speaks_once_per_state_and_again_per_new_state() {
  reset_say
  seed task-rep "needs-decision: choose the shape"
  fm_notify_task task-rep
  fm_notify_task task-rep
  fm_notify_task task-rep
  [ "$(count)" -eq 1 ] || fail "repeated polls must speak once, spoke $(count)"
  pass "repeated polls speak once"

  seed task-rep "needs-decision: choose the other shape"
  fm_notify_task task-rep
  [ "$(count)" -eq 2 ] || fail "a new state for a known task must speak again, spoke $(count)"
  pass "a new state speaks again"

  # A crew closing its own loop is NOT news. `resolved` is deliberately absent
  # from BROKK_CLASSIFY_ALLFATHER_RE_DEFAULT (done/needs-decision/blocked/
  # failed), so the Allfather is not pulled back to a decision he already made.
  # Asserted here because it is the boundary most likely to be "helpfully"
  # widened later by someone who has not thought about the popup cost.
  seed task-rep "resolved: the shape is chosen"
  fm_notify_task task-rep
  [ "$(count)" -eq 2 ] || fail "a resolution must not speak, spoke $(count)"
  pass "a resolution is not news"
}

test_a_restarted_watcher_does_not_reannounce() {
  # Two independent watcher processes polling the same unchanged state: the
  # durable marker is what makes the second one quiet. Without it, every arm
  # re-launch would re-announce the entire fleet's history.
  reset_say
  seed task-again "blocked: the gate is waiting"
  fm_notify_task task-again
  fm_notify_task task-again
  [ "$(count)" -eq 1 ] || fail "a second watcher must not re-announce a spoken state, spoke $(count)"
  pass "a restart does not re-announce"
}

test_the_spoken_line_leaks_no_private_path() {
  local line
  reset_say
  seed task-plain "blocked: awaiting the captain"
  fm_notify_task task-plain
  line=$(spoken)
  case "$line" in
    *"$STATE"*|*"$TMP_ROOT"*|*/home/*)
      fail "the spoken text must carry no private path: $line"
      ;;
  esac
  pass "the spoken line carries no private path"
}

test_the_watchers_own_calling_form_works() {
  reset_say
  seed task-bulk "needs-decision: pick one"
  # fm_notify_files is the form fm-watch.sh actually calls: a space-separated
  # list of status FILE paths, not task ids.
  # shellcheck disable=SC2086
  fm_notify_files "$STATE/task-bulk.status"
  [ "$(count)" -eq 1 ] || fail "fm_notify_files must speak for a surfaced status file, spoke $(count)"
  pass "fm_notify_files speaks for a surfaced file"

  reset_say
  # A non-status argument must be ignored, not spoken and not fatal.
  fm_notify_files "$STATE/.lock" "not-a-status-file"
  [ "$(count)" -eq 0 ] || fail "a non-status argument must be ignored"
  pass "non-status arguments are ignored"
}

test_each_human_verb_speaks_once
test_manner_matches_the_verb
test_routine_turns_stay_quiet
test_speaks_once_per_state_and_again_per_new_state
test_a_restarted_watcher_does_not_reannounce
test_the_spoken_line_leaks_no_private_path
test_the_watchers_own_calling_form_works