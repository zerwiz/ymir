## voice · 2026-11-17 — only a session that can speak may hold an arm

### What was wrong

On 2026-11-17 the heart's arm read `held` all morning while every `pi` on that machine was dead. The holder was `ymir_runtime watch run` — a supervisor with no model behind it. A tell was handed to it and nothing answered, because the thing holding the arm cannot speak.

The fault was not the arm. It was that nothing in the house said what **"a session that can speak"** means, so two doors were about to invent two definitions.

### What the door does now

`bin/voice/rodd-arm.sh hold` refuses a claimant that cannot speak, before it touches the lock, and prints the reason. The refusal is the first law of the arm: *only a session that can speak may hold an arm*.

The definition is one function in one place — `speaks_probe` in `bin/voice/arm-speak-lib.sh`:

- the pid asked about must itself be a live harness (`pi`, `opencode`, `claude`, `cursor`, `codex`, `grok`, `kimi`, `muse`, `hermes`), so a watcher is refused by name;
- that harness must have written its own transcript within `YMIR_SPEAK_MAX_AGE` seconds (default 1800) — the live model heartbeat;
- the proof is named: `transcript:cwd` for a harness that keys its transcripts by session directory (`pi`, `claude`), `transcript:harness` where the shelf is not keyed by path (borrowed, and it says so);
- a harness with no known transcript shelf is refused, naming the row to add.

`rodd-arm.sh speaks [<pid>]` asks the same question aloud, so a caller need not re-derive it.

### Files

- `bin/voice/arm-speak-lib.sh` (new — the one definition)
- `bin/voice/rodd-arm.sh` (the `hold` clause, the `speaks` verb, the usage lines)
- `bin/voice/tests/test_arm_speaks.sh` (new)
- `bin/voice/tests/test_rodd_arm.sh` (the hold cases now carry a stand-in harness)

## CHANGE LOG

- **2026-11-17** — Opened: `hold` refuses a holder that cannot speak; the definition lives in one library, so the heart's own guard and this door cannot drift.
