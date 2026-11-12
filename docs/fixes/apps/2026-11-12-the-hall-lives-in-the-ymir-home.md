# The hall lives in the Ymir home, never in or beside the public tree

**2026-11-12 · component: apps · `apps/bilskirnir/scripts/data-home.sh` · follows PR #707 · RULES/04**

## What was wrong

The hall's database, its engines (keys in `config.yaml`) and its `.env` are private data. PR #704 moved them out of
the public checkout to `~/.local/share/ymir/bilskirnir`, which is outside the repository but still outside the Ymir
home. RULES/04 says private data lives under `$YMIR_HOME`.

## What was done

- The default data home is now `$YMIR_HOME/bilskirnir`, resolved through `bin/vault/hoard-lib.sh`, the way Smíðja's
  databases live in `$YMIR_HOME/smidja/`.
- The home's `.gitignore` carries `bilskirnir/`, because a live database and keys never ride the home's git.
- The XDG folder remains only as the fallback on a machine with no Ymir home.

## Proof

`apps/bilskirnir/tests/data-home.sh` — 16 of 16, fenced to its temp folder.

## CHANGE LOG

- **2026-11-12** — the hall's default home moves to `$YMIR_HOME/bilskirnir`; the longer account is the section
  appended at 16:02 to `2026-11-12-the-hall-finds-every-root-and-waits-for-a-busy-one.md`.
