# The Runes ledger has one chair, and the fleet has four seats

**A study of a single-writer limitation in the append-only audit chain, and of four
mechanisms worth taking from hashgraph to mend it.**

Opened 2026-10-06, after the Allfather asked *"how could this benefit us"* about
**SWIRLDS-TR-2016-02 — "Hashgraph Consensus: Detailed Examples"** (Leemon Baird, Dec 2016,
rev. Feb 2018). The paper was read whole. This document records what the reading found.

**This is a study, not a plan.** The plan is in the vault:
`~/Documents/ymirhome/svartalfaheim/whynotproductions/projects/ymir/plans/71-the-dag-runes-provable-ledger.md`.
This document is the *engineering* companion: the proof, the design, and the reasoning, with
every claim tied to a line of code. Nothing here is private; the plan carries the decision.

---

## 1. The claim, in one sentence

> The Runes ledger is a **linear hash chain**, and a linear chain admits **exactly one legal
> writer** — but `$YMIR_HOME` is cloned onto **four seats** that each append to it locally.

## 2. The proof, from the code

`src/ymir_runtime/state/runes.py` is the chain law. `append()`:

```python
fcntl.flock(handle.fileno(), fcntl.LOCK_EX)     # one exclusive lock
prev = last_checksum(target)                    # read the tail
checksum = compute(stamp, actor, event, message, prev, ...)
```

and the module header states the invariant in its own words:

```
fold     checksum = sha256(prev + "\n" + base)
lock     one exclusive flock around read-previous + append
```

The lock is real — but it is a lock over **one file on one machine**. It says nothing about the
other three.

Now the other half. `bin/time/nornir-job-git-sync.sh`:

```
line 103:  git -C "$target" merge --ff-only "$upstream"
line 124:  git -C "$target" push "$REMOTE" HEAD      # never force
```

Put the two together and the failure is not a matter of probability:

1. Two seats append between pulls. Each reads **its own stale tail**.
2. Each folds a **valid** checksum from that stale `prev` — neither is corrupt.
3. `git` brings two lines that share one `prev` into one file. The *paths* are fine; the
   **chain** forks.
4. `verify()` sees the parity break.
5. The module's own law: **"a parity mismatch is a refusal, not an overwrite."**

**The ledger is then stuck — permanently.** `--ff-only` will not converge divergent branches, and
resolving a forked chain by hand means rewriting entries, which **Rule 06 (append-only)** forbids.
There is no legal repair.

**Stated honestly:** this is read from the code. No seat has been *observed* to fork the chain.
The distinction is preserved deliberately — the code permits it, and the law forbids the fix.

## 3. Why the obvious remedies are wrong

| Tempting remedy | Why it fails |
|---|---|
| Lock across seats | A lock needs a shared, always-reachable resource. The seats are offline-first by design; a seat with no network cannot wait on a lock. |
| Make the ledger single-writer (one seat carves, others queue) | Legal, and much cheaper than the DAG — but it makes one seat's availability the ledger's availability, and it yields **agreement, not proof**. |
| Loosen `verify()` to tolerate forks | This is the worst one. It trades a visible, recoverable error for a silent corruption of the audit spine. **Never.** |
| Merge with `git merge -X ours/theirs` | Resolves the *file*, not the *chain*, and breaks `--ff-only` for every later sync. |

## 4. What hashgraph offers, and what it does not

The paper is a **teaching document** — one annotated diagram per step, from gossip and events
through witnesses, fame elections and strongly-see, to consensus timestamp and consensus order. It
is not a whitepaper, and it is not Hedera: the network, the staking and the council are a product
wrapped around the algorithm. (And it is a 2016 teaching text, not a build spec — it predates the
address book, key rotation and HIP-32.)

**Adopted:**

| Mechanism | What it gives us here |
|---|---|
| **Event** = self-parent + other-parents + timestamp + creator signature | The unit becomes a branch, not a line. Two writers is two branches, not a conflict. |
| **Gossip as an event** (a sync *is* recorded) | An errand's provenance is its own communication history. |
| **Consensus order derived from the graph** | The canonical order is **computed**, never asserted — so no merge can contradict it. |
| **Median consensus timestamp** | Clock skew across four boxes silently mis-orders history today. The median of the witnesses immunises it. |
| **"You cannot see a cheater"** (`see` = ancestry *except* an equivocating creator) | An agent that forks is not caught by a hook — it is **structurally invisible** to the derivation. Rule 08 becomes a property of the data, not of a pre-receive gate. |

