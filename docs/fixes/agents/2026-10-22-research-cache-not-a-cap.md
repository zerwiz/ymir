## agents · 2026-10-22 — no cap on the Allfather; a cache, and a throttle that says so

**His question:** *"why per hour cap?"* The honest answer is that he does not need one, and proposing it
was a reflex.

```
why_not_a_cap[3]{reason,evidence}:
  "the cap already exists one layer down","`telegram.py` refuses a chat faster than one message per **5 s** and more than **30 an hour** — the owner's DM is already capped"
  "a stranger cannot reach the door","research is owner-only; there is no hostile flood to defend against"
  "what is real is COST, not abuse","every research turn is one Exa call plus one model answer, and with `--models-max 1` a cold answer evicts the interactive model (~7 s, then a swap back)"
```

**So the fix is not a cap. It is: don't ask twice, and never lie about a throttle.**

- **A ten-minute cache**, keyed on query + limit, under `hodd/state/assistant/research-cache/`. Measured:
  the same question cost **1 197 ms** live and **195 ms** from cache, provider reported as `exa-cache`
  so the caller can see it did not touch the network.
- **429 is reported as a throttle**, not silently answered from the Wikipedia stub. That silent
  downgrade is the exact bug this door was rebuilt to end, and a fallback hidden behind a rate limit
  would bring it back.
- `--no-cache` exists for the smoke test, so "the provider is Exa" is proved by a live call every run
  rather than by whatever the cache held.

**Verified:** `research-smoke.sh` now **17/17** — including *"a repeat is served from the cache — 192 ms,
no provider call"* and *"the cached answer still carries its sources"*.

**Files:** `bin/assistant/research.py`, `bin/assistant/research-smoke.sh`.
