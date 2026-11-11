# The collaboration kit — the same discipline in every repository

**What it is.** Twenty-one small pieces that make a repository reviewable by a stranger: a baton, fix notes, a review shelf, five gates, three
hooks, and the two tools that keep them honest. They are the ones this house actually uses — not a template somebody imagined.

**Why a kit instead of a paragraph in each repo.** Two products already carry slightly different versions of the same rules, because each
was written in the moment. A kit is how they stay the same, and how the next repository starts at the standard rather than at the
beginning.

| Piece | Path | What it does |
|---|---|---|
| the baton | `handoff/{TEMPLATE.md,check.sh,check.py}` + `handoff/CURRENT.md` | where the work is, what is blocked, and who is blocked for — rewritten at every hand |
| the fix notes | `scripts/fixes.sh` · `scripts/fixes-components.sh` · `docs/fixes/` | one file per fix, never a changelog; a note says what was wrong, why, and what was run |
| the review shelf | `scripts/reviews.sh` · `docs/audit/` | a review is a file named for its pull request, listed, and named by the baton |
| the secret scan | `scripts/gates/secret-scan.sh` | a credential is refused at the commit |
| the private-data scan | `scripts/gates/private-data.sh` | a machine path or a real address is refused at the commit |
| the fix-note gate | `scripts/gates/fixes-guard.sh` | a behaviour change with no note is refused at the push |
| the review gate | `scripts/gates/reviews-shelf.sh` | a review that is misnamed, unlisted or unnamed by the baton is refused |
| the pull-request gate | `scripts/gates/pr-guard.sh` | a branch that exists on the remote with no pull request is refused at the push |
| the hooks | `.githooks/{pre-commit,commit-msg,pre-push}` | the three moments a mistake is cheapest to stop |
| the checks door | `scripts/checks.sh` | asks the repository which check it owns — node, elixir, its own `scripts/doctor.sh`, or none, which is a printed skip and never a silent pass |
| the worktree tool | `scripts/worktree.sh` | one agent, one `.yggdrasil/<id>/` checkout — two hands never share a directory |
| the referee guard | `scripts/gates/referee-guard.sh` | a change to a gate, a hook or a ward with no fix note and no word in the message is refused at the push |
| the module-test guard | `scripts/gates/new-module-test.sh` | a new module with no test naming it — and no line in `.module-test.allow` — is refused at the push |
| the workbench skill | `.agents/skills/smidr-the-workbench/` | the craft taught to a guest hand: the slice, the note, the five things never changed quietly, and what each refusal means |
| the collaborator door | `docs/collaborator-door.md` · `scripts/collab-connect.sh` | how a hand that is not on our network connects: a public card, a short-lived JWT scoped to one skill, a grant, a Rune per call — and the five refusals a door must still make |
| the advantage gate | `scripts/advantage-audit.sh` · `docs/advantage.md` | a claim about why we win carries its evidence or it is refused: the VRIO screen, the teardown taken from lost deals, and the check that fails a page of adjectives |
| the status script | `scripts/status.py` | reads every plan, ticket and document header and prints their status; `--check` fails on a malformed header; it takes the plan prefix from `plans/.prefix` or the plan file names, never assumes one |
| the header format | `docs/headers.md` | the header every document, plan and ticket opens with, the statuses, and the rule that each ends with a References section |
| plan, validate, execute | `RULES/19-plan-validate-execute.md` | no implementation before the area owner named in `AGENTS.md` has validated the plan; documentation and planning are allowed at any time |
| the tickets shelf | `plans/tickets/{README.md,TEMPLATE.md}` | a ticket is one unit of work under a validated plan, never a plan itself; several tickets may share one plan |
| the document rule | `RULES/20-documents-are-for-people.md` | every document a person reads uses headings, short paragraphs, Markdown tables, Mermaid diagrams and callouts — never machine-shaped blocks |
| the template shelf | `docs/templates/` (`INDEX.md` first) | a template for every kind of document — plan, architecture, decision, research, rule, README, quickstart, tutorial, how-to, concept, reference, installation, runbook, troubleshooting, release notes, glossary — each with its licence |

Plus the rules that govern them (`RULES/15`, `16`, `17`, `18`, `19`, `20`) and `docs/gates.md`, which explains what each refuses **and what it deliberately
does not**.

## Install it

```bash
bin/collab/standardise.sh --check  /path/to/repo     # what is missing or different; changes nothing
bin/collab/standardise.sh --apply  /path/to/repo     # copy what is missing, seat the hooks, write the manifest
```

**It never overwrites a rule that is already there**, and it says which files it left alone and why. A kit that silently replaces a
repository's own law is not a standardisation, it is a raid.

## What it does not do

- **It does not decide for a repository.** A rule that does not fit is not installed; the manifest says which version is present.
- **It does not touch the code.** No pipeline, no build, no dependency.
- **It does not enforce anything on GitHub.** Branch protection is unavailable on this plan (`403: Upgrade to GitHub Pro`), so the
  enforcement is the hooks — which means a clone without `core.hooksPath` set is unprotected, and the installer sets it.
