# skirnir · 2026-11-12 — voice-io.py is a door: a shebang and the executable bit

**Status:** done on branch `eindri/nda-gate`.

**In three sentences.** `systems/skirnir/services/voice-io.py` was committed as `100644` with no shebang. The rules-compliance
ward (R4) refuses a door that is not executable, so every collaborator who synced was refused. It is run as a script by the
hall's voice server, so it is a door: it now starts with `#!/usr/bin/env python3` and is mode `100755`.

## Files

| What | Where |
|---|---|
| The door | `systems/skirnir/services/voice-io.py` |
| Its caller | `apps/hlidskjalf/server/voice.ts` |

## How it was checked

`python3 -m py_compile` passes and `git ls-files -s` shows `100755`. The test `systems/skirnir/services/test_voice_io.py` loads the file by path and is unaffected.

## CHANGE LOG

- 2026-11-12 — written with the fix.
