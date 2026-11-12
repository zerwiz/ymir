# harness · 2026-11-12 — the global Claude arm is opt-in

## Files
- `bin/seat/harness-extensions-install.sh`: `claude-ymir-arm` is seated only when `YMIR_CLAUDE_GLOBAL_ARM=1` or `$YMIR_HOME/config/claude-global-arm` reads `on`; otherwise it reports `opt-in`, never `stale`
- `bin/agents/eir-doctor.sh`: the `claudehooks` detail names the opt-in
- `.agents/migrations/0021-the-claude-hooks.sh`: its closing line says what it seated
- `docs/features/the-well-door-for-every-harness.md`: how to opt in, appended
- `bin/seat/tests/test_claude_global_arm_opt_in.sh`: the regression test

## Why
`ymir-arm.sh` is a user-scope `asyncRewake` Stop hook. Once seated, it wakes **every** Claude Code session on the
machine, in every repository and with whatever permissions that session holds. The wake tells the session to
act on the wake queue.

The hook itself prints only a short signal, such as `signal: wake queue`. The queue it points at holds lines from
several writers, and one of them is Gná, which writes lines derived from inbound mail. A woken session reading
that queue is therefore reading text that anyone able to send the operator an email can influence. That is an
indirect prompt-injection path into sessions that may be running with broad, auto-approved permissions, including
sessions inside client repositories.

Inside the Ymir repository, the project's own `.claude/settings.json` arms the session anyway. The global hook
only adds reach into every other project.

## Fix
- **Opt-in.** The installer adds the Stop entry only when the operator asks, with `YMIR_CLAUDE_GLOBAL_ARM=1` or
  `printf 'on\n' > "$YMIR_HOME/config/claude-global-arm"`.
- **Eir stays green.** An absent arm reports `opt-in`, which Eir's `claudehooks` surface does not count as stale.
- **Nothing is removed.** An entry the operator already has is left exactly as it is.

The AGENTS.md loader, the Eindri-only ward and the NDA-write ward are seated as before.

> [!NOTE]
> A follow-up worth doing: make the mail lines in the wake queue signals only (a count and a message id), so even
> an opted-in session never reads mail-derived text as part of a wake.

## Verified
- `bash bin/seat/tests/test_claude_global_arm_opt_in.sh`: 7/7 checks pass. The default seats no arm, `--check`
  reads `opt-in` and never `stale`, the env and the config file each seat it, and an existing entry is left alone.
- `bash bin/seat/tests/test_everything_up.sh`: 28 passed, 0 failed.
- `bash bin/seat/tests/test_arm_pin.sh`: 14 passed, 0 failed.

## CHANGE LOG

- **2026-11-12** — note written with the fix.
