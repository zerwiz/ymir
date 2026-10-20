# The Þing — the house’s meeting framework

**Status:** adopted 2026-10-20 · **Owner:** the Chair · **Applies to:** every the company meeting
**Recorded by:** Snotra · **Reviewed by:** the operator

A meeting is not a conversation with a calendar entry. It is the place where a decision
becomes binding and an action becomes someone's responsibility. This framework says who
does what, how a decision is made, and how every participant signs the record.

It borrows the name of the Norse assembly because the shape is the same: a called
assembly, a law-speaker, a recorder, a challenger, and a record that everyone stands
behind.

---

## 1. The four roles

Every meeting names four roles at the top of its agenda. One person may hold two roles in
a small meeting, but **the Chair and the Adjuster are never the same person** — the one
who drives cannot also be the one who tests.

| Role | Who | Owns | Does |
|---|---|---|---|
| **Chair** | one named person | the meeting and its decisions | calls it, sets the agenda, enforces the clock and decision rights, states each decision in one sentence, closes it, signs the final record |
| **Secretary** | one named person | the record | curates the draft, checks every action has an owner/date/done-when, publishes within 24 h, runs the sign-off, appends corrections |
| **Notetaker** | Snotra, or a person if Snotra is absent | the raw capture | records the transcript, timestamps, speakers; never edits the record |
| **Adjuster** | one named person, not the Chair | the quality of the decision | tests assumptions, names the option nobody named, records dissent and the cost of being wrong; cannot veto, but an unanswered objection blocks a Grade A decision |

**Participants** are everyone else present. They have two duties: bring the facts their
area owns, and sign the record.

The division is deliberate: the Chair is accountable for *what was decided*, the
Secretary for *whether the record is true*, the Adjuster for *whether the decision was
tested*. One person holding all three is how a meeting becomes a monologue with minutes.

---

## 2. Decision rights — DACI, one letter at a time

Every decision names its people before it is discussed, not after:

| Letter | Meaning | In the record |
|---|---|---|
| **D — Driver** | pushes the decision to closure | the Chair, or the person who tabled it |
| **A — Approver** | the one person who decides | `decided_by` |
| **C — Contributors** | consulted before the decision | participants quoted in the evidence |
| **I — Informed** | told after, not asked | the distribution list |

One Approver. Never "the team". If two people believe they are the Approver, the
decision is not ready; the Chair names one before discussion begins.

This is the same discipline as RAPID/DACI: the failure mode is rarely a lack of
information, it is an unnamed decider.

---

## 3. How a decision is made — consent, not unanimity

the company decides by **consent**: a proposal passes when no participant has a *reasoned
objection*. Silence is not consent; a reasoned objection is not a veto.

```
decide(proposal, grade):
  1. Chair states the proposal in one sentence.
  2. Adjuster names the strongest objection and the option not taken.
  3. Round of consent: "any reasoned objection?"
     - none            -> decided
     - objection       -> amend once; if it survives, record it
  4. If objection survives and grade is A -> do not decide today; park it with an owner
     and a date. Grade B -> Chair decides, dissent recorded. Grade C -> Chair decides.
  5. Record: statement, Approver, rationale, options considered, reversibility,
     review date, grade, dissent (if any).
```

Why consent rather than consensus: consensus seeks full agreement and stalls on the last
holdout; consent seeks "good enough for now, safe enough to try" and forces the objection
to be *reasoned* rather than merely held.

### The grades

| Grade | Meaning | Sign-off required |
|---|---|---|
| **A — one-way / strategic** | hard to reverse, moves the company | **explicit sign-off from every participant**; review date mandatory |
| **B — costly to reverse** | cross-team or product-wide | explicit sign-off from the Approver and every affected owner |
| **C — easily reversed** | process and operations | silence for two business days = provisional acceptance |

---

## 4. The record and its four states

| State | Meaning | Who moves it |
|---|---|---|
| **Draft** | Snotra has rendered it; not yet authoritative | Secretary |
| **Reviewed** | every action has an owner, a date and a done-when; every decision has an Approver and evidence | Secretary + Chair |
| **Approved** | participants have confirmed it or raised a correction | participants |
| **Signed** | the Chair signs the approved version; it is the official account | Chair |

A record is **approved** when it accurately reflects what happened — not when everyone
agrees with the decision. That distinction is the whole point: you sign the *truth of the
record*, not loyalty to the outcome.

**Corrections are appended, never rewritten.** A correction cites the entry it corrects
and the date. The original stays.

### Sign-off protocol

1. The Secretary publishes the Draft within **24 hours** with `record.pdf`, the registers,
   the raw transcript and each person's brief.
2. Each participant replies **`confirm`** or **`objection: <the correction>`** within
   **two business days**. A correction is not a re-vote; it fixes the record.
3. Grade A decisions require explicit `confirm` from every participant. Grade B requires
   the Approver and affected owners. Grade C accepts silence after two business days.
