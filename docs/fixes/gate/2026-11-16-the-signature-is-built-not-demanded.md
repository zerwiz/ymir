# gate · 2026-11-16 — the signature is built from the pull request's own commits and author

## What the ward demanded

`bin/gates/guards/pr-identity-guard.sh` refused a pull request whose body carried no five-line
signature block, and refused again when the body's `agent:` disagreed with the branch's errand id.
Every field of that block was a fact the ward already held: the origin's owner, the repository's
name, the branch, the author, and the commits the branch carried onto its base.

So a hand retyped facts the gate could read. Measured 2026-11-15 and 2026-11-16: two of the five
refusals that stalled the queue were this ceremony, and neither was about the code in the branch.

## What it does now

The ward derives the block and prints it:

```
house: <the origin's owner>
fleet: <the repository>
agent: <the branch's errand> (role: ship, errand: <the errand>)
authority: <the author> — the pull request records <n> commit(s) onto <base>
proves: head <sha7>: <n> commit(s) from <author>; the gate is bin/gates/ci-verify.sh
```

It prints the built block to stderr so the hand may paste it into the body and make the record
permanent. It never refuses its absence.

A body that names a different agent is a **note**, not a refusal: the branch and its commits are the
record, and the body is a description of them. The built `agent:` line carries the branch's errand
and says what the body claimed.

## What still refuses

Everything the body can PUBLISH, because a pull request is public the moment it is opened:

- a live private address, an IPv6 address, a tailnet host (RULES/04);
- a concrete home path — `/home/<an account>/`, `/Users/<an account>/`;
- a personal mailbox, a pane id, a credential shape;
- a model, model-maker or agent-harness name in the title or the body (RULES/53).

## Why a home path is now judged by the value

The `homepath` class read `~` as a leak. RULES/04 says the opposite in its own words: *"shape, never
by value — a literal `/home/<name>/`"*. A tilde names nobody.

So `bin/forge/pr-patterns.sh` now refuses a **value** (a concrete account name after `/home/` or
`/Users/`) and allows a **shape** (`~`, `~/…`, `/home/<name>/`, `$HOME/…`, `/home/example/…`). That
one distinction is what refused PR #770 and PR #771 for the sentence that described the fix.

## The proof

`bin/gates/tests/test_pr_identity.sh` — 31 cases, and CI now runs it
(`bin/gates/checks.d/0492-pr-identity.sh`; before this change no gate file named the test at all):

- a body with no signature block is judged, and the block it built is printed;
- the errand comes from the branch, the authority from the author, `proves` from the head;
- a disagreeing `agent:` is a note, and the branch wins;
- a complete block passes untouched and is not rebuilt;
- a body carrying an address, a concrete home path or a pane id is still refused, and a maker's
  name in the title is still refused;
- a tilde in prose passes, and the six leak classes still refuse through the door (`pr-open.sh`).

Run it: `bash bin/gates/tests/test_pr_identity.sh`.
