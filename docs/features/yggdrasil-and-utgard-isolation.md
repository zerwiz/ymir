# Yggdrasil and Utgard — isolation

## What it is

Two kinds of isolation, for two kinds of risk:

- **Yggdrasil** — the worktree manager (the world‑tree). Every task gets its **own
  checkout on its own branch** under `.yggdrasil/<id>/`, so parallel work never
  collides. Merging and cleanup are explicit; nothing happens by accident.
- **Utgard** — the sealed execution barrier (the realm outside the wall). Untrusted or
  risky code runs in an **ephemeral container**: no host root, **no network by
  default**, CPU/RAM/timeout caps, a read‑only rootfs, and **only the task worktree
  mounted**. A failed run leaves no trace on `main`.

Yggdrasil keeps work *apart*; Utgard keeps it *contained*.

## What you need

- Ymir installed.
- For Utgard: a container engine (Docker or rootless Podman) and the image —
  `bin/forge/utgard.sh build` builds `utgard-runner:latest`.

## Do it

**Yggdrasil — a worktree per task:**

```bash
bin/forge/yggdrasil.sh create <id>            # .yggdrasil/<id>/ on its own branch
bin/forge/yggdrasil.sh list
bin/forge/yggdrasil.sh status <id>
bin/forge/yggdrasil.sh merge  <id>            # explicit, never automatic
bin/forge/yggdrasil.sh cleanup <id>           # remove it when done
```

**Utgard — a sealed run:**

```bash
bin/forge/utgard.sh status                    # image, network default, caps
bin/forge/utgard.sh build                     # build the image (once)
bin/forge/utgard.sh run <worktree> -- <command…> \
    [--network none|on] [--cpus N] [--memory M] [--timeout S]
```

**Sandcastle** is the engine underneath; the door delegates to it:
`bin/forge/utgard.sh sandcastle <args…>`.

## Notes and limits

- **A sealed run is one‑shot.** Utgard runs a command, capped and read‑only — it is not
  an interactive shell (for an interactive no‑network shell, use a **confidential
  session**, Rule 16).
- **No network by default.** `--network none` is the default; opening it is a
  deliberate act printed in the command, never a hidden setting.
- **herdr is the ordinary road; Utgard is the barrier.** Normal work runs in a herdr
  workspace in the worktree with **no container**; Utgard is for untrusted code. A
  declared `utgard` with no image is a **loud refusal**, never a silent downgrade.
- **One worktree per task** — parallel workers never touch each other's files.

## If it does not work

| What you see | What to do |
|---|---|
| `image utgard-runner:latest missing` | `bin/forge/utgard.sh build`. |
| `neither docker nor podman is reachable` | Start the engine, or declare `Isolation: herdr` deliberately. |
| A run times out | Raise `--timeout`, or the work does not fit the cap — split it. |
| A worktree will not merge | It diverged; resolve on its branch (see [resolving conflicts]). Yggdrasil never forces. |
