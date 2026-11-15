# The kit says how a company runs its own suite (1.6.0 → 1.7.0)

**2026-11-15 · component: collab**

## What was wrong

The kit knew how to make a repository reviewable by a stranger, and how a hand that is not on our network asks
the house one question through a card, a token and a grant. It had nothing to say to a **company** that wants
the collaboration suite itself: its own hall, board, documents, whiteboard, files and code, on its own hardware,
under its own name.

That is not a collaborator and not a tenant. A collaborator asks; a tenant shares a gate. A company runs its own
installation and owns every part of it — its gate secrets, its members, its domain, its cookies, its theme, its
tokens and its mail identity. With no page saying so, the first company that asked would have been given a
second tenant on our host, or a copy with our keys in it, and neither is the thing it asked for.

The operator's word (2026-11-15): *"we need to update the collaboration kit in Ymir to maybe support things like
this"* — a company raising its own copy, renamed and themed as its own.

## What was forged

Kit **1.7.0** — documentation only, and no gate changed:

- `docs/a-company-suite.md` — what a second installation is, why every part of it is separate, the nine-step
  checklist a company follows (its own host, fresh gate secrets generated there, its members only, its own
  domain and cookie domain, every route behind its gate, its theme and names, one MCP token per member scoped
  to that company's places, mail only after its SPF and DMARC, secrets out of the tree), and the proof line:
  **the two installations share no secret and no user**, with the two refusals that show it.
- The kit README gains the row for it, and its count of pieces (21 → 23) now matches the table it describes;
  the table had carried 22 rows against a prose count of 21 before this change.
- `standardise.sh` moves to `1.7.0` with the note in its history comment, so the manifest a company reads says
  which kit version carried the page.

No rule, no gate and no hook is touched. A documentation change is not a referee change; the version moves
because the kit's carried set changed, which is what `.collab-kit.json` records.

## What was run

```
python3 -c "yaml.safe_load(header of docs/a-company-suite.md)"   → title, status, owner, updated (loads)
bash bin/collab/standardise.sh --check /tmp/kitcheck            → kit 1.7.0 · missing 73
                                                                  incl. docs/a-company-suite.md (carried, not orphaned)
bash bin/gates/fixes.sh validate                                 → valid, 1193 notes
```

The page was read against the kit's own document rule: headings that say what each section answers, short
paragraphs, tables where an item carries three or more facts, one Mermaid diagram for the two installations, a
callout for what is owed, and no machine-shaped blocks.

## What is not done

- **Nothing is gated.** No ward inspects a second installation and refuses a shared secret or a shared user.
  Until one exists, the proof line is a discipline held by review, and the page says so in its own words rather
  than implying a check that is not there.
- **The company's own steps are its own.** The kit carries the discipline and the page; the installation
  procedure, its domain and its people belong in that company's repository, not in ours.

## References

- `bin/collab/kit/docs/a-company-suite.md`, `bin/collab/kit/README.md`, `bin/collab/standardise.sh`
- `bin/collab/kit/docs/collaborator-door.md` — the door a hand outside our network is given
- `RULES/04-hoard.md` — a credential is referenced through the vault, never carried in the tree; a company's
  data, addresses and people stay in that company's own repository
