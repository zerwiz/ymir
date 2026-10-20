# The council of models, and a blanket kill is now a blocked commit

**Date:** 2026-10-20 · **Component:** `extensions` + `guard` · **Plan:** 92 · **Rule:** 24 (the ward), 13 (Pi extensions)

## What was built

**1 · Lögrétta — the council of models (`.pi/extensions/logretta/`).**

A Pi extension that seats 2–5 different models on one question. Each seat is a **separate
clean-room `pi` process** (`-p --mode json --no-session --no-extensions --model <id> --tools
read,grep,find,ls`, prompt over stdin), because pi's own model is fixed per session — a different
model per seat requires a different process. Three rounds:

```
opinion  · every seat answers through its REMIT, in a fixed contract
debate   · each seat reads the others (delimited as untrusted) and must open HOLD: or CHANGE:
verdict  · the arbiter merges, names the disagreements, owns the risks, orders next actions
```

Six production remits ship — `architect · security · cost · skeptic · operator · recon` — each a
full brief, plus a shared **charter** that every seat receives (advise, don't act; argue from your
remit; be concrete; separate knowledge from assumption; you may refuse and name what is missing).

A stack is `$YMIR_HOME/config/logretta-stack.yaml`, 2–5 slots, each `name · model · lens · rail`
with `rail: local|fleet|hosted`; the printer shows the honest queue before anything is spent, since
a `--models-max 1` rail makes local seats serial. A `max_total_chars` budget stops the council
loudly. It writes nothing: the verdict is returned, and the caller records it with Elder.

**2 · `pkill-guard` — a blanket kill is refused at the gate (`bin/gates/guards/pkill-guard.sh`).**

Measured 2026-10-20, twice in one session: `pkill -f "<pattern>"` matched the shell that ran it —
because `pkill -f` matches the whole command LINE, and the caller's own command line contains the
pattern. A blanket kill does not know what it is killing: it takes an agent's own process tree, a
sibling's pane, or the next unrelated process carrying the name.

The guard refuses a push whose **added lines** invoke `pkill` or `killall` in a code file. It
distinguishes an invocation from a mention (a comment, the tool's own name, a vendored
banned-pattern list under `.compliance/`), and it has one documented escape written on the same
line: `# pkill-allowed: <why a pid will not do>`. `--scan` audits the whole tree and classifies
every hit.

**The two real hits it found, and mended:**

| where | what it did | now |
|---|---|---|
| `bin/fleet/ymir-platform.sh:100` | `pkill -"$sig" -f -- "$pat"` | a pid scan that excludes its own pid, its parent, and any line containing itself — the same door, named targets only |
| `.pi/extensions/excalidraw/index.ts:178` | a tool description *mentioning* a blanket kill | reworded, so the tree has **zero** invocations |

## Why it matters

The council is the first door that lets the house put several models on one question without a
desktop app and without a second runtime. The pkill guard closes the failure that cost two shells
in one session — the class of bug where the tool kills the thing that is using it.

## How it was proved

```
.agents/tests/logretta.test.sh   20/20, with a STUB pi: no model, no money
  · N seats = N children; each gets its OWN model; --no-extensions; --tools read,grep,find,ls
  · the charter, the opinion contract, the HOLD/CHANGE contract, the arbiter brief and the
    verdict contract are all present in what a seat receives
  · another seat's answer is delimited as untrusted
  · a failed seat is named and the council still converges
  · invalid stacks fail loudly (unknown key, bad rail, <2 slots, non-qualified model id);
    a missing stack is a loud skip, never an invented roster
  · the budget line stops the council
bin/gates/guards/pkill-guard.sh --scan   invocations: 0
bin/gates/guards.sh                       pkill-guard PASS (defaults-guard FAIL is pre-existing,
                                          bin/time/snotra/calendar-auth.sh:23 hardcodes the home)
```

**A real sitting** (two local seats, `qwen3.5-9b@q4_k_s` and `…-summarizer`, rounds=1) produced a
verdict naming the failure and the seat it followed — 328 s, because both seats are local and the
rail holds one model at a time. That wall clock is the honest cost of a local-only council.

## Not done

- The verdict is not written automatically (plan 92 L4: Elder + the well + Skuld).
- No herdr-pane mode yet (L3) — the watchable shape.
- Vault mode (`confidential.sh` + refusing hosted rails) is documented, not enforced by code (L5).
