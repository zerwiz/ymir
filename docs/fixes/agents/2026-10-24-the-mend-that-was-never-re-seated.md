# The mend that was never re-seated — a fixed installer beside a four-day-old hook

**Dated:** 2026-10-24 · **Component:** agents · **Branch:** `fix/eir-seats-the-gate`
**Found on:** sleipnir (the hand — Termux/Android, Pi 1.4.0)

## The symptom

A push from a Yggdrasil worktree was judged by the **main** checkout. This branch's sibling (#422)
regenerated `bin/README.md`, committed it, and was still refused by `inventory-guard` with *"bin/README.md
is STALE"* — because the hook was looking at a tree nobody was pushing. It was only pushable after the
register was regenerated in the main checkout as well, which is exactly the drift the gate exists to stop.

## The fault

`bin/gates/guards/fixes-guard.sh --install` was **fixed on 2026-10-20** to bake

```bash
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

into the hook, so a push is judged by the worktree it comes from. The hook already installed on this machine
still carried the old shape — the absolute path of the installing checkout:

```bash
"/data/…/ymir/bin/gates/guards.sh" || exit 1
```

and no `branch-current` check at all. The installer was right for four days while the installed artifact was
wrong, and **nothing ever compares the two**. Same class as plan 120's rule: *a harness fix is not delivered
until the session that shows it has started again* — here, a gate fix is not delivered until the gate itself
is re-seated.

## The fix

A `gates` surface in Eir, which checks the **artifact**, not the script:

- `s_gates` — the installed `pre-push` exists, is executable, resolves its root from the pushing worktree
  (`git rev-parse --show-toplevel`), and still asks `branch-current.sh` that the branch is based on current
  main.
- `f_gates` — the mend is the installer itself (`fixes-guard.sh --install`), then re-check.
- `detail gates` — names the state in one line, and names the remedy when it is stale.

## Verification

```
bash bin/agents/eir-doctor.sh check        → "gates","ok","pre-push hook: the worktree that pushes"

# prove the failure path by seating a stale hook on purpose:
echo '"/data/…/ymir/bin/gates/guards.sh" || exit 1' > <hooks>/pre-push
bash bin/agents/eir-doctor.sh check        → "gates","broken","installed hook is stale — … --install"
bash bin/gates/guards/fixes-guard.sh --install
bash bin/agents/eir-doctor.sh check        → "gates","ok","pre-push hook: the worktree that pushes"
```

`bin/README.md` is regenerated in the same change (the surface list and the script's line count moved).

## Restart

None. Eir reads the installed hook on every run; the next `eir-doctor.sh check` on any seat sees the truth.
