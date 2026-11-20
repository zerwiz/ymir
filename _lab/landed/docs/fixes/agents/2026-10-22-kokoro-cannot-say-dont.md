## agents · 2026-10-22 — Kokoro cannot say "don't", and his answers teach him

**His words:** *"and kokoru cant say don´t she says do n,,,, t"*. He is right, and the fault is in what
the synthesiser is handed.

```
fixed[2]{fault,now}:
  "a contraction breaks the phonemiser","Kokoro splits the `n't` and inserts pauses: **“do n,,,, t”**. `speech-text.py` now expands contractions to full words and folds curly punctuation to ASCII — `don't → do not`, `it's → it is`, `I'd → I would` — and collapses the comma runs. The **written** answer is never touched; only what is SPOKEN is normalised, and it runs after the gate"
  "an answer died with the question","he answered a person and forgot what he said","`asks.sh deliver` now writes the Allfather's answer into `approved/` as a fact (`approved_by: the Allfather`, source: his own words, in answer to that question) and re-exports. Measured: asked *'when is the inspection'* afterwards, he answers it — for a stranger too"
```

**Measured before the fix:** *"I don't have that — I'd rather say so. It isn't in what's approved, and
that's fine."* → **"I do not have that, I would rather say so. It is not in what is approved, and that is
fine."** The audio is generated identically in length (1.43 s) for both forms, which is why the stumble
was in the phonemes and not in the clock.

**One correction, recorded:** the first test of the learning loop wrote a fact I had invented
(*"the inspection is Friday at 10:00 in Solna"*) into `approved/`. It was my test text, not his word, and
it was **removed** and the digest rebuilt — a fabricated fact is worse than a refusal. The loop now
writes only what the Allfather actually said.

**Verified:** `walls-test` holds (33) · the learned answer answers both phrasings, at the stranger tier
as well · digest 25 facts.
