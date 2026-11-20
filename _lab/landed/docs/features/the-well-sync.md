# The well sync — carry the memory across the fleet

## What it is

The **well sync** checkpoints Ymir's memory (the engram, its episodes, and the Runes
ledger) and carries it across your machines through the **private home repo**. One
memory, one vault — same law as the git‑sync job: **never force, never discard, never
merge**.

## What you need

- Ymir on each seat, and the home repo clone/remote configured.

## Do it

```bash
bin/time/well-vault-sync.sh --mode push   # checkpoint + commit + push the well
bin/time/well-vault-sync.sh --mode pull   # fast-forward the well from origin
bin/time/well-vault-sync.sh --dry-run     # show what would move
```

It runs on a schedule (`@heart 06:35 … --mode push` in `config/cron.yaml`) so the heart
keeps the memory checkpointed.

## Notes and limits

- **Stages only the named well files** — never `git add -A`; unapproved work must not ride.
- **Fast‑forward only.** It never forces, stashes, or merges; a diverged home is reported,
  not resolved for you.
- **The engram is checkpointed** (`wal_checkpoint(TRUNCATE)`) so one binary carries the
  memory.
- **It ships in the repo** (`bin/time/well-vault-sync.sh`) — a cron job pointing at a
  script that did not ship is exactly what `cron-guard` refuses.

## If it does not work

| What you see | What to do |
|---|---|
| `nothing new in the well` | Nothing changed since the last push. |
| `push failed (non-fast-forward?)` | Pull first (`--mode pull`), or push by hand; it will not force. |
| `pull failed (dirty tree or divergence)` | Resolve the home by hand, then re‑run. |
| No well in the vault | Create the home/engram first; the well lives in the hoard (Rule 04). |
