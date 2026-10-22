## agents · 2026-10-22 — the mouth got a model, and the matcher stopped lying

**The Allfather's word:** *"he need to use an ai model."* He had one available and spoke through none
of it: `skirnir-telegram.service` carried no `SKIRNIR_MODEL`, so every reply was a template or an
approved claim read out verbatim.

**But arming it alone would have bought nothing**, and the audit of the same evening says why: the
fuzzy fallback claimed an intent for nearly every *"what is …"* before the model branch was reached,
and answered a DIFFERENT approved fact — *"what is gimle"* → the Ymir fact; *"how many plans are
there"* → the Brokk fact because his claim says *"he plans"*. A model behind a lying matcher is still
a lie.

```
change[4]{what,why}:
  "the fallback only accepts a TYPO","every content word of the question must be a word of the phrase, or ≥0.80 similar to one. 'gimle' is not a misspelling of 'ymir'; 'whata' is a misspelling of 'what'"
  "one word must be the SUBJECT","a single-token question matches the claim's opening only, so 'how many plans' no longer becomes Brokk because 'plans' appears in his prose"
  "two facts about one subject: the focused one answers","more matched, then more in the subject, then the one that names it first, then the shorter claim; only an exact dead heat is refused — saying nothing beats guessing"
  "the model is the MOUTH","for owner/collaborator/known it phrases a matched fact, and answers from the digest when nothing matched. It sees `public`, `logistics` and `role` ONLY (new `model_context`), plus the last turns of that chat. A stranger still gets templates"
```

**The model does not replace the walls.** Its output still runs through the gate (no URL, no link, no
image, no code, 194 canaries), and if it says it does not hold the fact, the answer **stays a
refusal** so the escalation still fires. If the rail is down, the verbatim claim or the honest no is
already prepared — an absent model is not an outage.

**Which model, by measurement** (modeltesting canon §10.5.17 plus a head-to-head this evening):

```
mouth_bench[4]{model,first_call,warm,obeys "I do not hold that"?}:
  "minicpm5-1b-agentic-tooluse (Q8)","2.7 s","0.3–0.4 s","**NO** — invented 'Gimle is a type of dog', 'the well is a natural feature'"
  "qwen3.5-9b@q4_k_s-summarizer (32K, 5.4 GB)","6.6 s","1.3–3.2 s","**yes** — chosen"
  "gemma-4-12b-q3_k_s","11.1 s","1.4–4.9 s","yes, but slower and a Q3 quant"
  "qwen3.6-35b-a3b@iq3_s (MoE)","—","~147 t/s","same speed at 13.8 GB — starves Kokoro (measured CUBLAS failure)"
```

**The walls suite was testing an EMPTY digest.** It copied the approved facts from
`hodd/state/assistant/approved/`, the pre-move shelf; since the 2026-10-21 move to
`hodd/identity/assistant/approved/` that copy matched nothing, so the suite ran green against zero
facts. Repaired: both shelves are read, the resolved home is taken BEFORE the test's own `YMIR_HOME`
hides it, and the assertion **"the digest carries the operator's approved facts (N ≥ 5)"** now fails
if a future move empties it again.

**Verified:** `walls-test` 19/19 (12 red-team + 7 new: digest non-empty, unknown subject refused, one
shared word not a match, a name is not an identity claim, typo tolerance kept, two-facts tie answers,
model context clean, model leg through the gate) · `adapter-test` 6/6 · `room-wall-test` 9/9 ·
live: `Environment=SKIRNIR_MODEL=qwen3.5-9b@q4_k_s-summarizer` on the running unit, and an unheld
subject answered *"I do not know what Gimle is based on the provided facts, so I will ask the
Allfather."*

**Files:** `bin/assistant/skirnir.py`, `bin/assistant/walls-test.sh`, `bin/assistant/telegram.py`
(the addressee rule moved ahead of the allowlist so an owner-trusted room is heard),
`bin/assistant/group-allow.sh` (the allowlist writes to the identity shelf, where `telegram.py` reads
it), `docs/features/skirnir-the-assistant.md`, `FEATURES.md`.
