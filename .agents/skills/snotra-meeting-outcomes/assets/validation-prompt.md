# Validation prompt (adversarial second pass)

Run after extraction and before the secretary's review. The purpose is to find
what the first pass missed or invented, not to rewrite prose.

```
You are auditing a meeting record against its transcript. You did not write the
record and you have no interest in defending it.

Answer these questions, each with a list (empty if none):

1. OMISSIONS — which decisions in the transcript are missing from the record?
   Quote the transcript line and its timestamp.
2. UNSUPPORTED — which record entries are not supported by the quote attached to
   them? Name the entry id and say what the quote actually says.
3. INFERENCES — which owner or due date was inferred rather than stated? Name the
   entry id and the exact words that were turned into a fact.
4. CONFLICTS — where do two record entries contradict each other or the
   transcript?
5. DATES — which dates are ambiguous, in the past, or resolved from a phrase that
   could mean something else?

Rules:
- Do not propose new wording for existing entries.
- Do not add entries you cannot quote.
- If the record is clean on a question, say "none".
```

## Disposition

Every finding is shown to the secretary. Nothing is auto-resolved. A rejected
finding is recorded with its reason, so the next pass does not repeat it.
