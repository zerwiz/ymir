# The ear follows the gate — the engine stops holding VRAM when no meeting is running

**Dated:** 2026-10-01 · **Component:** snotra · **Branch:** `eindri/snotra-ear-follows-the-gate`
**Found on:** heimdall (RTX A5000 Laptop, 16,384 MiB)

## The symptom, and why it pointed at the wrong thing

`pi` came up on its new default and every request failed:

```
Error: 500: {"code":500,"message":"model name=qwen3.6-35b-a3b@q4_k_xl-mtp failed to load"}
```

A `500` that names the model reads like a broken preset, and the preset was fine —
`~/.config/llama-rail/models.ini` and `~/.pi/agent/models.json` agreed on the id, and
the shelf symlink resolved to a real 22.8 GB file. The model loads and serves. The
rail's own log said what was actually wrong, at the tail of the load:

```
creating MTP draft context against the target model ...
E ggml_backend_cuda_buffer_type_alloc_buffer: allocating 1184.06 MiB on device 0: cudaMalloc failed: out of memory
E common_speculative_init_result: failed to create MTP context
```

The weights and the 262K KV cache allocate fine. The **1,184 MiB MTP draft context**
is what finds nothing left. It is a capacity wall wearing a model's name.

## The measurement that decided the fix

| Consumer | MiB |
|---|---|
| `qwen3.6-35b-a3b@q4_k_xl-mtp`, fully loaded (incl. MTP draft ctx) | **13,790** |
| `kokoro-serve` (fp32 CUDA) | 684 |
| `snotra-ear` (whisper small.en, `:8322`) | **900** |
| `maestro` (the forge) | 186 |
| CUDA/context overhead | ~247 |
| **card** | **16,384** |

With the engine resident the total is ~15,900 — inside the card on paper and **49 MiB
short** in practice, which is the whole failure. With it down, 15,001 used and 970 free,
and the rail served `HTTP 200` with MTP confirmed (`draft_n: 3, draft_n_accepted: 3`).

**The blame was not where it first fell.** The obvious suspect was Kokoro, and the
obvious fix was to stop it. That would have been wrong twice over: rail + Kokoro is
15,001 MiB and both serve fine together (Kokoro measured RTF 0.31 with the 262K model
fully resident). The engine was the co-conspirator — and it was resident for **three
days with no meeting**, which is the part worth fixing.

## The defect

`res` — the watch, the gate and the capture were all already correct:

| layer | demand-driven? | evidence |
|---|---|---|
| the watch (`snotra-detect.service`) | **yes** | arms only when `snotra-iscall.sh` exits 0 |
| the call gate (`snotra-iscall.sh`) | **yes** | exit 1 live: `no stream carries a call role (communication phone)` |
| the capture (`snotra-capture.sh`) | **yes** | runs only inside a watch capture |
| **the engine (`snotra-ear.service`)** | **no** | `WantedBy=ymir.target` — decided by what hardware the seat has, never by whether a meeting is happening |

The unit's own comment claimed *"fleet-ensure raises this unit by CAPABILITY"*. It did
not: `AUTOBOOT_CAPABILITY_PROGRAMS` is `snotra-detect` alone, and `AUTOBOOT_PROGRAMS`
never mentioned the ear. **The engine's residency came from exactly one thing —
`[Install] WantedBy=ymir.target` — and the comment described a mechanism that did not
exist.** So there was no capability raise to correct, only a boot target to remove.

Worse for auditing: `snotra-ear.service` was **not in the tree at all**. It existed only
as `~/.config/systemd/user/snotra-ear.service` and in the worktree
`.yggdrasil/snotra-door-fronts-the-ear` (commit `0f5ff14`, a branch 61 commits behind
`main`, never pushed, never given a PR). The unit holding 900 MiB of the box's card was
invisible to the governed-path contract and to anyone auditing it.

## The change

1. **`bin/snotra-detect.sh`** — `ear_up` / `ear_down` / `ear_seat_unit`, and four hooks:
   `ear_up` after a capture is confirmed alive in `do_arm`; `ear_down` on **all three**
   exits out of `do_leave`; `ear_down` in `back_to_idle` as the net for a watch that
   restarted mid-meeting.
2. **`tools/mill/systemd/snotra-ear.service`** — new in the tree, with **no `[Install]`
   section**, so nothing can put it back in `ymir.target`. Seated into
   `~/.config/systemd/user/` by the watch at arm time from the durable tree.
3. **`bin/snotra-transcribe.sh`** — `SNOTRA_FREE_RAIL` default `0` → `1`. The
   rail-yielding path was already written and shipped; it was simply off. A meeting is
   the thing that matters while it is happening, and the rail is the largest claim on
   the card, so the rail is the one that gives way. `SNOTRA_FREE_RAIL=0` remains the
   deliberate override.

**The window that had to be preserved.** `ear_down` fires **after `finalize`**, not when
the room empties. `finalize` transcribes the recording *through this engine*; lowering it
one step earlier leaves a recorded meeting with no minutes. That is the one way this
change could have cost a meeting, and it is why the call sits where it does rather than
in the tick loop.

**Why the ear is not in `AUTOBOOT_PROGRAMS`.** That list is the purge list:
`purge_stale_units` removes any unit in it that is not *owed*, and the ear is owed by
nothing (a headless heart must never load whisper). Adding it would have the engine's
own unit purged out from under the watch. Keeping it out leaves the copy governed by
exactly one file — the one in the tree — instead of a materialized copy nobody audits.

## Verified

- `bash -n` clean on both scripts.
- Rail serves `HTTP 200` with the engine down; `draft_n: 3, draft_n_accepted: 3`.
- Kokoro serves RTF 0.31 with the 262K model resident.
- 970 MiB free on the card with the engine disabled.
- The gate still refuses: `snotra-iscall.sh` exits 1 with no call on the room.

**Not verified — stated honestly:** the `ear_up` → `ear_down` round trip has **not** been
exercised end to end. Arming a real meeting means a real call on the room, and the
watch's own history (the 2026-09-28 P0) is a record of what a synthetic arm delivered
eight times over. The hooks are placed so a refused arm never pays the VRAM, but the
transcription-at-leave path is proven only by reading, not by running. That is the first
thing to watch on the next real meeting.

## The lesson worth keeping

**A file's size is not a VRAM budget, and a seat's hardware is not a meeting.** Both
errors were in the same subsystem and both pointed the wrong way: `text-to-speech.md`
estimated Kokoro at "~100 MB, contention is small" and recorded 1,212 MiB two sections
later, and the ear's unit invented a capability raise to explain a boot target. The
expensive mistake is not the 900 MiB — it is that a resource with no stated owner and no
stated gate looks, from every angle, like it is working.
