# The library of records — one corpus, one contract, one door

**What it is.** Before this, the house had *registers* — a list of every door in `bin/`, a feature
catalogue, a rule index, a skill index — and no *corpus*: a document was a loose `.md` in whatever
folder a hand chose, with nothing on its face saying what it was, who kept it true, or whether it was
still true. And what an agent *looked up* online was kept nowhere at all.

The library is the mend. One door answers both questions — *"where is the document for X?"* and
*"what did we already learn about Y?"* — over documents that declare their own shape.

**What you need.** Nothing installed. The door is `bin/records/library.sh`; the shelf for research is
`$YMIR_HOME/hodd/library/research/`. The law is `RULES/34` (a record has a shape) and `RULES/35` (what
was learned outside is kept).

**The commands.**

```bash
bin/records/library.sh check            # coverage per shelf, measured — never a guess
bin/records/library.sh check --changed  # the gate: a NEW or changed doc must carry a header
bin/records/library.sh ask "vault guard" # one query across doors, capabilities, features, law, skills, research
bin/records/library.sh index            # the library's own view, in the home

bin/records/library.sh research keep \
  --question "what did we look up" \
  --finding  "the answer, in our own words" \
  --source   "https://example.org/page|Its title" \
  --owner brokk --tag gate,docs --route "direct fetch"
bin/records/library.sh research list | find <words> | show <slug> | check | index
bin/records/library.sh self-test         # 10 assertions, in a temp root — never the real library
```

A subsystem register is one command too: `bin/gates/doors.sh --root tools/snotra` writes
`tools/snotra/DOORS.md` — every entry point, what it is, whether it is executable — and `--check`
fails when it is stale.

**The header** (on any document meant to be found again):

```
---
kind: feature | rule | fix | audit | research | reference | decision | document
status: live | draft | superseded | archived
verified: 2026-10-23        # a DATE only when someone proved it; otherwise leave it empty
verified_by: bin/gates/guards.sh   # the command a reader can re-run
owner: brokk
tags: library, records
sources:                    # required on research and audits
---
```

`ymir_header apply` writes a full header where none exists; `ymir_header check` lists the documents
that have none.

**Limits — what this does not do.**

- It does not **delete** anything. A record that cannot be typed is moved to `hodd/reference/` with
  its reason (Rule 11).
- It does not **migrate history** in one pass. The gate is on the *diff*: new and changed documents
  must be typed; the shelves written before the law are reported shelf by shelf and paid down.
- It does not **embed or search semantically**. `ask` is words over the registers and the typed
  corpus. The well (`bin/records/mimir.sh`) remains the place for a semantic recall.
- It does not answer from a **superseded** record silently — an answer carries the record's status
  and date.
- The library's research shelf refuses **vault or NDA material** (Rule 15 wins).

**If it does not work.**

| symptom | cause | do this |
|---|---|---|
| `ask` finds nothing | the words are not in a register, a rule title, a feature row or a research note | try a shorter phrase; check the doc is in `docs/features/`, `RULES/`, or the research shelf |
| `check --changed` fails on a file you did not touch | another hand left it untyped in the working tree | type it with `ymir_header apply`, or `git stash` it — the report names the file |
| `research check` says *index stale* | the index is derived | `bin/records/library.sh research index` |
| `research keep` refuses your finding | no `--source` | add the page, or record it as a **negative result** with `--negative` |
| `doors.sh --check` says STALE | the tree changed since the register was rendered | `bin/gates/doors.sh --root <dir>` and commit it with the change |
