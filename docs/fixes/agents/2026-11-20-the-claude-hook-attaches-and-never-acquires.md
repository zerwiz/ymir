# The Claude arm hook attaches; it never acquires

**2026-11-20.** The Allfather, twice in a night: *"every time a Claude starts he takes the arm"* and *"it seems like
Claude Code have taken over the arm on heimdall — it was a pi who had it."*

`~/.claude/hooks/ymir-arm.sh` runs at **every Stop**, and the client it starts (`syn-watch-arm.sh`) **enters a
vacant helm** by design. So any Claude seat that stopped while no owner was visible became the primary and took
the lock from the seat holding it.

Measured, twice: the lock moved `2243828 → 1557290`, and again `477836 → 2425137`. The earlier repair was made in
the **installed copy only** — `~/.claude/hooks/ymir-arm.sh` — and an update re-seated the unpatched version from
this repository, so the fault returned. That is the lesson: a fix outside the repo is not a fix.

**The change:** the hook resolves the lock first and exits 0 unless **this** session is the recorded owner. It
attaches; it never acquires. Taking the helm stays a deliberate act — `bin/voice/rodd-arm.sh hold`.

Proved by: starting a Claude session while a pi seat holds the lock, then reading the owner — unchanged.
