# Security policy

## Secrets

Never commit a secret. Credentials live in the gitignored `.env.local`
(platform) or `svartalfaheim/<realm>/.env.realm` (realm); committed examples
end in `.example` and carry empty values.

`bin/gates/guards/secret-guard.sh` scans the staged change (installed as the `pre-commit`
hook) and every tracked file (`--all`, run in CI) for private env files and
obvious keys (`AKIA…`, `ghp_…`, `sk-…`, `xox…`, `AIza…`, private keys). A hit
blocks the commit.

**If a secret reaches a commit:** rotate it immediately — rewriting history does
not un-leak it — then purge it with `bin/gates/repo-scrub.sh --yes`.

## Private data

The operator's world-tree is private by design: `workspace/{work,personal,
memory,companies}/` and `assets/reference/state/` are gitignored. A clone must
never inherit another operator's data. Keep it that way.

## Reporting a vulnerability

Do not open a public issue. Report privately to the maintainers (GitHub
Security Advisory on the repository), including steps to reproduce and the
affected version. We will acknowledge and coordinate a fix before disclosure.

## Contact and disclosure process (appended 2026-11-14)

This section names the contact and the process, because the two paragraphs above
said where to report and not who answers, or how soon.

### The contact

**One public door: GitHub's private vulnerability reporting** — on the repository,
**Security → Report a vulnerability**. It is a private channel to the maintainers, it
opens a discussion nobody outside can read, and it needs no address of anyone's. The
repository carries no personal email address on purpose: a public repository is not where
the operator's identity lives (RULES/04).

The maintainers are the accounts named in [`.github/CODEOWNERS`](.github/CODEOWNERS).
A report about the security policy itself goes to the same door.

### What to send

- what you can do with the flaw, and what an attacker gains;
- the version or commit you tested (`git rev-parse HEAD`, or the release name);
- the smallest reproduction you have — a command, a request, a file;
- whether you have told anyone else, and whether you intend to publish.

### What happens next

| When | What |
|---|---|
| within **7 days** | a maintainer acknowledges the report and asks for anything missing |
| within **30 days** | a first assessment: accepted, needs more information, or out of scope, with the reason |
| within **90 days** | a fix released, or a written explanation of why it takes longer |
| before any disclosure | the report and the fix are coordinated with you; credit is given unless you ask for none |

If a release cannot be made inside 90 days, the maintainers say so in the report before
the window closes rather than after.

### Scope

**In scope:** the runtime and its install, the apps, the gates and the MCP doors shipped
in this repository, and any default that would expose an operator's machine or data.

**Out of scope:** a secret you put in your own home or your own `.env.local` (that is a
rotation, not a vulnerability — see below), third-party services the runtime connects to,
model weights fetched from their own publishers, and anything that requires an attacker
to already hold the operator's account.

### If you find a committed secret

Tell the maintainers through the same door, do not open a public issue, and **do not paste
the secret** — name the file and the line. A secret that reached a commit lives in the
history and in every clone, so the fix is rotation first and history second. The two
scans that judge a change are `bin/gates/secret-scan.sh tree` (gitleaks, the whole history)
and `bin/gates/guards/secret-guard.sh --all` (the house's ward); both run in CI, and a
finding fails the build.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-14** — the contact and the disclosure process appended: the private reporting
door, what to send, the 7 / 30 / 90-day expectations, the scope, and what to do about a
committed secret. Plan 287 §8 asked for a contact and a process; the earlier text named
the door and left the rest unsaid.
