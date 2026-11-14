# Secret scanning — gitleaks, and the operator's own words

## What it is

A scan that answers two questions before a change leaves a machine:

1. **Does a credential ship?** A key, a token, a private-key header, a connection
   string — the shapes every project shares.
2. **Does a word of the operator's ship?** A person, a client, a company, a mail
   domain, a host name, a user name — the things that must never appear in a
   public repository (RULES/04).

The first question is answered by gitleaks' own rules plus the repository's
`.gitleaks.toml`. The second is answered by rules that are **generated at run
time** from the operator's private deny list, into a config that lives in the
home and never in the tree. That split is the whole design: a stranger who
installs Ymir gets the shared half and brings their own words; CI, which has no
home, scans the shared half, and proves that no credential shape ships.

## What you need

- The `gitleaks` binary — one file, from
  [github.com/gitleaks/gitleaks/releases](https://github.com/gitleaks/gitleaks/releases).
  Put it on your `PATH`, or name it with `YMIR_GITLEAKS=/path/to/gitleaks`.
- The deny list, if you keep one: `$YMIR_HOME/hodd/identity/public-deny.txt`.
  A template ships as `hodd/identity/public-deny.txt.example` and the install
  copies it into your home; it starts with invented entries only.

Nothing else. The shared rules are in the repository, and the operator's words
are in your home.

## Do it

```bash
# 1. What a scan would use — counts and paths, never a word
bin/gates/secret-scan.sh status

# 2. Turn the home's deny list into gitleaks rules (writes into the home)
bin/gates/secret-scan.sh config

# 3. Scan the working tree, and then the whole history
bin/gates/secret-scan.sh dir
bin/gates/secret-scan.sh tree

# 4. Scan only what is staged (a pre-commit habit)
bin/gates/secret-scan.sh staged

# 5. Without a home of your own: the shared rules alone
bin/gates/secret-scan.sh dir --config .gitleaks.toml
```

`status` answers like this:

```text
secret_scan[7]{fact,value}:
  "gitleaks","8.30.1"
  "shared rules","/path/to/ymir/.gitleaks.toml"
  "deny list","/path/to/home/hodd/identity/public-deny.txt"
  "deny sources","2"
  "operator words","20"
  "generated config","/path/to/home/state/gitleaks/gitleaks.toml"
  "history","every commit on every branch (gitleaks git --all)"
```

A finding names the rule, the file and the line, and the match is redacted:

```text
Finding:     const API_KEY = 'REDACTED'
RuleID:      operator-name-3
File:        apps/example/src/config.ts
Line:        42
```

## The deny list

One entry per line, `<kind>:<word>`; a blank line or a line starting with `#` is
ignored. The **kind** decides where the word is judged, because the lore and the
fleet share names: a subsystem named for a figure is the house's craft, and a box
named for him is the operator's life — only the second is a finding.

| Kind | Judged |
|---|---|
| `name:` | anywhere, as a whole word — a person, a client, a company |
| `domain:` | anywhere, on a domain boundary — a mail or client domain |
| `host:` | only where it is *used* as a host: after `@`, `//`, `/home/`, `host=`, `host:` or `ssh`, or before a port, `.local` or a tailnet suffix |
| `user:` | another spelling of `host:` |

A bare word is read as `name:`. Entries shorter than three characters are
ignored, because a two-letter rule matches half the tree. When the same word
appears twice, the stronger kind wins.

## The allowlist, and why it is short

`.gitleaks.toml` exempts a handful of places where a secret *shape* is on purpose:

- test fixtures that seed a fake token so a ward can prove it refuses one — the
  **line**, not the file, is exempt, so the rest of the test is still scanned;
- the wards that hunt secrets, which must name the shapes they hunt;
- third-party lockfiles and built bundles, which repeat upstream text verbatim.

Everything else is scanned — every commit, on every branch. A secret that was
committed and then deleted in a later commit is still in the clone, and `tree`
finds it.

## In CI

`.github/workflows/ymir-secret-scan.yml` runs two jobs on every pull request and
on `main`:

- the house's ward, `bin/gates/guards/secret-guard.sh --all`, over every tracked file;
- this door, `bin/gates/secret-scan.sh tree`, over the tree and the whole history.

The checkout fetches the **whole history** (`fetch-depth: 0`). Without it,
gitleaks can only see the last commit, and the scan proves nothing about
yesterday. The binary is pinned by version and verified against the release's
published SHA-256 before it runs.

CI scans the **shared** rules only. The operator's words are not in the
repository, so CI cannot judge them — and that is correct: CI proves no
credential shape ships to anyone, and your machine proves no word of yours
ships to anyone.

## Notes and limits

- **A removed secret still lives in history.** Rotate first — the key is exposed
  the moment it was pushed — then clean history if you must. The scan tells you
  where it is; it cannot un-leak it.
- **The generated config is machine-specific** and rides an absolute path to the
  tree's `.gitleaks.toml`. Regenerate it (`config`) after moving or re-cloning
  the tree.
- **Two lists, one scan.** The door reads both `hodd/identity/public-deny.txt`
  (the audit's list, plan 287) and the older
  `hodd/security/operator-words.txt`, and uses the union, so neither owner has to
  move a file.
- **A word scan is a net, not a proof.** It catches the word; it cannot know
  whether a sentence about a person is private. The ward is the floor, and
  judgement is still the writer's.

## If it does not work

- `gitleaks is not on PATH — nothing was scanned` — install the binary or set
  `YMIR_GITLEAKS`. The door exits 3 and does not pretend to have passed.
- `no deny list on this machine — nothing to generate` — there is no
  `public-deny.txt` in the home. Copy the template into the home, or run with the
  shared rules alone; both are clean outcomes and the door says which it used.
- A finding you believe is wrong — add the exact **line** to the allowlist in
  `.gitleaks.toml` with a reason beside it, never the whole file, and never a
  word from the deny list.

## CHANGE LOG

- **2026-11-14** — written, with the door `bin/gates/secret-scan.sh`, the shared
  config `.gitleaks.toml`, the deny-list template, and the CI job (plan 287 §8,
  plan 288 step 3).
