# Skírnir — a mouth with no hands, and walls that fail closed

**Component:** agents · **Seat:** heimdall · **Date:** 2026-10-21

## The ask

A separate system that answers when the Allfather is away, in Telegram chats, in Snotra meetings and
(someday) Discord; deliberately less capable than Brokk; and **it must never leak NDA or contracted
data to the wrong people**, whatever anyone tells it to do.

## What the doctrine said, and what it changed

OWASP's LLM Top 10 (2026) is blunt: *prompt injection is intrinsic; no reliable prevention exists;
defence is architectural.* So the architecture removes the thing worth attacking:

- **no tools, no credentials, no shell** in his reach — an instruction inside a message can only make
  him say "I don't know", which is the honest answer anyway;
- **the lethal trifecta's missing leg**: he holds untrusted text and he speaks outward, so the leg we
  cut is **private data** — his knowledge is a digest of separately approved facts, never the vault;
- **markdown exfiltration** dies in the gate: no URL, no image, no link, no code block in any answer;
- **canaries fail closed**: a string from the vault's markers, the plan titles or the posture that
  appears in an answer is a **build failure**, not a warning.

## What was built

`bin/assistant/`: `kb-export.sh` (approval headers enforced, expiry honoured), `skirnir.py` (digest,
tiers, gate, ledger, escalation), `ask.sh`, `walls-test.sh`. Facts live in
`$YMIR_HOME/hodd/state/assistant/approved/`, one file each, `approved_by: the Allfather` required.

**The NDA wall**, which is the part he insisted on: a fact may declare `class: nda` and
`parties: a@x`. Only the operator or a **sender whose address is on that list** hears it; a stranger
asking politely is exactly the case it exists for. Both halves are asserted in the suite.

## The tests, and the mistake they caused

Ten assertions now pass — injection, vault probe, plan probe, posture probe, markdown exfiltration,
tier gate, action request, the canary wall, NDA-refusal and NDA-party — plus a 50-message flood.

**The first version paged the Allfather's desktop with 200 escalations**, because every unknown
answer escalates and the flood test sent 200. That is a real defect, not a test artefact: a hostile
sender could do the same. Fixed in two places — `SKIRNIR_NO_ESCALATE=1` for tests, and a hard cap of
**three escalations an hour** with the suppression itself written to the ledger.

## Also in this change

**Notifications became answerable.** He reported clicking Omarchy notifications and nothing happening;
they were one-way. Omarchy's notifier supports `--exec`, so `send.sh --ask` now records a question and
sends a notification whose click runs `approve.sh <id>` → a zenity Approve/Decline → the decision in the
vault and a Rune. One question, two answers, no silent default.
