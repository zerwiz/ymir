---
title: "Competitive advantage — research and evidence"
status: "accepted"
owner: "the project's collaboration-kit owner"
updated: "2026-11-11"
---

# Competitive advantage — how we research it, and how we are allowed to state it

**In every repository, the same two failures.** A studio says it is "senior, fast and
bespoke", and the buyer hears nothing, because the shop next door says the same words for
less money. Or the studio has a real edge and cannot prove it, so it loses the deal to a
weaker rival with a better-shaped sentence.

This shelf is the method that avoids both, and one gate that enforces the second half.

## 1 · The rule, first

> **A claim with an empty evidence line is deleted, never softened.**

An advantage is a sentence plus a measurement. If the measurement is missing, the sentence
stays out of the client-facing document until it exists — and it is marked as owed in the
internal one, with the date it is expected.

## 2 · The screen: does this advantage survive being looked at?

Run every candidate advantage through four questions. Anything that fails one is a
**feature**, not an advantage, and it belongs in a capabilities list, not a positioning
statement.

| Question | What it kills |
|---|---|
| **Valuable** — does it change a buyer's decision? | everything the buyer never mentions |
| **Rare** — do our competitors have it too? | "we use modern tools", "we communicate well" |
| **Costly to imitate** — how long would a rival need, and what would it cost them? | a process anyone can copy in a week |
| **Organised to exploit it** — can we actually sell and deliver it at our size? | an edge that needs a bench we do not have |

A candidate that passes all four is a real advantage. One that passes three is a **claim to
be earned** — say what would make it true, and by when.

## 3 · The competitive set: who we are actually up against

Not a listicle. In order of usefulness:

1. **Who we lose to.** Ask whoever runs the deals which three companies we lose to most,
   and pull the last two quarters of lost-to fields. That list is the truth; the rest is
   the internet.
2. **The comparison pages buyers look at.** The "frequently compared" modules of the review
   sites for our category.
3. **The obvious substitute.** Often not a competitor at all: a spreadsheet, an intern, a
   hire, a SaaS the client already pays for, or doing nothing. This is the rival we beat
   most often and understand least.
4. **The do-nothing case.** "We will revisit it next quarter" wins more deals than any
   agency does.

## 4 · The teardown: one page per rival, every fact dated

```
COMPETITOR: <name> · reviewed <date> · reviewed by <name>
  who they target        segments, company size, region, the buyer's title
  what they say          their headline, verbatim, and the date it was captured
  the category they claim
  their offer shape      fixed price · sprint · retainer · staff augmentation
  their pricing          published or stated, with the source
  their proof            named clients, case studies, numbers, certifications
  their gap              what they cannot say, cannot staff, or will not touch
  our counter            one sentence, with our evidence
```

Verbatim, not paraphrased: their own words are what a buyer will compare us against.

## 5 · Where an advantage actually comes from, at our size

Four sources, in the order they usually pay:

1. **A live proof.** We run the thing ourselves. A pilot is an opinion; a running business
   is evidence.
2. **A regulated market's requirement nobody wants to meet.** Governance, audit, approval
   paths, data location. Boring, expensive, and a moat when it is in the shipped code.
3. **A vertical nobody has productised.** The same problem, in the same industry, solved
   with the same components for the third time — that is where the margin is.
4. **A way of working the client can see.** Signed scope, acceptance per function,
   evidence-backed invoices. Buyers of small shops are not afraid of the technology; they
   are afraid of surprises.

**What is not an advantage:** speed without a baseline, seniority without a signature,
"AI-powered" without a named capability, and price. Price is a decision someone else makes
for you.

## 6 · The cadence

| When | What | Owner |
|---|---|---|
| Every lost deal | one paragraph: who won, what they said, what we could not prove | whoever ran the deal |
| Quarterly | refresh the competitive set and the teardown pages | the commercial lead |
| Before any client-facing document | run the gate below | whoever wrote it |
| After each engagement | did the evidence line get filled? If not, why not | the technical lead |

## 7 · The gate

```bash
scripts/advantage-audit.sh <claims-document.md>              # every evidence line present?
scripts/advantage-audit.sh --strict --check <client-page.md> # refuse a page of adjectives
scripts/advantage-audit.sh --json <doc.md>                   # for a board or a report
```

It reads a document of claims, finds the `**Evidence:**` line inside each section, and
refuses when the line is empty, an unfilled blank, or too thin to check. Exit 1 means the page
is not ready to send — and it names the line to fix, which is the only useful kind of
refusal.

## 8 · The output, in two files

- **Internal** — four to six advantages, each with its evidence, its **limit**, and the
  places we are honestly not advantaged. If this document has no weaknesses in it, it is
  marketing, and nobody will trust the strengths either.
- **Client-facing** — the same advantages, evidence filled, plus what we will not claim and
  the questions we invite a client to test us with. This file passes the gate or it does
  not go out.

## Sources

- VRIO and the resource-based view — <https://www.mindtools.com/your-toolkit/strategy-analysis/vrio-analysis/>,
  <https://open.oregonstate.education/strategicmanagement2e/chapter/4-vrio-analysis/>
- Competitive set from won/lost, and the teardown matrix —
  <https://metaflow.life/blog/how-to-do-competitive-analysis>,
  <https://edithly.com/knowledge-hub/competitor-research-template/>
- Productising by *problem* rather than by solution, and the 80/20 reading of past
  engagements — <https://amitkoth.com/productizing-ai-services/>,
  <https://www.beltcourse.com/blog/build-a-category-of-one-ai-agency-offers-pricing-and-markets-that-actually-buy>
- Niche as the precondition for a specialist rate — <https://vibeengines.com/handbook/ai-consultant>

## CHANGE LOG

- **2026-11-06** — the method opened with the gate (plan 207).

## References

- `scripts/advantage-audit.sh`, `docs/gates.md`
- `docs/headers.md` — the header and References format this document follows