**Refused:** witnesses, fame elections, strongly-see, coin rounds, and Hedera itself.

> **Why, in one paragraph:** fame elections exist to make a **Byzantine** fault tolerable among
> mutually distrustful nodes. That is not our threat model. The Allfather decided, explicitly,
> that the fleet needs entries **provable independent of any one seat's disk** — tamper-evidence,
> not Byzantine consensus. A signed DAG with equivocation quarantine delivers that for a fraction of
> the cost. Building the election machinery would be scope creep against a recorded decision.

## 5. The design: split the truth from the view

One architectural move mends all three wounds — the chain fork, the missing order across machines,
and the hook-based cheater catch.

```
hodd/memory/runes/events/<seat>/<seq>.json   ← TRUTH: one signed event per file, never rewritten
hodd/memory/runes/runes_audit.md             ← PROJECTION: generated, never hand-edited
```

**Why the fork problem dies:** each seat writes **only under its own directory**. Paths are
disjoint, so git merges cleanly *by construction* — there is no shared file left to conflict on.

**The derived order**, identical on every seat: topological (causal) order → ties by **median
timestamp** → ties by **hash**.

**Equivocation is excluded by rule, not by vote.** If one seat emits two events sharing a
`self_parent`, **all** of its equivocating siblings are excluded from the projection —
deterministically, identically everywhere. Nothing is deleted (Rule 06 holds): **exclusion is a
derivation**, which is exactly what makes it trustworthy.

### The kinship this did not see at first

Plan **65 — The Well that combines** already chose this shape, one shelf over. Measured 2026-10-02,
the artefact that *could* merge was *"designed, named in the owning asset, and never built"*, so
what travelled between seats was a 2.1 MB binary SQLite that git can move and cannot merge. Its
law:

> **the log is the truth; SQLite is a per-seat cache.** Combining two seats is a **union** —
> conflict-free by construction, idempotent, order-independent, offline-first for free.

This design is not a new idea. It applies the same law to the ledger. And the same lesson repeats:
**an artefact that is designed but never built is the failure mode the Runes chain is in.**

## 6. Two rules for anyone who builds this

1. **The existing `.md` ledger is history.** It stays byte-identical. The first projection must
   equal the current chain **exactly** — that equality is the acceptance test, not a nicety.
2. **One reader, not two.** When the event set lands, the well's episode log and the Runes events
   are the same kind of artefact in two places. Build one reader and one merge rule, or the house
   will have re-created the *"five ways to start one thing"* seam that `register.md` already
   records as a live defect.

## 8. Measured: the fork has already happened four times

**Added 2026-10-07.** Section 2 said, carefully, that the fork was *read from the code, not
observed*. That distinction is now closed:

```
$ runes.verify()
runes verify -> False   chain break at 2026-09-12T01:11:28Z
```

366 entries parsed; **four `prev` values are each claimed by two entries.** The first is the
proof of the whole thesis:

| `prev` | claimed by |
|---|---|
| `f039a97562bf2a89…` | `2026-09-12T01:11:28Z brokk harness.open-editor` · `2026-09-12T21:00:08Z yggdrasil git.sync` |
| `0aeae70cb3e01de9…` | `2026-09-20T00:29:41Z brokk pr.reconcile…` · `2026-09-20T17:03:20Z brokk well.birth-race.fixed` |
| `f6a915a21504fbb7…` | `2026-09-21T21:15:09Z muninn memory.housekeeping` · `2026-09-21T21:15:44Z muninn memory.housekeeping` |
| *(fourth, same shape)* | — |

Two different writers claiming one parent twenty hours apart is two seats, each folding a
valid checksum from the tail it could see. The ledger has been **unverifiable for twenty-four
days** — and the failure has the shape this document is about: it still *accepts* appends and
still *returns* a checksum. It only fails when something asks it to **prove itself**.

**What this changes:** nothing in the design, and it sharpens the scope. The projector must
reconcile **four real forks**, and consensus order *across* a fork must be defined and tested
before any migration. The forks are **not** to be collapsed to one branch: two branches is the
honest record that two seats were writing at once, and Rule 06 forbids the alternative.

## 9. Related

- **Plan 71** (vault) — the phases, the acceptance criteria, and what is dropped if the premise changes.
- **Fix note** `docs/fixes/agents/unversioned-2026-10-06-the-errand-door-reported-every-verdict-wrong.md`
  — the three silent failures met on the way to filing the plan. Same species of bug: **silence
  shaped exactly like success.**