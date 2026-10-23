## docs · unversioned · 2026-10-23 — the library of records: one contract, one door (plan 115)

### Why

The Allfather asked twice why the house's knowledge is *"random md files scattered all over"*. The
audit (`hodd/docs/audits/2026-10-23-the-scattered-record-audit.md`) measured it. This is the first
built slice of plan 115, and it is deliberately small enough to be true:

- **one contract, and it is not new.** `.pi/extensions/ymirhome.ts` already enforced
  `kind · status · verified · verified_by · supersedes · superseded_by · grade · aliases · canonical ·
  origin · used_by · sensitivity · owner`. The plan had proposed a **rival** header — the same fault
  one level up. The extension now carries two more fields (`tags`, `sources`) and both the checker and
  `apply` write them. **One command answers "is this document typed".**
- **one door.** `bin/records/library.sh` — `check` (coverage per shelf, and `--changed` for the gate on
  the diff), `ask` (one query across doors, capabilities, features, law, skills, research), `index`,
  and `research keep|list|show|find|index|check`. The research engine that was built earlier the same
  day (and never pushed) is folded **in** rather than shipped as a second door.
- **the research kind.** One episode = one question, the finding in our words, the sources and the
  `route`, filed by date in `hodd/library/research/<YYYY>/<MM>/`, index derived from the folders. A
  finding with no source is refused; a **negative result** may stand without one, because a dead end
  paid for once must not be paid twice; an episode is never rewritten. That is `RULES/35`.
- **the law.** `RULES/34-the-record-has-a-shape.md` — the header, `verified` as a command, a view is
  rendered not appended, a derived view must be reproducible and gated, the gate is on the diff, and a
  correction is a new record citing the old one. Both rules indexed.

### The measurement that changed the plan's own number

The audit said the home was **68%** typed. Against the *contract* (a `---` block carrying `kind` and
`status`), the first real run of `library.sh check` measured:

```
2119 documents on the sampled shelves · 13 typed · 0%  (hodd/identity 311 → 0 · svartalfaheim 554 → 1)
```

The audit counted any front-matter or TOON block; the contract is stricter. **The stricter number is
the true one**, and it makes the case for the diff-gate stronger, not weaker.

### Files
- `bin/records/library.sh` (door) · `src/ymir_runtime/library.py` (the engine, 10-assertion self-test)
- `RULES/34-the-record-has-a-shape.md` · `RULES/35-the-research-is-kept.md` · `RULES/README.md`
- `.pi/extensions/ymirhome.ts` — `tags` + `sources` in the header contract and in `apply`
- `docs/features/the-library-of-records.md` · `FEATURES.md` (one row)
- `docs/fixes/docs/unversioned-2026-10-23-the-library-of-records.md`

### Verified
```
bin/records/library.sh self-test    10/10 PASS (refuses an unsourced finding, keeps a negative result,
                                    never rewrites an episode, fails on an emptied source list)
bin/records/library.sh check        coverage printed per shelf, both trees
bin/records/library.sh ask "vault"  rows from the registers, with the file that carries each
bin/gates/guards.sh                 14/14 PASS
```
**Not built here, and why:** rendering `FEATURES.md` / `RULES/README.md` from records (plan 115 P3) is
blocked on two things that must come first — the one-time extraction of the catalogue's rows into
records (a render would otherwise delete history the append-only law protects), and a generator proven
reproducible. This change makes the second possible; the first is its own commit.
