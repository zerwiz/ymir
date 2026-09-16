# `.agents/backend/` — the backend layer

**What this folder is.** Two things that share one job — *make work happen and
report it truthfully*:

1. **The vendored firstmate runtime** (`fm-*`) — the validated upstream we ported
   Ymir's dispatch from (`~/firstmate`, the source of the Einherjar/fm-spawn
   lifecycle). Vendored, not rewritten: it is the reference implementation of
   spawn → send → peek → watch → teardown, and it stays byte-comparable to
   upstream so a port can be checked against it.
2. **The model bridges** (`model-bridge.py`, `opencode-go-bridge.py`) — Ymir's
   own, the only files here we wrote. They are the reason this README exists: the
   bridge was the cause of the Cloudflare 1010 night (see the plan's Amendment I).

**Every file's own header is the owner of its contract.** They all say so
explicitly ("this header is the one owner of…"), and that is deliberate: this
README must not become a second, drifting description. Read a file's first twenty
lines for its exact rule; read here for the map.

## The owners, by family

```
families[12]{family,owns,subsystem,ui_part}:
  "spawn / lifecycle","fm-spawn.sh fm-send.sh fm-peek.sh fm-control.sh fm-teardown.sh fm-promote.sh fm-merge-local.sh","Einherjar (the door)","Hlidskjalf · Fleet — create, steer, land a task"
  "state","state/<id>.meta, crew/current state: fm-crew-state.sh fm-inactive-reconcile.sh fm-project-mode.sh","Hlidskjalf · Fleet","the task cards: kind, posture, branch, worktree"
  "watch / wake","the watcher and its wake queue: fm-watch.sh fm-watch-arm.sh fm-watch-checkpoint.sh fm-wake-*.sh fm-classify-lib.sh fm-transition-lib.sh","Sýn (supervision)","Hlidskjalf · Status — needs-decision, blocked, the lock state"
  "lease / lock","who may act on a task: fm-lease.sh fm-lease-lib.sh fm-lock.sh fm-session-lock-lib.sh","Gleipnir (the lock)","Hlidskjalf · Status — the session-lock indicator"
  "busy / composer","is the agent working, is the composer ready: fm-busy-lib.sh fm-busy-event.sh fm-composer-lib.sh fm-tmux-lib.sh","Hlidskjalf · Fleet","the per-task state chip (working / paused / waiting)"
  "process → events","long-polling children turned into wakes: fm-procevent.sh fm-procevent-lib.sh fm-procevent-{quota,when,lavish,remote-reply}.sh","Nornir (fate)","Hlidskjalf · Status — scheduled events and quota warnings"
  "remote / secondmate","other homes over SSH: fm-on.sh fm-remote-*.sh fm-home-seed.sh fm-remote-home-*.sh","Yggdrasil (the trunk)","Hlidskjalf · Homes — the secondmate list and its liveness"
  "pr / merge","the delivery gate's other half: fm-pr-check.sh fm-pr-lib.sh fm-pr-merge.sh fm-pr-poll.sh fm-merge-outcome-lib.sh","Mjollnir (the gate)","Hlidskjalf · Reviews (Glitnir) — open, merged, refused"
  "briefs / contracts","what a worker is told, and what done means: fm-brief.sh fm-dod-lib.sh fm-branch-prompt.sh","Smiðja · Erindi","Smiðja · run detail — the brief and the definition of done"
  "voice","the spoken interface: fm-voice-client.py fm-voice-relay.py fm_voice_*.py","Óðrerir (the hall)","Óðrerir · the hall — spoken status and queued work"
  "CI installs","pinned, checksum-verified tool builds: fm-install-{herdr,shellcheck,actionlint,treehouse}.sh","Ymir's CI","(no UI — the pipeline only)"
  "model bridge","the provider door: model-bridge.py + the opencode-go-bridge.py shim","Bifrost (the crossing)","Hlidskjalf · Models — which provider answers, and whether it is local"
```

## What the UI must be connected to

The rule for every row above: **the UI reads the record, never the prose.** A
panel that parses a log for state is a panel that will lie to the operator.

```
ui_links[6]{surface,reads,shows}:
  "Hlidskjalf · Fleet","state/<id>.meta via fm-crew-state.sh","each task: kind, harness, model, branch, worktree, posture"
  "Hlidskjalf · Status","fm-busy-lib.sh's semantic busy contract (never a pane scrape)","working / paused / needs-decision / done / failed, and the lock"
  "Hlidskjalf · Reviews (Glitnir)","fm-pr-*.sh records (provider, url, number, head)","what is open, merged or refused — the delivery gate"
  "Hlidskjalf · Homes","fm-fleet-snapshot.sh --json and the secondmate registry","the other homes, their liveness and their scope"
  "Óðrerir · the hall","fm-fleet-snapshot.sh --json (the ONE structured contract)","the live board: sessions, phases, spend, ledger"
  "Smiðja · trace","the run's own SQLite trace","phases, envelopes, retries — what the work actually did"
```

**The rule this folder exists to enforce, and it is the lesson of this session:**
a seat is not a spawn; a spawn is not a delivery; a delivery is not a record. The
lifecycle above is the only path that turns an intention into a *record* the UI can
honestly show — which is why `bin/einherjar-spawn.sh` is the door and typing into a
pane is forbidden (rule 09 / the spawn seatbelt).

## The bridges, and the law they broke

`model-bridge.py` exposes a provider to pi as a local OpenAI-compatible endpoint,
reading the credential from the env. It sat at `127.0.0.1:4603` **while forwarding
to a cloud gateway** — a localhost address that left the machine. Its `urllib`
client was refused by Cloudflare (1010, browser_signature_banned) while `curl`
passed on the same request, and the fix is a session header plus a transport with
a fingerprint the edge admits. The law it violated is now Rule 09's sibling:
*local is not a port number; it is a promise.*

## Maintaining this

- **Owner:** Brokk. **Upstream:** `~/firstmate` — a change here that upstream does
  not have is drift, and should be a documented port, not a quiet edit.
- **Never rename an `fm-*` file** to a Norse name while the upstream reference is
  needed: names are the join between the two trees.
