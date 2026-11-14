# The house can say who holds the card

**Date:** 2026-11-14 · **Component:** model (`bin/model/vram-ledger.sh`) · **Plan:** 275 item 23

## What was wrong

At 03:16 the rail failed to load `qwen3.6-35b-a3b@q4_k_xl-mtp` (cudaMalloc of 1,184 MiB) and
`apodex-1.0-mini` (3,314 MiB): out of memory. Rödd's voice engine (`speech-to-speech serve`) held 2,762 MiB of the
same 16 GiB card, and nothing in the house could say so — so the chat reported a 500 and the operator was left to
guess which process had taken his GPU.

## The fix

`bin/model/vram-ledger.sh` is the door that answers **who holds the card**: every compute holder, classified as
`voice`, `rail` or `other`, with its MiB, the card's total and free memory, and a verdict.

- A holder is identified by its **command line**, not its executable: the voice engine shows up in `nvidia-smi` as
  `.../venvs/s2s/bin/python` — the fact that it is the engine lives in its arguments. Measured 2026-11-14: reading the
  executable alone called the engine "other" and the ledger was useless for the one question it exists to answer.
- The argv is used to classify and then **thrown away**: a holder's command line can carry a bearer key (the voice
  engine takes its head key as a flag), and this door's output is read in a chat. Only the executable's name leaves it.
- Agnostic (RULES/25): NVIDIA is read through `nvidia-smi`; a seat without a readable card answers `known: false`
  **with the reason**, so a chat says only what it knows instead of inventing a voice it cannot see.
- `--busy-with-voice` is the question a chat asks: does the voice hold the card while the rail holds nothing?

## Verified

`bin/model/tests/test_vram_ledger.sh` — 5 checks against a fake `nvidia-smi`: holders are classified and their MiB
summed; `--busy-with-voice` says yes while the voice holds the card and no when a rail model is resident; a seat with
no readable card reports `known:false` with the reason; the verdict a person reads names the holder.

Live on heimdall: the ledger classified the running engine as `voice, 2762 MiB` and `voxtype` as `other, 480 MiB`,
matching the measurement in plan 275 to the megabyte.
