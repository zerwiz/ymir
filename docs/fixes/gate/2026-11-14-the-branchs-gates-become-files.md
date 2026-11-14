## gate · 2026-11-14 — this batch's nine gates move out of ci-verify.sh into checks.d

### Why

PR #750 (a gathered batch) was **CONFLICTING** on `bin/gates/ci-verify.sh` — the file every branch edited to add its
gate, and the reason fourteen sound pull requests could not merge. While this batch sat open, main landed #767: the
gate list is now a **directory**, `bin/gates/checks.d/<NNNN>-<name>.sh`, read in C order, so two branches that each
add a gate add two different files and never collide again.

### The resolution — the interim rule, applied

1. `bin/gates/ci-verify.sh` is main's, **whole** (`git checkout origin/main -- bin/gates/ci-verify.sh`);
2. this batch's own gate lines became nine files of their own, comments and all:

```
0400-bifrost-provider.sh        0450-gjallarhorn-no-hall.sh
0410-chat-ladder.sh             0460-rules-compliance-env-file.sh
0420-vram-ledger.sh             0470-handoff-packet.sh
0430-voice-idle-out.sh          0480-saga-head.sh
0440-unit-path-shims.sh
```

Each keeps the fault it answers in its header comment, exactly as it stood in the old list. The numbers start at 0400
— the highest gate main carries is 0390 — so they run after every existing gate and leave room between them.

### The second conflict

`bin/gates/guards/fixes-guard.sh` conflicted on its `path_component()` map: main added `bin/gates/checks.d/*` to the
gate row, and this batch had added a row for the agnostic audit. A union: the batch's row kept, and main's newer gate
row (which names `checks.d`) used for the rest — the two facts do not compete.

### Proof

`bash -n` is clean on `ci-verify.sh`, `fixes-guard.sh` and all nine gate files; no conflict marker survives; the
driver reads the directory (`checks.d` named in `ci-verify.sh`).
