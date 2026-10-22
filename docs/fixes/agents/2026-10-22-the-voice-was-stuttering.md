
---

## Appended 2026-10-22 (same evening) — "Allfather's is not punctuation, it is one word"

He is right, and the measurement proves it: with **af_heart**, the possessive is already spoken as ONE
word. The pause he heard was the voice, not the apostrophe.

```
one_word[4]{input,audio,silence_at,verdict}:
  "the Allfather's word","1.216 s","1.03 s (the end)","**one word** — identical to 'Allfathers'"
  "the Allfathers word","1.216 s","1.03 s (the end)","the control: same audio, to the millisecond"
  "the Allfather’s word (curly)","1.216 s","1.03 s (the end)","folded to ASCII by `speech-text.py`; also fine"
  "the Allfatherʼs word (U+02BC)","3.264 s","0.66 · 1.81 · 2.39 · 3.16","**a trap** — the modifier apostrophe shatters the word into four pieces"
```

So: **an ASCII apostrophe is correct, and must be kept.** `speech-text.py` folds curly quotes to ASCII
and never strips a possessive. What it must never do is "fix" the apostrophe into U+02BC or into a space —
measured above, that is what breaks the word.

The stutter was af_nicole, at every apostrophe, on every phrase. It is off the mouth now, and the
rotation is documented as a place a stutter can come back from.
