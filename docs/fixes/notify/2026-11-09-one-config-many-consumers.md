# One config, many consumers — why the assistant answered in the counsellor's chat

**2026-11-09 · component: notify**

## What he saw

A message written to the assistant arrived in the counsellor's chat, and the counsellor answered it. Then
pi-telegram refused to run at all: *"Telegram update journal belongs to another Telegram bot identity"*.
Three times in one night, with two different bots.

## The two causes, which are one mistake in different clothes

1. **One config, many consumers.** `@llblab/pi-telegram` reads `~/.pi/agent/telegram.json` for the whole
   **harness**, so *every* pi session on the machine inherits whichever bot is written there. A seat that is
   not that bot's owner answers as it — which is exactly what happened.
2. **A token from one bot under the name of another.** The file carried the seat's name and id with a
   different bot's credential, so the extension derived one identity from the token and found another in the
   journal on disk. It refused — correctly — and the seat went dark with a stack trace nobody could read.

Skírnir being a *system* isolates nothing here. The bot is a harness-level credential; the system's own
services read **their** bot from the vault by key (`SKIRNIR_TELEGRAM_BOT_TOKEN`), which is the right shape
and was never broken.

## What was forged

`bin/notify/telegram-seat.sh` — the door that answers who is whose, and repairs the third answer:

```
verbs[3]{verb,what it does}:
  "check","the harness profile, the credential's bot id (withheld value), the label it claims — a label that disagrees with its credential is a FAULT; then every journal on disk and whether its botId agrees; then every TELEGRAM key in the vault, by NAME, with its bot id and whether it CLASHES with the harness"
  "repair","moves aside any journal whose identity disagrees — dated, never deleted, because a journal holds update offsets and a thrown-away offset swallows a message"
  "repair --dry-run","says what would move and moves nothing"
```

It never prints a token, never writes one, and works on every role: a machine with no `telegram.json`, no
journals and no vault keys reports three empty tables and exits 0 — a clean skip, not a failure (RULES/25).

## Measured, this seat

```
harness    default · credential id=9218478309 (Ymir_Nidavellir_Bot) · label 9218478309      agree
journals   one journal carried 9204230623 → DISAGREES                                     moved aside
consumers  TELEGRAM_BOT_TOKEN 8961261921 · SKIRNIR_TELEGRAM_BOT_TOKEN 9279551439 ·
           TELEGRAM_BOT_TOKEN_SKIRNIR 9279551439                                           all distinct
```

After `repair`: every identity agrees, exit 0; and pi's credential is verified live against Telegram's
`getMe`.

## What is still owed

The three bots' tokens have each been in plain text in a chat, so all three are burned: rotate them in
BotFather and put each where it belongs **by name** — pi's in the harness config, the assistant's in the
vault under `SKIRNIR_TELEGRAM_BOT_TOKEN` — and no token ever needs to pass through a message again.

## CHANGE LOG

- **2026-11-09** — Opened with the fault, the two causes, the door, the measured tables, and the rotation owed.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
