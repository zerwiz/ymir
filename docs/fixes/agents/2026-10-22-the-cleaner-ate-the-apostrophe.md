## agents · 2026-10-22 — the cleaner ate the apostrophe, and every voice was blamed

**His words:** *"all voisce models on f11 alre breaking allfather + s on"*. Every voice — so the fault
could not be a voice. It was the text cleaner both F11 and Piper share.

```
root_cause[3]{line,what_it_did,effect}:
  "`re.sub(r\\"[^\\\\w\\\\s.,:-]\\", \\" \\", line)`","the final sweep allowed no apostrophe, so it became a space","**'Allfather's' → 'Allfather s'**, 'don't' → 'don t' — on every voice, in every engine"
  "`re.sub(r\\"(?<!\\\\d)\\\\.(?!\\\\d)\\", \\"\\", line)`","deleted every period","no sentence pauses left: clauses spliced, the answer rushed"
  "`re.sub(r\\"(?<!\\\\d),(?!\\\\d)\\", \\"\\", line)`","deleted every comma","the breath inside a sentence was gone too"
```

**Fixed in `~/.local/bin/piper-clean-text`** (backup `piper-clean-text.bak-20261022`):
- curly apostrophes fold to a plain one; only quotes that are not word-internal become a space;
- a period and a comma are **kept** — they are the speaker's breath;
- a colon becomes a comma unless it is a time (`12:30`), which the digit guard already protects;
- the final sweep now allows `'`.

Measured after: *"the Allfather's assistant, and he doesn't hold that. It isn't approved — 1,000 times at
12:30."* → the same text, apostrophes attached, commas and full stops intact, numbers and times untouched.

**And the assistant's own path is separate:** `bin/assistant/speech-text.py` expands contractions and
folds curly punctuation for the mouth, and never touches a possessive — because with a correct text the
possessive is one word: measured, `Allfather's` and `Allfathers` are identical audio.

**Also in this pass, because a voice that inserts gaps cannot be fixed by text:** `audio-tighten.py`
closes the SHORT gaps a model puts inside its own words (a gap under 120 ms becomes 30 ms; a real pause
is left alone), and `voice.sh` now asks the server for **WAV** (`response_format`) instead of the MP3 it
was silently receiving into a `.wav` filename.

**Verified:** the cleaner round-trips a paragraph with apostrophes, commas, periods, `1,000` and `12:30`
intact · `walls-test` holds (33).
