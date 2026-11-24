## hlidskjalf · unversioned · 2026-11-24 — every session on the machine, from every tool, read into one index (plan 368)

### Why

Nothing read the agent sessions together. The Decisions panel grouped only Smíðja's failures, so the same failure in a
Claude, pi, Codex, Hermes or opencode session was invisible, and no project knew what its sessions had left undone.

### What changed

- **`bin/records/sessions_index.py`** (door `ymir sessions`, wrapper `sessions.sh`): read-only adapters for the five
  tools, incremental by byte offset or time; spans in the OpenTelemetry GenAI shape (convention 1.37.0 pinned) plus
  `ymir.*`; a seat index in SQLite under the state dir.
- **Redaction before indexing**: house secret patterns, bearer tokens, e-mail, the vault mount. Vault sessions are
  counted only. Raw transcripts are never copied.
- **Project join** through plan 367's resolver (cwd, worktrees, git remote). `projects-status.sh --json` now carries
  `sessions` per project (by tool and seat) and the next updates.
- **Next updates and alerts** without a model (recurring failures, sessions ended on an error; failure rate, cost per
  session, judged quality). **The judge pass** runs only on the machine's own profile and is off without one.
- **Faces**: `/api/sessions/index` and `/api/sessions/decisions`, an all-tools block in the Sessions panel, a
  cross-tool block in Decisions, a sessions column in Projects. `--fleet` / `?fleet=1` is opt-in: this machine asks
  other seats and names the source seat. Optional OTLP export, off unless a collector is named.
- **`tests/test_sessions_index.sh`**: 23 checks on fixtures for all five adapters, no heart.

### Decisions (the Allfather, 2026-11-24)

Complete on one computer; the heart only adds summaries and a fleet filter. Every answer is built by the machine the
user sits at.

### Not done

The judge profile is read from env or `config/sessions.yaml`: plan 365's `ymir work models` role `judge` does not exist
yet, so there is no link to it. The judge pass is not scheduled on the heart, and the morning brief's cron job is not
edited (`ymir sessions brief` gives the lines). Cursor and other tools have no adapter yet. Raw retention is left where
each tool wrote it.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #927
