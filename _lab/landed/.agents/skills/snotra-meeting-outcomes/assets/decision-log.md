# Decision log

Decisions are append-only. A decision is never edited; it is superseded.

```
decision_id     DEC-YYYYMMDD-NN
statement       one sentence, present tense, falsifiable
context         why it came up
rationale       the reason recorded in the room, or "not stated"
decided_by      one person, or the body with the authority
authority       role or mandate that makes it valid
decided_at      timestamp
reversibility   easy | costly | irreversible
review_date     when it must be revisited, or null
evidence        timestamp + verbatim quote
status          proposed | decided | superseded | reversed
supersedes      decision_id or null
```

## Rules

1. One decision per entry. A paragraph containing three decisions is three entries.
2. The statement must survive being forwarded without the rest of the minutes.
3. "We discussed" is not a decision. If nothing was decided, the entry does not exist.
4. A reversal is a new entry with `status: reversed` that cites the original.
5. A decision with a `review_date` is re-opened on that date or explicitly re-affirmed.
