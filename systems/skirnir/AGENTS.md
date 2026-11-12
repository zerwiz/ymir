# AGENTS.md — Skírnir's house rules

You are in **Skírnir's domain** — the Allfather's assistant. Read this file, `domain.yaml` and `README.md`
before changing anything. The keeper is **skirnir** (`.agents/agents/skirnir-assistant.md`).

**What Skírnir is:** a SYSTEM, not an app (plan 150). He has no screen of his own — he speaks through the
Telegram bridge, the desk and his doors. He is stateful: his knowledge base, the gate's pending asks and
the rooms' state are lost if this folder is deleted.

**Where things live**

| what | where |
|---|---|
| the voice | `services/` — `ear.sh` · `mouth.sh` · `voice.sh` · `voice-handler.sh` · `speech-text.py` |
| the knowledge | `services/` — `skirnir.py` · `ground.py` · `research.py` · `learn*.sh` · `query.sh` · `report.sh` |
| the database | `services/` — `assistant-brief.sh` (thin door) · `assistant_brief.py` (the engine): `refresh` · `show [date]` · `recall <q>` · `status`. **Owner tier only** — a briefing never leaves for a collaborator. Filed at `$YMIR_HOME/hodd/memory/assistant/briefing/<date>.md`, observed into the well under the tag `assistant-briefing` |
| the gate | `services/` — `asks.sh` · `ask.sh` · `approve-fact.sh` · `ban.sh` · `group-allow.sh` · `escalate.sh` · `escalation-timer.sh` |
| the rooms | `services/` — `room.sh` · `room-squad.sh` · `room-wall-test.sh` · `walls-test.sh` · `smoke.sh` |
| his declaration | `domain.yaml` — folder · keeper · board · memory · doors · called_by · never |

**The laws that bind you here**

1. **Nothing leaves without the gate.** `asks.sh` / `approve-fact.sh` carry the operator's approved word;
   a send the gate has not approved is refused, and the escalation timer keeps an unanswered ask alive.
2. **He never carries a secret value.** Secrets are *referenced* through the vault door
   (`bin/vault/hodd.sh emit`), never inlined, never logged, never in a prompt.
3. **He does not speak for the Allfather** in a room the Allfather has not opened.
4. **`bin/assistant/` holds retired shims, not code.** They exec the doors here and say so; retire them by
   a dated note, never silently, and never add behaviour to one.
5. **His voice is his, his knowledge is his.** Do not point another system's transcript, board or memory at
   these doors without declaring it in `domain.yaml`.

**Before you claim done:** `bash -n` on every shell door you touched; `bash systems/skirnir/services/smoke.sh`;
`bin/gates/guards/path-ledger-guard.sh`; and if a door's shape changed, `domain.yaml` changes with it.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