4. The Secretary records every reply in `signoffs.json` and renders `signoff.md`.
5. The Chair signs last. `signed_at` is the moment the record becomes official.

---

## 5. The cadence — four layers, four different jobs

| Layer | When | Length | Decides |
|---|---|---|---|
| **Daily** | written, async | 10 min | nothing; surfaces blockers |
| **Weekly** | Monday, fixed | 45 min | C decisions; what was planned, done, blocked |
| **Monthly** | first week | 90 min | B decisions; trajectory against the plan |
| **Quarterly** | end of quarter | half day | A decisions; capital, roles, strategy, review dates |

The rule that keeps them apart: **a question that belongs to a higher layer is parked,
not decided, in a lower one.** A strategic pivot raised in the Monday review gets an
owner and a date for the quarterly — it does not get decided while the clock runs.

The weekly is for unblocking, not relitigating. The monthly is for trajectory, not
status. The quarterly is for scoring outcomes and re-planning.

---

## 6. The agenda — one page, seven parts

```
1. Purpose          one sentence: what must be decided or resolved today
2. Roles            Chair · Secretary · Notetaker · Adjuster
3. Previous record  any correction to the last record? (2 min, then close)
4. Decisions        each: proposal · options · reversibility · recommendation ·
                    Approver · consent round · grade
5. Open questions   each: question · decider · needed by · blocking?
6. Actions          each: verb · deliverable · owner · due · done-when · depends on
7. Close            next meeting, sign-off window, who publishes
```

If an item does not fit one of the seven, it is not an agenda item; it is a conversation
that belongs in a smaller room.

---

## 7. The artifacts every meeting produces

| Artifact | What it is | Kept |
|---|---|---|
| `record.pdf` / `minutes.md` | the curated record | permanent |
| `decisions.md` | decisions with grade, options, dissent, review date | permanent |
| `actions.md` | actions with owner, date, done-when, dependency | permanent |
| `questions.md` | open questions with decider and needed-by | until answered |
| `transcript.md` | the raw evidence | 90 days, or while the source is kept |
| `signoffs.json` / `signoff.md` | who confirmed, who objected, when signed | permanent |
| `briefs/<person>.md` | each person's own actions | permanent |

The record is the reading; the transcript is the evidence. Neither replaces the other.

---

## 8. What good looks like — the tests

A meeting passes if all eight are true:

1. A named Chair, Secretary and Adjuster, and the Chair is not the Adjuster.
2. Every decision has one Approver, a rationale, and a timestamp.
3. Every Grade A decision has a review date.
4. Every action has one owner, one date, and a definition of done.
5. Open questions are named, owned, and dated.
6. The record is published within 24 hours.
7. Every participant has confirmed or corrected the record before it is Signed.
8. Dissent is recorded where it existed; no decision claims unanimous agreement it did not have.

---

## 9. Sources this framework rests on

- Chair/Secretary/Adjuster separation and timekeeping: Curtin *Good Practice Guidelines*;
  University of Cambridge *Effective Meetings Toolkit*; Open Group *Standards Process Guide*.
- Consent vs consensus and the reasoned objection: sociocratic consent practice
  (Umbrex; Talkspirit).
- One decider and named decision roles: Bain **RAPID**; **DACI/RACI**.
- Draft → Approved → Signed and the "approve the record, not the decision" distinction:
  SAP Signavio minutes workflow; board-room.org approval scripts; Loughborough and
  Manchester governance guidance.
- Four-layer operating cadence (weekly execution, monthly trajectory, quarterly strategy):
  Ascend *operating cadence stack*; Serendly; Vindaris.

---

## 10. Adoption

1. The next meeting names its four roles in the invitation.
2. Snotra renders the record and `signoffs.json`; the Secretary publishes within 24 h.
3. Every participant replies `confirm` or `objection: …`.
4. The Chair signs; the record moves to `signed`.
5. The framework is reviewed at the first quarterly meeting, and corrected by append.

---

## 11. Everyone is on the meeting and the agenda; every meeting ends with the open floor

**Appended 2026-10-20.**

Two rules were missing and are now part of the framework:

1. **Everyone is attached.** The meeting card and the proposed agenda card carry **all
   participants** as Trello members, not just the Chair and the Secretary. An agenda that
   is not shared with everyone is a plan for the few.
2. **The open floor is the last substantive item.** Before the close, every meeting gives
   ten minutes to **open questions and anything not on the agenda**. Anyone may raise a
   question, a concern or a proposal. It leaves as one of three things: a question with a
   decider and a needed-by date, an action with one owner and one date, or a recorded
   decision. Nothing is left as “we will talk about it”.

The agenda therefore ends:

```
5. Open floor — questions and anything not yet on the agenda (10 min)
6. Close — Secretary for the record, sign-off window, next date
```

The rendered `agenda-next.md` and the Trello `Agenda` card carry this automatically; the
meeting and agenda cards have all four members.
