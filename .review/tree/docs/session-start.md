# Session Start & Seating — Sága, the digest

When a harness opens in `$YMIR_ROOT`, Brokk must take the high seat
**before the first turn**: the session context is injected, the model bridge is
raised, the Nornir jobs start, and the session lock binds to the live process.
This document records how that mechanism works, how it compares to the validated
upstream agent-distro it was ported from, and how to verify it. The runtime spec
is `docs/plans/29-brokk-distro-runtime.md`; the lore is `docs/lore.md` §XII.

## The two tiers

A harness either **runs** the digest and has its output gated into model context,
or is **nudged** to run it. The tier is a property of the harness surface.

```
tiers[2]{tier,mechanism,harnesses}:
  "Run","the adapter runs the digest before the first turn and injects its stdout as a context message","Claude Code, Codex exec, Pi, Cursor"
  "Nudge","the adapter asks the agent to run the digest","Grok, OpenCode"
```

The nudge tier can only ask; an agent may defer. The run tier removes that
discretion, which is why it is preferred wherever the harness supports it.

## The Pi run-tier flow

```
pi_flow[6]{id,step,owner}:
  1,"Pi fires session_start with a reason (startup|new|resume|fork)","Pi"
  2,"the extension maps the reason to a Sága source and starts one digest generation","syn-turnend-guard.ts"
  3,"the digest runs under a bounded child supervisor","vordr-sessionstart-supervisor.mjs -> bin/saga-sessionstart-run.sh"
  4,"before_agent_start awaits the generation and returns one persistent message","syn-turnend-guard.ts"
  5,"the message is Rödd-encoded (customType brokk-sessionstart-nudge) and delivered","Rödd"
  6,"compaction re-emits; shutdown retires the generation","syn-turnend-guard.ts"
```

Source routing (owned by `bin/saga-sessionstart-run.sh`):

```
sources[4]{source,action}:
  "startup, new","full digest"
  "clear, compact","re-emit after a proven complete startup, else full digest"
  "resume, reload, fork","delegate to the nudge (prior context restored)"
  "unrecognized","full digest (taking the seat twice is cheap; not taking it is the bug)"
```

## The digest (Sága)

`bin/saga-session-start.sh` prints one ordered digest. It starts the runtime
pieces the session owns:

```
saga_stages[8]{stage,does}:
  "LOCK","acquires the per-home lock; a refused lock is read-only"
  "BOOTSTRAP","tool floors; raises the Bifrost model bridge; realm env check"
  "WAKE QUEUE","presents durable wakes and open decisions"
  "SUPERVISION","the operating note for the detected harness"
  "FLEET DIGEST","state metadata and open forge orders"
  "CONTEXT DIGEST","realm, operator, projects, learnings (ABSENT explicit)"
  "CRON START","starts the Nornir schedule if stopped"
  "NEXT STEP","the closing pointer"
```

## Why it can look like "no injection"

The digest is delivered as a **custom context message with `display: false`** —
the same as the upstream distro. It is present in model context but never
rendered in the transcript, and it does not make the model visibly act. A first
reply of "Greetings, Allfather" is a model choosing to greet, not evidence the
digest is missing. The cron and the lock are the observable side-effects.

## Verify it

```
verify[4]{check,how}:
  "injection happened","the session JSONL has a custom_message with customType brokk-sessionstart-nudge"
  "lock bound","state/.lock holds the live harness pid"
  "digest ran","state/.session-start-complete exists for this lock"
  "cron started","bash bin/nornir-cron-start.sh --status prints running"
```

One-liners:

```bash
rg -n "brokk-sessionstart-nudge|CRON START" ~/.pi/agent/sessions/--home-zerwiz-Ymir--/*.jsonl | tail
cat state/.lock; cat state/.session-start-complete
bash bin/nornir-cron-start.sh --status
```

## Make it visible or auto-arm (optional divergence)

The upstream distro and Ymir both keep the injection hidden and leave watcher
arming to the agent (OpenCode arms on `session.idle`; Pi arms through the
watch-arm tool). To diverge:

```
options[2]{change,effect}:
  "display=true or a `/saga` command","show a one-line marker at session start"
  "arm Sýn on boot in syn-turnend-guard.ts","supervision is live without the agent acting"
```

## Provenance

Ported from the validated upstream agent-distro (read-only reference) for
[plan 29](plans/29-brokk-distro-runtime.md); the Norse names and the Brokk/Allfather
substitutions are ours. The upstream's own contract is its `docs/sessionstart-nudge.md`.
