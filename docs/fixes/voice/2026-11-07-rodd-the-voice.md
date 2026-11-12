# voice · unversioned · 2026-11-07 — Rödd: the streaming voice becomes a door, a face and fifteen hands

## What

The house's realtime voice — the engine's streaming pipeline — becomes one governed thing:

- **`bin/voice/voice-door.sh`** (new) — the one door: `start · stop · status · log · host · client`,
  seat-agnostic (it resolves the host from the operator's own fleet registry), loopback-only host reached
  through an ssh tunnel, seated in a herdr pane, mic blocked during playback (no acoustic echo cancellation
  exists, and server-VAD barge-in was cancelling every answer after its first sentence).
- **`bin/voice/voice_tools.py`** (new) — the hands: fifteen client tools (`hand_over` with a two-phase
  confirmation gate, `plan_write`, `context_left`, `errand_state`, `steer_worker`, `gimle`, `search_home`,
  `read_home_file`, `read_mail`, `read_calendar`, `calendar_respond`, `read_board`, `add_todo`, `recall`,
  `remember`), every call appended to `hodd/state/voice/activity-*.jsonl`.
- **`bin/voice/voice-toolbox.py`** (new) — the same fifteen tools over loopback HTTP for a browser client
  (`GET /tools`, `POST /tool`), so the face and the terminal share one implementation.
- **`apps/rodd/**` (new)** — Rödd as a Ymir application: an Electron shell that spawns the UI's own server,
  clears a leaked pipeline slot through the door, repairs a saved demo voice/instruction, and serves the
  house's palette. Includes `start.sh` (one command, the single-seat order) and `smoke.sh` (eight stages,
  the last proving **audio arrived**).
- **`apps/hlidskjalf`** — a Rödd panel on the Skírnir page (Start · Stop · Show what it has done) over a new
  `/api/rodd/*` route that drives the door behind the gate's existing local-owner policy.
- **`bin/mail/mail-scan.sh`** — a `--scope inbox|sent|drafts|all` flag. The old query was `is:unread
  in:inbox` only, so "read my sent mail" could never work; the voice was describing its cage truthfully.
- **`systems/snotra/services/calendar/calendar-ask.sh`** — accept the vault's `GOOGLE_MCP_*` spelling of the
  Google client, not only `GOOGLE_OAUTH_*`; a credential that existed read as missing.
- **`systems/snotra/services/calendar/calendar-auth.sh`** — `CALENDAR_WRITE=1` requests the write scope
  (`calendar.events`), and the door now **refuses to re-encrypt a manifest that decrypts to fewer than ten
  lines**. On 2026-11-07 this door wrote an empty manifest over the whole vault; it was restored from the
  backup the same door had just made (155 lines, 78 exports), and this guard is why it cannot happen again.

## Why

His words through the day: *"it need to be streaming ai"* (RULES/28), *"we can not break the setup we had"*,
*"we need to have ALL we added to the terminal rödd"*, *"ask for permission before we send out agents"*,
*"allways do online resarch for problems"*. The voice worked in the terminal and not in the face; the gaps were
a voice name (Qwen3 `Aiden` to a Kokoro mouth → 404), a leaked single session slot, a client/server version
skew, and one shim of mine that crashed every response.

## Verified

- `apps/rodd/smoke.sh` — all stages PASS, the decisive line **`assistant audio arrived PASS 293,376 bytes`**,
  with a full spoken turn in the same run.
- the toolbox — `{"ok": true, "tools": 15}`, and a real call: Gimlé's board `9 card(s) assigned · OPT·Example4 5
  · GRW·Example9 3 · INV·InvestReady 1`.
- the vision head — `gemma-4-12b-vision` (model + BF16 **mmproj**) answered **"Red"** for a 2×2 PNG sent as an
  image part; the camera is enabled again on that guard.
- the errand gate — first `hand_over` answers *"NOT SENT — ask him"*; a confirm with a different task is
  **refused**; only a matching pending record dispatches.
- the vault guard — the write-grant door now aborts if the decrypted manifest is short, instead of writing it.

## Not verified / owed

- the calendar **write** grant was not obtained (the tool refuses with `403`); re-run it only through the
  guarded door.
- slot eviction lives in the face, not the door; the smoke's host probe still opens a session.
- the camera's snapshot budget and the latency of a turn *with* a picture are unmeasured.

Plan: `svartalfaheim/whynotproductions/projects/ymir/plans/132-skirnir-fleet-connectivity.md` §11–§40.

## CHANGE LOG

- **2026-11-07** — written. The fix note for Rödd, the streaming voice: the door, the fifteen
  hands (now twenty-five), the app, the toolbox, and the faults each one paid for. Appended to, never
  rewritten (RULES/06).
