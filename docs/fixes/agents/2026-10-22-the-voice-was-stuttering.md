## agents · 2026-10-22 — the voice was stuttering, not the sentence

**His words:** *"she says the allfather .... s not the allfathers"*, and before that *"kokoru cant say
don´t she says do n,,,, t"*. He was pointing at the right layer: **the voice**, not the text.

```
measured[2]{voice,phrase,audio,pauses}:
  "af_nicole (grade B−)","the Allfather's word","1.49 s","**4** — the apostrophe becomes a pause"
  "af_heart (grade A)","the Allfather's word","1.22 s","1"
  "af_nicole","I don't have that","1.47 s","**3**"
  "af_heart","I don't have that","1.07 s","2"
```

And on a whole answer: af_nicole took **17.4 s with 14 stutter-pauses** where af_heart took **10.7 s with
6** — a 60 % difference on the same text. That is the "she rushes and clips the adverb" he heard.

**The fix is a voice, not a rewrite.** `kokoro-voice set af_heart` (grade A, the top of the published
list) and the assistant's fallback is no longer af_nicole. The switcher (`SUPER+CTRL+U`) remains the
source of truth; a rotation that lands on af_nicole will stutter again, which is now written down.

**Kept as belt-and-braces:** `speech-text.py` expands contractions and folds curly punctuation before
synthesis — it helps any voice, and it is the reason a contraction no longer reaches the phonemiser at
all. It never touches the written answer, and it runs after the gate.

**Verified:** the same phrase measured across five voices (af_nicole 17.4 s/14 pauses · af_heart 10.7 s/6 ·
af_bella 11.0 s/5 · bf_emma 10.0 s/4 · am_michael 11.8 s/7) — af_heart and bf_emma are the two that
speak a long answer without stumbling.
