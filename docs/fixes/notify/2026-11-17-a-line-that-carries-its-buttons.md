# notify · 2026-11-17 — a line that carries its buttons

## Files

- `bin/notify/send.sh` — `--button "<emoji> <label>|<prompt>"` (repeatable) and `--buttons "<CML>"`
- `bin/notify/telegram-buttons.mjs` — `emit --format reply-markup`, `--per-row N`, and `--payload`
- `bin/notify/tests/test_send_buttons.py` — NEW, five proofs against a stub Bot API
- `docs/features/telegram-buttons.md` — the new rendering, in the one place the grammar is written

## Why

The house writes buttons in exactly one grammar (`telegram-buttons.sh`), and that grammar is written
for the **bridge**: a footer comment or a column-zero fence that the harness parses out of an
assistant's reply. It has no way to reach a message that no session composed.

`bin/notify/send.sh` posts **straight to the Bot API** — that is its virtue, it works with no session
running, which is the whole point of a cron line. But it posted plain text, so a line that left the
operator a decision arrived with no controls and no error anywhere. The weekly draft sweep is the
first door that genuinely needs both: no session behind it, and three buttons per draft.

## Fix

- **`telegram-buttons.mjs emit --format reply-markup`** renders the same CML cells as the Bot API's
  own `{"inline_keyboard":[[{text,callback_data}]]}`. The grammar is still judged in ONE place: the
  same cell parser, the same refusals (no prompt, unknown style, more than eight in a row).
  `callback_data` is capped at Telegram's 64 bytes, clipped at a word boundary.
- **`--per-row N`** lets a caller lay its own rows (three per draft), and **`--payload`** re-renders
  a matrix the caller already built, so a row layout survives instead of being rechunked.
- **`send.sh --button` / `--buttons`** build the markup once, before the delivery legs, and pass it
  to the Bot API as `reply_markup`. A button that could not render is a **refusal (exit 2)** — never
  a message that arrives as prose. The Rune records how many controls the line carried.

## Proof

`python3 bin/notify/tests/test_send_buttons.py` — 5 proofs, Bot API stood in for over HTTP
(`TELEGRAM_API_BASE` is configuration, Rule 07):

| Proof | What it pins |
|---|---|
| `ButtonsArrive` | one message, the text, and a `reply_markup` whose two rows are the caller's own |
| `FromPairs` | three `--button` pairs become one row of three, prompts byte-for-byte |
| `Refused` | a button with no prompt exits 2 and **posts nothing**; a malformed payload too |
| `NoButtons` | an ordinary line grows no empty keyboard |

## The limit, stated

A click on a Bot-API-sent button arrives as a `callback_query`. On a line the bridge composed, the
bridge dispatches the prompt into the session that owns the bot; on a line a cron row sent, the
prompt travels as `callback_data` and is answered by whichever seat holds the arm. That asymmetry is
named here rather than hidden: the sweep's buttons carry a self-contained sentence, so a click is
never a mystery — but a house that wants every cron button to open a turn needs a callback dispatcher
in the resident bot, which is a change of its own.
