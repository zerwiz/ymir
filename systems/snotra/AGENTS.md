# AGENTS.md — Snotra's house rules

You are in **Snotra's domain**. Before you change anything here, read this file, `domain.yaml` beside
it, and `README.md`. The keeper is **snotra** (`.agents/agents/snotra-documenter.md`); the register in
the home (`hodd/identity/domains.yaml`) says who is accountable, this folder says what the domain is.

**What Snotra is:** the meeting system — a SYSTEM, not an app (plan 129 §12). Headless, stateful, and
her records are lost if this folder is deleted. Hlidskjalf may *read* her; nothing here draws a window.

**Where things live**

| what | where |
|---|---|
| the doors | `services/` — ear · cron · record · letters · mail-watch · approve · calendar · tts-lease |
| the subsystems | `systems/` — the record, the letter, the board |
| her declaration | `domain.yaml` — folder · keeper · board · memory · doors · called_by · never |
| her memory | well namespace `domain:snotra` + `memory/` here (append-only, curated, small) |
| her board | `snotra/projects` |

**The laws that bind you here**

1. **The microphone is a LOCAL room door only.** `services/ear/snotra-capture.sh`, `snotra-detect.sh` and
   `snotra-live.sh` refuse unless `SNOTRA_LOCAL_ROOM=1`, which only the Hlidskjalf button sets. An online
   meeting is heard by the **bot** (`snotra-bot.sh`, the Vexa participant) and never by the mic.
2. **Nothing leaves without the gate.** `services/approve/snotra-approve.sh` binds the operator's word to
   the exact bytes; `sendUpdates=none` is the default on invites; a spent word cannot be reused.
3. **The record appends.** `meeting.json · transcript.md · minutes.md · actions.md` are written once and
   corrected by appending (`--as corrections`). Never rewrite a record to look tidier.
4. **`bin/time/snotra/` holds retired shims, not code.** A shim exists so an un-repointed caller keeps
   working; it is retired by a dated note, never silently. Do not add behaviour to a shim.
5. **Two parts of this move are still on the trunk** (org adapters · rules · route · grooming · card-moves ·
   friday-synch · channel adapters). The paths ledger records the partial move — read it before assuming a
   path is gone.

**Before you claim done:** `bash -n` on every shell door you touched; `bash systems/snotra/tests/smoke.sh`;
`bin/gates/guards/path-ledger-guard.sh`; and if you changed a door's shape, update `domain.yaml` in the
same change — code, plan and declaration must agree.
