## agents · 2026-10-22 — a chat gets a shape, and a mangled name still finds its chat

Two of the audit's owed items, plus the Allfather's word on the ledger.

```
fixed[3]{item,was,now}:
  "his memory was six raw turns","no shape to a long conversation; a follow-up was a fresh question","every eight turns the chat is summarised into at most two sentences (names, dates, decisions kept; pleasantries dropped) into `chat-summaries.json`, and *'what did we talk about'* answers from it. Measured on a seeded chat: *'The Allfather requires the OptiCat protocol, template, and BBR list by Friday for the 10:00 Solna inspection. Craig's phase two deliverables remain under NDA…'*"
  "a mangled asker name","`tell Isabell: …` (ASR) matched nothing and fell to the newest ask","fuzzy match on the first name (≥0.60), the NEWEST matching ask wins, and *her/him/them* means the newest — so a name heard through a microphone still reaches the right chat"
  "the ledger on a shelf","`--commit` only, nightly","the Allfather's word: **yes, and on pushes** — the nightly row is `--keep 7 --push`, and the home repo carries a `pre-push` hook that snapshots on every push (a hook commit lands on the NEXT push; run `--commit` first to ride the same one)"
```

**One correction worth writing down:** the two test deliveries that reached the Allfather's own DM were
aimed there deliberately — a test needs a chat id that exists, and his was the only real one. In
production the ask carries **the asker's** chat id from the incoming message, so the answer returns to
the person who asked. The footer (*"He asked me to pass this on"*) is how he can tell a relay from a
conversation.

**Verified:** `walls-test` holds (33) · summarisation proved on a seeded chat · the mangled-name path
delivered live · `backup.sh --push` committed and pushed the ledger, so the fleet gets it on the next pull.
