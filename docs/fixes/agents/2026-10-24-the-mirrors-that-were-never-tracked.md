# The mirrors that were never tracked — a lawful tree that could not renew

**Dated:** 2026-10-24 · **Component:** agents · **Branch:** `fix/agent-mirror-symlinks`
**Found on:** sleipnir (the hand — Termux/Android, Pi 1.4.0)

## The symptom

Gróa refused to renew the home:

```
groa[1]{state,root,remote,branch,mode}:
  "renew",…,"check"
update[1]{id,target,state,detail}:
  "…/ymir","this Brokk home","skipped","dirty (11)"
```

Eleven dirty entries on a tree nobody had edited: one deliberate local patch, and **ten untracked
symlinks**.

## The fault

Rule 02 says `.agents/agents/` is canonical and every harness directory mirrors it by symlink. The repo
tracks **105** such mirrors across `.claude/agents/`, `.codex/agents/`, `.cursor/agents/`,
`.opencode/agents/` and `.pi/agents/`. When two agents were added — `modgud-auditor` and `vidarr-defender`
— their canonical files came in with the pull, and the ten mirrors were created on the machine by the
harness sync, but **never committed**:

```
.claude/  .codex/  .cursor/  .pi/      modgud-auditor.md   vidarr-defender.md
.opencode/                             modgud.md           vidarr.md   (canonical names differ)
```

So a tree obeying the naming law *perfectly* sits permanently dirty — and **a dirty tree cannot renew**. The
renewal was blocked not by the network, not by a remote, but by ten symlinks pointing at files that were
already tracked.

## The fix

Track the ten symlinks. They carry no content — each points at `../../.agents/agents/<agent>.md`, a file
already in the repo — so the commit adds names and targets, nothing else.

## Verification

```
git status --short            → empty on a clean checkout carrying both agents
bin/agents/groa-update.sh     → update[1]{…"current",…}   (no "dirty (11)" skip)
```

## Restart

None. Symlinks are read at load time by the harness and at scan time by Gróa; the next `pi` start and the
next Gróa run see them. No session must be closed for this fix.
