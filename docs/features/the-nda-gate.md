# The NDA gate — company names never reach the public repo

Ymir's repository is public. The name of a company or a client you work for, or of their project, is private
data. This gate refuses any of those names in a commit, a push or a file write, before it can reach GitHub.

## What it is

One matcher reads your list of protected names from your Ymir home and is used in four places: a Claude Code write
hook, the `pre-commit` hook (staged changes), the `commit-msg` hook (the message) and the `pre-push` hook (what the
push adds). The same check runs in the tree ward in CI.

## Where the names come from

Never from the repository. At run time the gate reads your home:

- every company in `hodd/identity/companies.yaml` and every client in `clients.yaml`;
- every project in `projects.yaml` that is not Ymir's own and not public;
- every realm folder under `svartalfaheim/`;
- the `nda:` list in `hodd/identity/confidential.yaml`, where you add names by hand.

## What you need

A Ymir home. Add a name by hand like this (shape only):

```yaml
nda:
  - SomeCompanyName
```

## The commands

```bash
bin/gates/guards/nda-guard.sh              # scan the tracked tree
bin/gates/guards/nda-guard.sh staged       # scan what is staged
bin/gates/guards/fixes-guard.sh --install  # seat the hooks in a plain checkout
bash bin/seat/harness-extensions-install.sh  # seat the Claude Code write hook
```

A refusal prints the file, the line and the matched name, and nothing else of the line.

## Limits

- Matching is whole-word and case-insensitive. A longer word that contains a name is not a hit.
- A word that is also ordinary English goes in `config/nda-allow.yaml` with its reason. An entry without a reason is ignored.
- The gate cannot unmake history. A name already pushed stays in old commits.

## If it does not work

- `nda-guard: UNARMED` means no home resolved, so nothing was judged. Set `YMIR_HOME`. On a seat that has a home, that is a fault.
- A refused word that is ordinary English: add it to `config/nda-allow.yaml` with a reason.
- A refused write in Claude Code: write the file under your home instead, or use a neutral word.

## CHANGE LOG

- 2026-11-12 — written with the gate (plan 268, phase 1).
