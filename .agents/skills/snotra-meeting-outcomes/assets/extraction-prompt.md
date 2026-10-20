# Extraction prompt (optional model pass)

Use only when a model is available and the transcript is worth the extra pass.
The deterministic extractor is the baseline; this prompt must never be allowed to
invent an owner, a date, or a commitment.

```
You extract the RECORD of a meeting from its transcript. You do not summarise
prose, you do not add context, and you do not infer facts that are not stated.

Return one JSON object and nothing else:

{
  "decisions": [
    {
      "statement": "one sentence, present tense, falsifiable",
      "rationale": "the reason stated in the room, or null",
      "decided_by": "one named person, or null",
      "evidence": {"timestamp": "h:mm:ss", "quote": "verbatim words"}
    }
  ],
  "actions": [
    {
      "verb": "send|draft|file|confirm|schedule|review|build|decide|research",
      "deliverable": "the object produced",
      "owner": "one named person, or null",
      "due_at": "YYYY-MM-DD or null",
      "due_phrase": "the words that gave the date, or null",
      "evidence": {"timestamp": "h:mm:ss", "quote": "verbatim words"}
    }
  ],
  "questions": [
    {"question": "...", "decider": "... or null", "needed_by": "YYYY-MM-DD or null",
     "evidence": {"timestamp": "...", "quote": "..."}}
  ],
  "risks": [
    {"description": "...", "owner": "... or null",
     "evidence": {"timestamp": "...", "quote": "..."}}
  ]
}

HARD RULES
1. A quote must be copied exactly from the transcript, including its errors.
2. If the transcript does not name an owner, owner is null. Never guess from a
   job title or from who usually speaks.
3. If no date is stated, due_at is null. Never convert "soon" or "at some point".
4. "We", "the team", and "someone" are not owners. Use null.
5. A decision requires a decision cue: decided, agreed, confirmed, approved,
   signed off, going with, final.
6. Questions and hedges ("I think", "maybe", "I don't know") are not decisions.
7. If you are not sure, return fewer items. An omission is visible; an invention
   is not.
```

## After the model pass

Run the deterministic validator. The model's output is a candidate set, never the
record. Merge it with the secretary's review; every accepted item carries its
evidence.
