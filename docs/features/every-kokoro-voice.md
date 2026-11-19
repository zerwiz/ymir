# Every Kokoro voice, by name

## What it is

Kokoro, the house's speaking engine, holds many voices in one file: 54 in `voices-v1.0.bin`. Until now you had
to know a voice's id to use it. `bin/voice/voices.sh` lists them all, finds one by its plain name, and lets
you hear it.

The list comes from the engine itself, never from a table kept by hand. A new voices file brings its voices
with it.

## What you need

- The Kokoro engine installed (`kokoro` on your `PATH`, or `KOKORO_BIN` naming it).
- Its model and voices downloaded (`kokoro setup`).

## The commands

| Command | What it does |
|---|---|
| `voices.sh list` | Every voice, with its id, name, language, gender and lang code |
| `voices.sh list --json` | The same, as JSON |
| `voices.sh resolve eric` | Prints the id for a name: `am_eric` |
| `voices.sh catalogue` | Prints the catalogue as YAML |
| `voices.sh catalogue --home` | Writes the catalogue to your hoard's `identity/voices.yaml` |
| `voices.sh say eric "Hello"` | Speaks "Hello" in Eric's voice |
| `voices.sh say eric "Hello" --to hello.wav` | Writes the speech to a file and plays nothing |

An id's first letter is its language and its second letter its gender. So `am_eric` is American English and
male, and `bf_emma` is British English and female.

## Limits

- A name that fits two voices is refused. `santa`, for example, is `am_santa`, `em_santa` and `pm_santa`.
  Say the id instead.
- `say` without `--to` plays sound. It is refused while the desk is held, because you are on a call.
- The speaking service (`kokoro-serve`) already takes the voice with every request. Its configured voice is
  only the default when a request names none.

## If it does not work

- **"the Kokoro engine is not installed here"** — install it, or set `KOKORO_BIN` to its path.
- **"no voice named …"** — run `voices.sh list` and use a name or id from that list.
- **"the desk is held"** — you are on a call. Write the sample to a file with `--to`, or wait until the call ends.

## CHANGE LOG

- 2026-11-19 — written: the voices door, its catalogue and its sample (plan 326.1–326.4).
