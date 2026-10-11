# Sága — the session start

## What it is

**Sága** is the seeress: the one digest a session reads before its first word. Instead
of a dozen files and many turns, she collapses the runtime's session start into **one
ordered report** — what stands, what is owed, what the seat is. When a harness opens in
the repo, Sága speaks first.

## What you need

- Ymir installed and raised.
- Nothing else — it is the first thing to run.

## Do it

```bash
bin/time/saga-session-start.sh
```

One command, in a fixed order:

1. **lock** — acquire the per-home session lock (Gleipnir) *first*.
2. **bootstrap** — detect‑only diagnostics: tool floors, realm env.
3. **wake queue** — durable wakes (the Ratatoskr inbox, approvals).
4. **supervision** — the operating block for the detected harness.
5. **fleet digest** — Eindri tasks, open forge orders, state metadata.
6. **context digest** — realm, operator, projects, learnings, the hoard.
7. **cron start** — ensure the scheduled jobs are running (idempotent).

Most harnesses run it **for you**: OpenCode/Pi/Claude Code/Cursor/Codex each own a
session‑start surface that speaks the digest. You only run it by hand when you want
the truth again mid‑session.

```bash
bin/time/saga-sessionstart-run.sh     # the run-tier door (used by the harness hooks)
```

## Notes and limits

- **It is read‑only except for the lock and cron.** It reports; it does not change the
  tree.
- **If it already spoke, do not run it again.** The harness injects it; running it a
  second time is duplication, not diligence.
- **The lock comes first** so a second primary on the same machine is refused before
  anything else.

## If it does not work

| What you see | What to do |
|---|---|
| Refused: the lock is held | A live primary owns the seat — end it, or inspect the `lock` surface with `bin/agents/eir-doctor.sh`. |
| No digest in the harness | The session‑start surface is not seated — `bin/seat/valknut-load.sh --check`, then re‑bind. |
| Cron did not start | `bin/time/nornir-cron-start.sh --status`; the digest's step 7 is idempotent, so re‑run it. |
