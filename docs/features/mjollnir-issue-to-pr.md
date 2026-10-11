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
