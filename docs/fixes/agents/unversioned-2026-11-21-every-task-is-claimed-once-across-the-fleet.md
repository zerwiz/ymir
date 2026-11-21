## agents · unversioned · 2026-11-21 — every task is claimed once, across the fleet (plan 343.12, 343.14)

### Why
On 2026-11-21 the machines collided. One seat reworked a PR after another seat had already merged it. Two PRs
were merged by one hand while another seat's judges were still reviewing them. One PR head was judged twice.
One branch received rework commits from two seats, and its own author could not fast-forward it.

The cause was a single fact. Each machine's errand record (`state/*.status`) is local and ignored by the home's
git. No seat could see another seat's work.

### What changed
- **`bin/agents/claim.sh`** is the claims ledger. A claim is a small file in the home at
  `state/claims/<key>/<role>`, shipped through `bin/vault/home-sync.sh` in the same act that writes it. The
  home's `.gitignore` now tracks `state/claims/` while `state/` stays private.
  - Keys: `pr:<owner>/<repo>#<n>`, `plan:<n>.<step>`, `branch:<owner>/<repo>:<name>`.
  - Commands: `take`, `show`, `check`, `heartbeat`, `release`, `list [--fleet]`.
  - A claim is per key and role. A judge and a coder may hold the same PR. Two coders may not.
  - `take` refuses a key another seat holds and names the holder's seat, errand and age.
  - A claim with no heartbeat for 2 hours is stale. It is offered, never stolen: `take` refuses it too
    unless the caller says `--adopt-stale`, and the old holder is recorded.
  - A claim is never deleted (Rule 11). `release` rewrites it as `state=released`.
  - A judge claim carries the PR head. A moved head is a new judgement and may be claimed.
- **`bin/agents/eindri-start.sh`** takes the claims before it seats anything: `--pr` and `--plan` name the
  task, and the errand's own branch is claimed too. A claimed task stops the errand with the holder's name. A
  claim taken here is released if the seat fails.
- **`bin/agents/eindri-review-spawn.sh`** claims the PR as `judge` for its head. A seat that finds another seat's
  judge on the same head stands down.
- **`bin/gates/guards/claim-guard.sh`**, called from `.githooks/pre-push`, refuses a push to a branch another
  seat holds as coder, with the holder named. `YMIR_SKIP_CLAIM_GUARD=1` is the loud override. It fails open,
  aloud, when the home cannot be read.
- `YMIR_CLAIMS=off` switches the start and review wiring off; `CLAIM_NO_SYNC=1` reads the local copy only.

### Verified
`tests/test_claims_ledger.sh` uses a fake home and two fake seats, each with its own clone of one bare origin.
It covers: sharing through git, refusal naming the holder, judge beside coder, a new head, the fleet list,
stale offered not stolen, adopt, heartbeat, release, a two-seat race with exactly one winner, and the push ward.

### Not done here
The standing shipper (343.13) is a separate phase. A claim closes on release, on the errand failing to seat, or
by going stale; closing it on merge belongs to the shipper.

### Files
- `bin/agents/claim.sh`
- `bin/gates/guards/claim-guard.sh`
- `bin/agents/eindri-start.sh`
- `bin/agents/eindri-review-spawn.sh`
- `.githooks/pre-push`
- `tests/test_claims_ledger.sh`
- `docs/features/the-claims-ledger.md`
