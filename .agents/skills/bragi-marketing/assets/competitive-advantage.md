# Competitive advantage — the research, the teardown, and the evidence gate

**Load this when** the task is: state why we win, research a competitor, prepare a
client-facing "why us", price against a rival, or answer "what is our competitive
advantage?". Bragi owns the market-facing craft; this asset is the part that must be true.

## The law that governs it

> A claim with an empty evidence line is deleted, never softened.

An advantage is **a sentence plus a measurement**. The measurement is a date, a number, a
link to a record, a signed acceptance, or a named person who will defend it. Adjectives
lose to whoever is cheaper.

## The two files, and they are different

| File | Audience | Contains | Tone |
|---|---|---|---|
| the internal one | the leads | advantages **with their limits**, and the places we are not advantaged | blunt |
| the client-facing one | a buyer | the same advantages with evidence filled, what we will not claim, and the questions we invite | confident, checkable |

An internal document with no weaknesses in it is marketing, and a buyer discounts the
strengths with it.

## The method

1. **Build the competitive set from the deals, not from the internet.** Ask the closer which
   three rivals we lose to; pull the lost-to fields; add the obvious substitute (a
   spreadsheet, an intern, a SaaS already paid for) and the do-nothing case.
2. **Screen every candidate** through VRIO: valuable · rare · costly to imitate · are we
   organised to exploit it. Three of four is **a claim to be earned** — name what would make
   it true and by when.
3. **Tear down one rival per page**, every fact dated and their words **verbatim** — their
   headline, their category, their offer shape, their pricing source, their proof, their gap,
   our counter. The full field list is in the kit's `docs/advantage.md`.
4. **Collect with the engines, not with memory.** Firecrawl scrapes their pages to markdown
   (quote the headline and date the capture); browser-use drives a logged-in comparison page
   when a review site hides it. Never paraphrase a competitor's positioning — a buyer will
   compare us against their exact words. The home pack's `competitor-profiling` skill runs
   the URL-driven collection loop; this asset decides what the findings **mean** and what we
   are allowed to claim about them.
5. **State the advantage in the four places it actually comes from**: a live proof (we run
   the thing), a regulated requirement met in shipped code (governance, audit, approvals),
   a vertical nobody has productised, and a way of working the client can see.
6. **Run the gate before anything goes out.**

```bash
scripts/advantage-audit.sh <internal doc>                   # evidence present, section by section
scripts/advantage-audit.sh --strict --check <client page>    # refuse a page of adjectives
bin/collab/kit/scripts/advantage-audit.sh --json <doc>       # from the platform repo
```

Exit 1 is a refusal with the line to fix. A page that fails the gate is not ready to send —
that is the whole point, and it is the only kind of refusal worth having.

## The cadence

- **Every lost deal:** one paragraph — who won, in what words, and what we could not prove.
- **Quarterly:** refresh the set and the teardown pages; the commercial lead owns it.
- **Before any client-facing document:** run the gate.
- **After each engagement:** did the evidence line get filled? If not, why not — that answer
  is the real strategy review.

## What this asset refuses

- **A positioning statement with no evidence.** It does not ship.
- **Price as the advantage.** Price is a decision someone else makes for you.
- **"AI-powered"** without a named capability and its limit.
- **A teardown without a date and a source.** An undated fact about a rival is a rumour.
- **A competitor's words paraphrased.** Quote them or leave them out.

## Where the rules live

- method and fields: `bin/collab/kit/docs/advantage.md` (installed into a standardised repo
  as `docs/advantage.md`)
- the gate: `bin/collab/kit/scripts/advantage-audit.sh` (installed as
  `scripts/advantage-audit.sh`)
- research engines: this skill's §1 — Firecrawl and browser-use
