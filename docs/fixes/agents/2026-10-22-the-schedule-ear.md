## agents · 2026-10-22 — he has the calendar; he only heard two phrasings of the question

**His transcript, verbatim:**
*"what are <his name> working on?"* → the *how to reach him* fact. *"what are he doing now?"* → the honest no.
*"when are he free for a meeting?"* → the availability sentence. *"can you ask him when hes avalible"* → the
honest no. **He does have the calendar** — `Mánagandr` answered *free* in 0.3 s — but the schedule
branch fired only on the phrase table's exact entries (`where is he`, `is he free`, …).

```
fixed[2]{fault,now}:
  "the schedule ear","a person-word (he · him · his · she · the Allfather · any of his names) plus any of doing · working on · free · available · busy · schedule · where is · when is · meeting now routes to the LIVE calendar read — measured on all three of his sentences: *'You are free — nothing on the calendar in the next twelve hours.'*"
  "**'can you ask him …'**","a request to pass a question was answered as a fact. It is now a handoff: at the owner tier he says *'You're the Allfather — I'm speaking to you'*; for anyone else he gathers what is needed and escalates with their name"
```

**And a match that had to be tightened, not loosened.** The squashed-token rule — the one that makes
*"whynotproductions"* meet *"Whynot Productions"* — was matching any word of eight letters or more, so
*"how many plans are there"* found *"he plans"* and *"what is the OptiCat deadline"* found *"a deadline
moves"*. It now applies only when the token **spans a word boundary**: two words run together, never one
word with the token inside it. Three wall assertions had gone red; they are green again.

**Verified:** `walls-test` holds (33) · *'what are <his name> working on'*, *'what are he doing now'*,
*'when are he free for a meeting'* all read the calendar · *'what is the OptiCat deadline'* and
*'how many plans are there'* are the honest no again.
