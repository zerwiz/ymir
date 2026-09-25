# THE STANDARD

**Purpose.** Ymir is a runtime you install on a machine you own, which turns that machine
into a place where agents work under your standards, with your data never leaving. It is a
distro. Its value is not the services it runs, it is that after one install the machine is
governed: the work is standardised, the data is sovereign, and the behaviour is provable.

Everything here is derived from that sentence. Anything not derived from it is preference.

---

## The rule of this document

> **A claim is not a claim until a command decides it.**

Every clause below carries the command that can falsify it. A clause whose command does not
exist is marked **GAP**, and a gap is a debt, not a footnote. We do not present a clause as
true while its command is missing.

```
purpose[5]{clause,the_assertion,the_command,status}:
  "install on a machine you own","a fresh machine reaches the governed state in one unattended action; running it twice changes nothing; removing it leaves the operator's home untouched","bin/prove-install.sh --fresh","GAP"
  "your data never leaves","with a canary planted in the home, the full exercise runs under recorded egress; the canary appears in no outbound payload, and only allowlisted endpoints are contacted","bin/prove-egress.sh","GAP (same machinery as the Utgard sandbox, so not extra work)"
  "agents work under your standards","for a named standard set the compliance rate clears a stated threshold at a stated n, with intervals reported, and the instrument passes its own discriminative-power test","bin/prove-standard.sh --set <name> --models <a,b>","INSTRUMENT EXISTS for one rule set; wrapper missing"
  "the behaviour is provable","a stranger re-runs every substantive claim and gets the same verdict; no claim escapes a command; no figure in the material is untagged","bin/prove-claims.sh","PARTIAL: the ledger exists, the claims registry does not"
  "it is worth building","NOT PROVABLE BY US. We pre-register what would make us stop, and the market decides","a dated, signed prediction in the ledger","BY DESIGN, NOT OURS"
```

## How each command must be built

**`prove-install.sh --fresh`** must be adversarial, not a rehearsal. A machine with nothing on
it, no author present, no hand-holding. It records: wall clock, manual steps (target zero),
failed steps, and whether a second run is a no-op. It exits non-zero if the machine is not
governed at the end, and the verdict is a TOON row, not a feeling.

**`prove-egress.sh`** must try to find a leak, not confirm the absence of one. Plant a canary
in the home, run the whole exercise with egress recorded at the boundary, then assert: the
canary appears in no payload that crossed, and every endpoint contacted is on the declared
allowlist. Silence is not evidence; a failed grep is.

**`prove-standard.sh`** wraps the instrument we already built (the differential with Wilson
intervals and the discriminative-power refusal). It must state the threshold and the n
*before* it runs, and report intervals, never a bare score.

**`prove-claims.sh`** walks a claims registry: every figure and every promise in the outward
material, each bound to the command that reproduces it. It fails on a claim with no command
and on an untagged figure. This is the clause that makes the pitch auditable rather than
persuasive.

**The fifth clause is not ours to prove.** We write down, dated, what evidence would make us
stop, and we let a buyer close it. Pretending a test can decide it would be the exact
dishonesty this document exists to forbid.

---

## Two modes, and only two

Most of the mess in this system came from one machine doing both at once.

```
modes[2]{mode,source,state,who}:
  "workbench","a checkout you edit. Mutable. The system may build here, never run from here","state beside the tree, disposable, gitignored","the person developing the runtime"
  "deployment","an immutable artifact. The checkout is never written to","one machine-local root outside the tree; the operator's home is theirs","the operator, and anyone replicating it"
```

A file that names a path, a port, a lock or a store must say which mode it means. A runtime
artifact in a workbench is declared. A runtime artifact in a deployment is impossible,
because the artifact cannot be written.

---

## How the standard is demanded

A standard that each project re-implements per repository is not a standard, it is a habit.
So the demand is uniform and it lives in the gate:

- **one source of wards**, adopted by every project rather than rewritten in each
- the gate runs on every push and in CI, so a project without the gate is not one we work in
- every lock names its rule in its failure message, because a refusal that does not teach is
  just an obstacle
- a waiver is a written decision on the line itself, never a quiet bypass

```
locks[6]{class,a_lock_that_ends_it}:
  "a runtime writes into its own tree","prove the tree does not move while the system runs"
  "a second identity or a guessed home","refuse any literal that restates where things live"
  "machine state in the synced home","refuse a lock, pid, socket or store under the home"
  "silent failure","refuse an entry path that cannot fail, absent a written waiver"
  "config read by pattern","refuse a sed-based read of a configuration file"
  "an unbacked claim","refuse a claim with no command"
```

**A lock is accepted only when it fires on a real breach.** A ward that stays silent on a
known fault is theatre, and theatre is the thing we are removing.

---

## The acceptance test

> **A stranger installs it, upgrades it, replicates it and removes it on a machine we have
> never seen, without reading this file, and nothing they do can touch a service that is
> already running.**

That sentence is the specification. If the documentation needs to be longer than the machine
demands, the machine is not doing its job.

## What we do not claim

- anything whose command does not exist yet
- that it is worth building
- that a passing test means a good product

The first is a debt we pay. The second is not ours to pay. The third is the mistake that makes
engineers distrust other engineers, and we will not add to that pile.
