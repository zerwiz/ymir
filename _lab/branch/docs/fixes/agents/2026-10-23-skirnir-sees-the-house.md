# Skírnir sees the house, and stops mistaking "ymir" for a subject

**Date:** 2026-10-23 · **Component:** agents (assistant) · **Plan:** 101

## The report

The Allfather, twice: *"why can't I see my full ymir home in Skírnir"* and *"there's bugs in Skírnir's
messaging — he's talking about the wrong things."* Both were true, and they were one disease with
two symptoms.

## Measured before any change

```
what is in my ymir home      → fact:feature-the-ward-v-r-r   ("Ymir has a feature: The ward …")
what does hodd contain       → fact:feature-the-secrets-vault…
what is plan 116             → "That one isn't in what's approved."
what are the rules of the house → "That one isn't in what's approved."
what is the mail desk        → "That one isn't in what's approved."
```

## Fault A — the home was never in his book

His digest held 308 approved claims, 95 of them `FEATURES.md` rows, and **not one fact about the
home itself**: no shelf, no rule, no plan. A question about the home could only match a feature's
words, which is why the ward answered a question about the home.

**The mend:** `bin/assistant/learn-home.sh` — a second learning door. It writes one fact per
**document** (its own `# heading` and `**Status:**`, never a parsed sentence), per rule, per plan in
the ledger, per home tool, and one fact naming the shelves. 357 facts tonight, 42 retired, idempotent
by slug, and the documentary approval is `approved_by: document` — **a machine never signs for him**:
`kb-export.sh` accepts that word for `class: internal` and refuses it everywhere else.

The first attempt parsed `docs/INDEX.md` with a regex. It produced "The Allfather's home holds Last
updated — 2026-09-20" — facts that look thorough and are noise. The walls test caught it within the
hour; the parser now reads documents, not prose.

## Fault B — a word in every claim is not a subject

Every feature fact opens `Ymir has a feature: …`, so `head(claim)` contains **ymir** for all 95 of
them, and `hit_head >= 1` made every one of them a candidate for any question mentioning Ymir. The
first one in iteration order won.

**The mend:** the retrieval now computes document frequency over the digest and drops tokens carried
by more than a sixth of it from the *query* — if that empties the query it keeps the rarest half.
"ymir" and "home" stop being subjects; "faktura", "ward", "plan 116" remain.

## Fault C — the wall refused the Allfather his own plan

Answering "what is plan 116" returned *"My own gate refused that answer"*: the derived canary list is
every plan **slug**, and a plan's title normalises into its own slug (`116 gna the one mail desk`).
The wall now splits by tier: the hand-written canaries (vault markers, security posture) bind
**everyone, always**; the derived plan slugs bind everyone who is not the owner.

```
stranger: "what is plan 116" → "Before I pass this to him — who are you, what does it concern…"
owner:    "what is plan 116" → "Plan 116: Gná, the one mail desk … — status proposed."
```

## After

```
what is in my ymir home        → the shelves under hodd/, named
what is plan 116               → the plan, its title and status
what are the rules of the house → 30 rules, read out
what is the mail desk          → plan 116 (the desk's own plan)
what is snotra                 → the meeting ear and the engine under it
```

## Honest state of the suite

- `bin/assistant/smoke.sh` — **34 pass · 2 skip · 1 fail**; the failure is the far-side ear
  (whisper silent on `:10300`), not the mouth.
- `bin/assistant/walls-test.sh` — **8 failures, against 9 on `origin/main`** before this change.
  They are pre-existing (`KeyError: 'ENGINE'` in the model-context, handoff and language probes;
  content-quality assertions on the vault and posture probes). This change does not add one, and
  removes one, but the suite is not green and that is a debt, not a pass.

## Also

`learn-home.sh` must run before the nightly export. The row (`03:05 bin/assistant/learn-home.sh`) is
armed as a comment in the home's cron until this branch merges — `cron-guard` refuses a row naming a
script the tree does not carry.
