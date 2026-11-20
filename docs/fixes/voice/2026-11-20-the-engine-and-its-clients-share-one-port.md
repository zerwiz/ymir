# The voice engine and its clients read one port

**Date:** 2026-11-20 · **Component:** voice · **Plan:** 326.0

## What was wrong

The plan recorded that `kokoro-serve` was active but nothing answered on `:8880`. Measured, two faults hid behind
that line.

- **The port was never 8880.** `kokoro serve` binds its built-in default, 8765, because the unit passed no `--port`.
  Nothing in Ymir dials 8880. But the port was a literal in about a dozen places: the Skírnir mouth, ear, voice and
  smoke tests, the Snotra meeting doors, Hlidskjalf's voice route, and the unit's silent default. Some clients read
  `KOKORO_URL` as a base and others as the full speech endpoint. Nothing tied the bound port to the dialled one
  (Rule 07).
- **"Active" did not mean "listening".** The engine loads its model before it binds, and its output was buffered, so
  the journal never said where it listened. A unit could be `active` with no socket. `snotra-meet.sh` trusted
  `is-active` and went on to speak into a closed port.

## What changed

- `bin/voice/kokoro-lib.sh` resolves the one value, `KOKORO_SERVICE_URL` (the engine's own name for it): the
  environment, then `$YMIR_HOME/config/voice.env`, then the engine's default. It refuses a non-loopback URL. It is the
  only place in Ymir that states the default. `bin/voice/kokoro_url.py` is its Python face and asks it.
- `config/voice.env.example` is the template for the home's file.
- `tools/systemd/kokoro-serve.service.d/20-one-port.conf` makes the unit read the same file and bind its port. Its
  `ExecStartPost` holds the unit in `activating` until the engine's pid owns a listening socket.
  `PYTHONUNBUFFERED=1` puts the "listening on" line in the journal. The CPU execution provider drop-in is untouched.
- Every client now resolves through the lib: `systems/skirnir/services/{mouth,ear,voice,smoke,walls-test}.sh`,
  `systems/snotra/services/ear/{snotra-meet.sh,snotra-talk.py,snotra-voice.py,snotra-cdp.py}`, and
  `apps/hlidskjalf/server/voice.ts`. An explicit `KOKORO_URL` still overrides, as before.
  `systems/skirnir/services/voice-io.py` also runs on Windows with no bash, so it reads the same names directly.
- `snotra-meet.sh` now checks the socket, never `is-active`.
- `voices.sh say` speaks through the running engine at the resolved URL (`--service required`), and raises a lowered
  engine first. `voices.sh engine` prints the URL and whether it answers. `voices.sh set` is `choose` by another name.

## Not changed

`bin/time/housewatch.sh` still probes a literal 8765. It belongs to another errand (plans 336/337), so it was left
alone. It should source `bin/voice/kokoro-lib.sh` next. `~/.local/bin/kokoro-speak` is a machine script outside the
repository and keeps its own literal.

## Proof (the dev machine)

- With `voice.env` set to port 8779, the unit bound `127.0.0.1:8779`, `kokoro-lib.sh port` printed 8779, and
  `/health` answered there. Set back to 8765, the unit bound 8765. One line moved both.
- `voices.sh say eric … --to eric.wav` wrote 146,476 bytes through the engine. `af_heart` from the same process, with
  no restart, had a clearly higher pitch. One sentence in Eric (from `hodd/identity/voices.yaml`) was played aloud
  while the desk was free.
- `mouth.sh` made a voice note through the resolved URL, and a dead URL still exits 3.
- `bin/voice/tests/test_voices.sh` passes 28 of 28, with 9 new checks for the resolver and the verbs. Hlidskjalf's
  `voice.test.ts` and `swedish-voice.test.ts` pass 10 of 10, and `test_voice_io.py` passes 4 of 4.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #840
