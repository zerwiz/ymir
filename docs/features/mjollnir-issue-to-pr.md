# Mjollnir — an issue becomes a pull request

## What it is

**Mjollnir** is Ymir's hammer: you point it at a GitHub **issue**, and it cuts an
isolated worktree, spawns a sealed **Eindri** to do the work, runs the tests, opens a
**pull request**, and hands it to **Glitnir** for human review. **It never
force‑merges** — the seal is always the Allfather's.

## What you need

- The project registered in the master registry (`$YMIR_HOME/hodd/identity/projects.yaml`,
  a `git{}` block) — Mjollnir reads host/owner/repo/branch/auth from there.
- GitHub auth resolved from `$YMIR_HOME/hodd/secrets/platform.env` (`GITHUB_TOKEN`, or
  the App credentials) — never a token in the tree.
- A container engine for Utgard isolation (optional; `--isolation auto` decides).

## Do it

```bash
# one issue -> one PR
bin/forge/mjollnir.sh run --repo ~/ymir --issue 123

# see what is in flight
bin/forge/mjollnir.sh status
```

Useful choices:

```bash
--mode direct-PR | no-mistakes | local-only   # how the change is validated
--harness <h>                                  # which agent harness does the work
--isolation auto | on | off                    # Utgard sandbox on/off
--no-spawn                                     # prepare the worktree, do not spawn
```

A run ends with a **PR**, not a merge: Glitnir's Reviews surface it, and the Allfather's
approval *is* the merge.

## Reading your own repos first

Two doors in front of the hammer, both harmless to run (they never write to GitHub and never touch a tree).

**What can Ymir even see?** The registry (`$YMIR_HOME/hodd/identity/projects.yaml`) names every project you
have. `doctor` says which of those rows can actually name a remote, which have a clone, and which are
unreachable — one line per project, and a `findings[]` row for each fault:

```bash
bin/agents/project-git.sh doctor            # offline, instant
bin/agents/project-git.sh doctor --probe    # ask GitHub about each remote
bin/agents/project-git.sh doctor --strict   # exit 1 when a row cannot name or reach a remote
```

**What is open across all of them?** `intake` reads every registered repo — open issues with their age and
labels, open pull requests with their checks, the health of each default branch, and the security alerts —
and caches the result under your home:

```bash
bin/forge/mjollnir.sh intake                      # every readable repo, cached 5 minutes
bin/forge/mjollnir.sh intake --repo hlidskjalf    # one project
bin/forge/mjollnir.sh intake --ttl 0              # ignore the cache
bin/forge/mjollnir.sh intake --json               # for a board or a script
```

A source it could not read is **named with its reason** (`denied — the token has no scope for dependabot
alerts`), never counted as zero. A `100+` means "at least a hundred, the read is capped". A `needs[]` row
tells you the one command that fixes a credential gap.

**Fixing a repo that is not cloned:** `intake` needs no working tree, `run` does. Clone it first — it lands
under your home, never in the Ymir tree:

```bash
bin/forge/mjollnir.sh clone example-10          # lands in $YMIR_HOME/halls/<owner>/<repo>
bin/forge/mjollnir.sh clone example-10 --dir ~/CodeP/example-10
bin/agents/project-git.sh example-10 --field path   # where the tree is (or refuses)
```

It refuses to clone over an existing tree, refuses a destination inside the Ymir repo, and refuses a
project whose registry row cannot name a remote — that row needs a `git{}` block, which `doctor` names.

## Notes and limits

- **Human in the loop, always.** Mjollnir opens PRs; it does not seal them. A local
  merge is a decision, not a delivery (Rule 08).
- **Isolation.** A declared `utgard` with no image is a **loud refusal**, never a
  silent downgrade to an unsafe mode.
- **Config lives in the home**, never the tree: projects in the registry, credentials in
  the secrets vault.
- **One issue, one worktree.** Parallel issues get independent Yggdrasil worktrees and
  never collide.

## If it does not work

| What you see | What to do |
|---|---|
| Unknown repo / no project | Register it in `$YMIR_HOME/hodd/identity/projects.yaml` with its `git{}` block. |
| Auth failure | Ensure the `$YMIR_HOME/hodd/secrets/platform.env` credentials are present and valid (`bin/vault/hodd.sh emit secrets/platform.env`). |
| Refused: no Utgard image | `bin/forge/utgard.sh build`, or run with `--isolation off` (deliberately). |
| A PR opened but CI red | This is Glitnir's read — the change is not ready; fix on the branch, do not merge. |

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
