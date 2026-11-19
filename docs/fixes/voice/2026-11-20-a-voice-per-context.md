# A voice per context, and Rödd changes voice when asked

**Date:** 2026-11-20 · **Component:** voice · **Plan:** 326.3

## What was wrong

The voices door could list and resolve every Kokoro voice, but nothing chose one. Rödd's window forced any voice
outside four English prefixes back to `af_nicole`. The voice she answered in could change only by hand in Settings.

## What changed

- `bin/voice/voices.sh choose <context> <voice>` keeps a voice for a context: `default`, `rodd`, `snotra`, or
  `person.<name>`. The choice is checked against the pack, and an unknown name is refused by name. Choices live in
  the home at `config/voices.yaml`.
- `voices.sh for <context>` answers in order: the context, then `default`, then the engine's own configured voice.
- The door reads the generated catalogue in the home when it is at least as new as the pack. Resolving went from
  4.7 s to 0.12 s. A newer pack makes the catalogue stale, and then the engine is asked.
- Two new hands in the toolbox: `voice_list` and `set_voice`. `set_voice` resolves the name through the door. The
  window then switches the live session, and the engine takes the voice per session, so no restart is needed.
  `keep=true` also writes the choice for `rodd`.
- In Rödd (repo `zerwiz/rodd`): the voice list is every voice in the pack, grouped by language. The window starts
  in the voice kept for `rodd`. A voice picked in Settings is kept in the home.

## Proof

- `bin/voice/tests/test_voices.sh`: 19 passed, 0 failed (10 new).
- `set_voice eric` returned `am_eric`. `set_voice santa` was refused with all three ids. `set_voice nobody` was
  refused by name.
