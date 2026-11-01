# 2026-11-01 — personal data belongs in the home, not in this repository

**Component:** collab (Vingólf) · **Rule:** 04 and the first law · **Plan:** 154

## What happened

While drafting the collaboration letter and its fix notes, this repository — which is **public** — was given
material it may not hold: two counterparts' names, one of their email addresses, and a mail draft id. Nothing was
sent, and no credential was written. The Allfather asked the direct question (*"are the letter things now in ymir
public repo?"*) and the answer was: the **template** was, with placeholders only; the **rendered letter** and the
**register** were not, because both live in the private home. The leak was in the notes *about* the letter.

## What was done

1. **The notes were rewritten** to describe the mechanism and never the person: "a counterpart", "the register",
   "the rendered letter lives in the private home". No name, no address, no draft id.
2. **The branch was squashed to one commit and force-pushed**, so the names are not in its history either — a
   clean tree on top of a dirty history is not a clean branch.
3. **A pre-existing note was moved out of the repository** (`docs/fixes/gimle/`) because it carried three
   third-party addresses and the account roster. It moved **intact** to the private home
   (`hodd/reference/imported/`), and a pointer replaced it here, so the component's history is cited rather than
   erased (Rule 11).

## The line this draws

- **A document that describes people belongs in the home.** Names, addresses, rosters, invitations, credentials.
- **A document that describes how the machine works belongs here.** Doors, gates, checks, the mechanism.
- A rendered letter is a document about a person: it is written to `$YMIR_HOME/hodd/state/collab/letters/` and
  never to the repository. The template stays here, with `{{placeholders}}` and no examples that look like people.

## Owed

The sweep is not finished: several older notes under `docs/fixes/` name counterparts or quote their addresses, and
each is another hand's record. They are listed in the home's audit and swept the same way — the record moves, the
pointer stays, nothing is lost. This note is the rule they will be swept by.
