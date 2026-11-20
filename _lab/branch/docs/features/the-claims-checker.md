# The claims checker — does the document still name an open road?

**What it is.** `bin/gates/checks/readme-claims.sh` reads a user-facing document and checks its
factual claims against the tree: every repo path in backticks must exist, and `@zerwiz/*` packages
can be checked against the registry. It is run by the `docs-claims-guard`, so a stale instruction
cannot be pushed.

**What you need.** Nothing: it reads files.

**The commands**

```sh
bin/gates/checks/readme-claims.sh                 # README.md
bin/gates/checks/readme-claims.sh --npm           # …and verify @zerwiz/* against the registry
bin/gates/checks/readme-claims.sh --ports         # …and report what actually listens on a named port
bin/gates/checks/readme-claims.sh docs/lore.md FEATURES.md docs/features/*.md
bin/gates/guards/docs-claims-guard.sh check       # the ward, as guards.sh runs it
```

**How a line is waived.** Two ways, both written down:

- inline, on the line: `` `config/backend` <!-- stale-ok: the seat writes this at runtime --> ``
- in `docs/README-claims.waived`, one token per line, for something deliberately absent from a
  clone (the live cron file belongs to the hoard, so a clone ships only `.example`).

**What it found on its first run.** Five closed roads in the README — including a paragraph saying
the smithy's `@zerwiz/smiddja` name "was accepted twice and served never" while the registry
answered `0.1.1` — plus nine more across the feature pages, one of which described an opener that
had been deleted from the tree.

**Limits, said plainly.** It checks that a road is **open**, never whether the sentence is *true in
spirit*. A green ward is not a finished document (Rule 27).

**If it does not work.** Run it directly on one file; the row names the line and the token. A
`MISSING PATH` on something you believe exists is usually a moved file: fix the page, or waive it
with the reason.
