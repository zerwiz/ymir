# Bilskirnir keeps only its own pieces, and proves the face is served

**2026-11-12 · component: apps · `apps/bilskirnir/start.sh` · `apps/bilskirnir/tests/start-owns-ports.sh`**

## What was wrong

The desktop icon opened a window onto "404 Not Found". `start.sh` found the server, gateway and Vite ports already
answering, printed "already answers — kept", and opened a window on them. Those were a stale dev server, gateway
and Vite from an old worktree. That server serves only the API, so `GET /` returned 404.

## What was done

| Part | What it does now |
|---|---|
| Ownership | A listener is ours only when it is in the process group of the pid under `data/run/<piece>.pid`, or its working directory is inside this app's tree (or the app's engine home, for the gateway). |
| Stranger | Anything else on the port is named by pid and working directory. `start.sh` never calls it "kept" and exits 1 with the exact `kill <pid>` command. |
| Sibling tree | A stranger of the same user whose working directory is under `*/apps/bilskirnir/*` is another Bilskirnir tree. It is lowered (SIGTERM, its pid only) and ours is raised. |
| Face check | The server counts as up only when `GET /` returns a 2xx HTML page, not merely when `/api/health` answers. `--check` reports the face and any stranger, and exits 1. |

Nothing that is not provably a Bilskirnir process is ever killed. An unreadable working directory counts as a stranger.

## Proof

`apps/bilskirnir/tests/start-owns-ports.sh` runs a copy of `start.sh` against stub servers on free ports: a stranger
is refused and named and left alive, a sibling tree is lowered, our own server with the face is kept, and an answering
server without the face is refused. All eleven checks pass.
