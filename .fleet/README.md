# `.fleet/` — what this shelf was, and why it is now a signpost

This folder used to hold one file: `voice/silero_vad.onnx`, the 2,327,524-byte Silero voice
activity detector that `bin/voice/ymir-vad.py` loads to decide whether the person has stopped
talking.

**It left git on 2026-11-14** (plan 288 step 7, plan 287 P4 — the line between the repository and
the operator's home). Model weights are downloads, not source: they make every clone heavy, they go
stale against nothing, and a public repository carries craft, not binaries.

## Where the weights live now

The detector is fetched by the install step and verified against a pinned checksum, into the user's
own data folder — never the code tree:

```
bin/voice/voice-ensure.sh install          # fetches and verifies it
~/.local/share/ymir/models/voice/silero_vad.onnx     # where it lands
bin/voice/ymir-vad.py selftest             # proves the loader runs it
```

The one answer to "where does it live and what must it hash to" is
`bin/voice/voice-model-lib.sh`; `bin/voice/ymir-vad.py` mirrors it and
`bin/voice/tests/test_voice_vad_model.sh` proves the two doors name one file. The bytes that left
git are preserved in the operator's home,
`hodd/reference/out-of-git-2026-11-14/` (Rule 11 — a file moves, recorded).

## Not to be confused with `~/.fleet`

`~/.fleet` (in the operator's home directory) is the **deploy shelf** — the tools and services
materialised for a seat. This `.fleet/` was a folder in the source tree. Different places, different
jobs; only one of them is code.
