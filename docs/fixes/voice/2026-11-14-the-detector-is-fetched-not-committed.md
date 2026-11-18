# The voice's detector is fetched and checksummed, not committed

**Date:** 2026-11-14 · **Component:** voice (`bin/voice/voice-model-lib.sh`,
`bin/voice/voice-ensure.sh`, `bin/voice/ymir-vad.py`, `bin/voice/tests/test_voice_vad_model.sh`,
`.fleet/voice/silero_vad.onnx`) · **Errand:** `out-of-git` (plan 288 step 7, plan 287 P4)

## What was wrong

`.fleet/voice/silero_vad.onnx` — the Silero voice-activity detector, 2,327,524 bytes — was tracked in
the public repository as the only file on the `.fleet/` shelf. Model weights are a **download**, not
source: they inflate every clone, they belong to an install step that can check what it fetched, and
plan 288 §1 puts them in the user's data folders.

Two smaller faults came to light while mending it, and both were found by running the code rather
than reading it:

1. **`ymir-vad.py selftest` had never run.** Its print statement referenced `window_samples`, a name
   that does not exist in the function, so the tool's own proof raised `NameError` the first time it
   was ever executed. A gate nobody runs is a gate that does not exist.
2. **The path was welded to the source tree.** `MODEL` was computed as
   `Path(__file__).parent.parent / ".fleet" / "voice" / …`, so the loader could only ever read a file
   that shipped beside it — the exact coupling that made committing the weights feel necessary.

## The fix

- **One library answers "where do the weights live, and what must they hash to"** —
  `bin/voice/voice-model-lib.sh`:

  ```
  YMIR_VAD_SHA256  1a153a22f4509e292a94e67d6f9b85e8deb25b4988682b7e174c65279d8788e3
  YMIR_VAD_URL     raw.githubusercontent.com/snakers4/silero-vad @ bfdc0193…  (v6.2, Apache-2.0)
  default folder   ${YMIR_RELEASES:-$XDG_DATA_HOME/ymir}/models/voice
  overrides        YMIR_VOICE_MODELS_DIR (the folder), YMIR_VAD_MODEL (one file)
  ```

  The upstream is pinned to a **commit**, never `master`: a checksum pinned against a moving URL is a
  checksum that fails one morning for no reason the reader can see.

- **The install step fetches it.** `bin/voice/voice-ensure.sh install` (which
  `bin/engine/ymir-install.sh` `step_voice` already runs) calls `ymir_vad_fetch`: download to
  `.part-<pid>`, verify the sha256, and only then rename into place. A mismatch **refuses**, names
  both hashes, and leaves nothing behind. `status` grew a `vad` row and now fails while the detector
  is missing, so a machine without it says so instead of reporting the voice whole.

- **The loader reads the same place.** `bin/voice/ymir-vad.py` resolves the identical three
  environment variables in the same order (commented as a mirror of the library), gained a `path`
  subcommand so any caller can ask it what file it would read, and is loud when the file is absent —
  naming the door that fetches it.

- **A test holds the two doors together.** `bin/voice/tests/test_voice_vad_model.sh`, added to
  `bin/gates/ci-verify.sh` as the `voice-vad` gate:

  | row | what it proves |
  |---|---|
  | 1 | the library and the loader name the **same** file, for the data-root default, `XDG_DATA_HOME`, `YMIR_VOICE_MODELS_DIR` and `YMIR_VAD_MODEL` |
  | 2 | `ymir_vad_verify` refuses a file that is not the pinned detector |
  | 3 | a mismatched fetch refuses, seats nothing, and leaves no `.part` behind |
  | 4 | a matching fetch seats the file, and verify then accepts it (judged against a `file://` URL — no network needed) |
  | 5 | a missing detector exits 1 and names `bin/voice/voice-ensure.sh install` |
  | 6 | the machine's own copy matches the pinned sha256; and where a python with `onnxruntime` exists, the selftest actually runs |

## Recorded move (Rule 11)

The weights did not vanish: a copy and its checksum are kept in the operator's home —
`$YMIR_HOME/hodd/reference/out-of-git-2026-11-14/silero_vad.onnx` (+ `.sha256`) — with the note
`README.md` beside them saying why they left and how to seat them again. `.fleet/README.md` remains
in the tree as a signpost so a reader who finds the empty shelf learns where the weights went.

## How it was proved on this machine

```
# the install door fetched it, into the data folder, and verified it
bin/voice/voice-ensure.sh install
#    → "vad: fetching silero_vad.onnx (pinned 1a153a22f450) …"
#    → "present","~/.local/share/ymir/models/voice/silero_vad.onnx"

sha256sum ~/.local/share/ymir/models/voice/silero_vad.onnx
#    1a153a22f4509e292a94e67d6f9b85e8deb25b4988682b7e174c65279d8788e3   (the pinned value)

# the loader reads that file and runs it
python bin/voice/ymir-vad.py path
#    ~/.local/share/ymir/models/voice/silero_vad.onnx
python bin/voice/ymir-vad.py selftest
#    vad_selftest[1]{file,window_samples,p_silence,verdict}:
#      "silero_vad.onnx","512","0.0006","PASS"

# the gate
bash bin/voice/tests/test_voice_vad_model.sh
#    14 passed, 0 failed, 1 skipped   (the skip is the selftest where no onnxruntime exists)
YMIR_VAD_PYTHON=…/kokoro-cli/bin/python bash bin/voice/tests/test_voice_vad_model.sh
#    15 passed, 0 failed, 0 skipped
```

## What this does not change

- **Rödd's window is untouched.** Its face fetches `silero_vad_v6.onnx` from `@ricky0123/vad-web` in
  `node_modules` (`apps/rodd/setup.sh`), and the realtime host runs its own `--vad silero`. Neither
  ever read the tracked file; the tracked file's only consumer was `ymir-vad.py`, the turn boundary.
- **No new runtime dependency.** `onnxruntime` + `numpy` were already what the tool needs; the fetch
  needs `curl`, which the piper voice fetch already required of the same script.
- **The pin is a version, not a hope.** `bfdc0193023f121ea5b3cc7b176dbed570a68a59` is the
  silero-vad commit that added the v6.2 model; its file hashes to the pinned value (verified twice,
  against `master` and against the pinned commit, both `1a153a22…`).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #758
