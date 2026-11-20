## docs · 2026-10-22 — the voice page learns the cleaner, and the operator's ear writes the lesson

`docs/features/the-voice-engines.md` described two engines and one install path. It did not say what
happens when a **text cleaner** breaks speech for every voice at once — which is what happened tonight,
and what the Allfather heard three times before it was found.

**Appended:** the three doors (F10 Piper · F11 Kokoro · the assistant's mouth), the three lines in
`piper-clean-text` that ate apostrophes and deleted every period and comma, the fix at the root, the
single source of truth for the voice (the switcher), the measured voice comparison, the commands worth
knowing (`piper-clean-text` round-trip, `kokoro-voice`, `audio-tighten.py`, `speech-text.py`), and the
limits — MP3 by default, `--squeeze-all` costs the breath between clauses, U+02BC shatters a possessive.

**And the lesson, on the page rather than only in a plan:** *when every voice breaks the same word,
measure the string before measuring the speaker.*

**Also:** a `FEATURES.md` row (append-only) so the feature is in the catalogue, and the claims gate is
green across 126 pages.
