# The mic is never an online meeting

**Date:** 2026-10-31 · **Component:** snotra · **Status:** fixed in the tree, gate proven

## The law, in his words

> "The mic should NOT be used. only in local meetings if they are happening.
> otherwise NEVER!!!!!!!!!!"

And earlier the same day: *"the local mic are a extra feature. but the online
meetings are the important things for snotra"*, and *"THE MIC SHOULD NOT PIC UP
AT ALL"*.

So: **an online meeting is heard by the bot, never by the seat's microphone.** The
microphone is the LOCAL ROOM door — people physically in the room — and it is
never opened for a Meet, a Zoom or a Teams call.

## What was wrong

Nothing enforced it. Two doors opened the mic on their own:

- `bin/time/snotra/snotra-detect.sh` **armed on the microphone**: an application
  taking an input stream was the trigger, and the ear then recorded mic + sink to
  a WAV. Every online call therefore recorded the Allfather's own voice, by
  design — `do_arm` never asked what the call was.
- `bin/time/snotra/snotra-capture.sh` **was the door any caller could open**, with
  no notion of local vs online. Plan 72's live tail (`snotra-live.sh`) is
  mic-only by decision and equally unguarded.

The plans carried no such rule either: plan 72 says "microphone of this machine
only" (its own decision, 2026-10-07) and plan 87 keeps the ear "for in-room
capture and for calls that never touch a platform" — neither forbids the mic on an
online call, and the watcher contradicted both by arming on one.

## The fix — one law, three gates, no new flag to remember

`SNOTRA_LOCAL_ROOM=1` is the only way the microphone opens. Anything else refuses
and names the bot door instead:

| file | gate |
|---|---|
| `bin/time/snotra/snotra-capture.sh` | `do_start` refuses (exit 2) unless `SNOTRA_LOCAL_ROOM=1`, printing the TOON refusal and the bot door |
| `bin/time/snotra/snotra-detect.sh` | `do_arm` refuses before resolving a device, logs `arm REFUSED — the mic is for a LOCAL room only …`, returns 1 |
| `bin/time/snotra/snotra-live.sh` | `do_start` refuses (exit 2) with the same words before it touches ffmpeg |

The refusal is the *safe* direction: a refused arm costs nothing, and the online
door (`snotra-bot.sh join <url>` → the Vexa participant) is named in the message so
the next hand is pointed at the right one.

## Evidence

```
$ bin/time/snotra/snotra-capture.sh start
snotra-capture[1]{state,reason,door}:
  "refused","the mic is for a LOCAL room only — never an online meeting","bin/time/snotra/snotra-bot.sh"
hint: an online meeting is heard by the BOT (snotra-bot.sh join <meet-url>);
      capture your own room only with SNOTRA_LOCAL_ROOM=1.
exit=2

$ bin/time/snotra/snotra-live.sh start note
refused: the mic is for a LOCAL room only — never an online meeting
hint: an online meeting is heard by the BOT — snotra-bot.sh join <meet-url>
hint: tail your own room only with SNOTRA_LOCAL_ROOM=1
```

`bash -n` passes on all three. No WAV from today was found anywhere on the box
(`find ~ -name '*.wav' -newermt '-30 hours'` is empty), so there is no recording of
the Allfather's mic alone left to delete: the capture he ordered deleted either
never reached the disk or was already removed in that session. The meeting shelf
holds only `meeting.json`.

## The remaining hole (not this fix)

The bot door itself is still fragile — today's Meet held the bot in its lobby loop
(`Waiting room indicator visible — suppressing admission`), which is the subject of
plan 147 and of the Vexa authenticated-bot work (`BOT_AUTHENTICATED=true`, the
`remote-browser` provision login). Until that is solid, an online meeting has **no**
working ear — and that is the correct failure: a missing microphone is honest, a
recorded room nobody consented to is not.
