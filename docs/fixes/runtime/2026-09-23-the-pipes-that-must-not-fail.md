## runtime · unversioned · 2026-09-23 — the pipes that must not fail: handoff, Firecrawl, the day's log

### Why
Four pipes were built but never carried anything.

1. **The handoff.** Huginn finished a research round at 18:26 and Brokk never
   noticed for 28 minutes. Three causes: the when-adapter **runner was not
   running** (`fm-procevent.sh` down, so no source ever polled); the arm wrote
   its spec into a **worktree** (`fm-procevent-when.sh` derives its state from
   the script's location, and `eindri-watch.sh` had run from `.yggdrasil/…`, a
   path deleted on cleanup — also a Rule 04 violation); and nobody looked.
2. **Firecrawl.** Self-hosted and answering `:3002 → 200` on both heimdall and
   whynot, but `bin/nornir-job-bragi-scrape.sh` still demanded a **cloud key** —
   and imported the `firecrawl` Python SDK, which is not installed. The engine
   was installed and unused.
3. **The source list.** The job's header named `$YMIR_HOME/config/scrape-sources.yaml`
   while its code resolved `$YMIR_HOME/hodd/config/…` — a shelf that does not
   exist, so it always reported "no sources".
4. **The day's record.** The hoard contract names the shelf — `hodd/memory/daily/YYYY-MM-DD.md`
   — and nothing wrote there, so a session's work scattered into one-off
   documents under `hodd/docs/`.

### Fix
- **`bin/eindri-handoff.sh`** — the handoff FAILSAFE. It sweeps
  `$STATE/eindri-reports/` and `$STATE/eindri-questions/` for anything not yet
  delivered and puts it in the wake queue, so Sága's drain surfaces it in the
  next session digest. Idempotent (one delivery marker per item); exit **3** when
  something *was* waiting. A question and a report keep separate markers, so a
  question is never mistaken for a finished errand.
- **`bin/saga-session-start.sh`** — runs the sweep **before** the wake drain, so
  the digest always shows undelivered work.
- **`bin/eindri-watch.sh`** — pins `FM_STATE_OVERRIDE` to the **hoard**
  (`$YMIR_HOME/state/procevent`), so a spec armed from a worktree lands where the
  runner looks.
- **`bin/nornir-job-bragi-scrape.sh`** — a **URL, not a key**:
  `FIRECRAWL_API_URL` (env → home env → the documented default `:3002`), and
  **curl instead of the SDK** (`/v2/scrape` for a URL, `/v2/search` for a query).
  The source list resolves to `$YMIR_HOME/config/`, matching its own header.
- **`bin/daily-log.sh`** — the day's work recorded where the contract says:
  `daily-log.sh add "<what>" [--actor NAME] [--tag T]`, appended dated blocks in
  `$YMIR_HOME/hodd/memory/daily/YYYY-MM-DD.md`; `today`/`show`/`list` read it
  back. Also surfaced by the session-start digest under a **TODAY** section.

### Verification
- **The failsafe caught exactly what was missed**, and is idempotent:
  `status` → `3` undelivered (snotra QUESTION, huginn REPORT, snotra REPORT);
  `sweep` → delivered 3 into the wake queue; `status` → `0`, exit 0.
- **The arm lands in the hoard:** armed from the worktree, the spec appeared at
  `$YMIR_HOME/state/procevent/when/when-testprobe.spec`, not in the tree.
- **The runner polls:** `reconcile` → `started=1`; `list` → `when-bragi … live`.
- **Firecrawl actually used:** `bragi-scrape: sources=12 ok=12 failed=0` — twelve
  pages of clean markdown in the marketing workspace, keyless.
- `bash -n` clean on every script touched.

### Files
- `bin/eindri-handoff.sh` (new)
- `bin/daily-log.sh` (new)
- `bin/saga-session-start.sh`
- `bin/eindri-watch.sh`
- `bin/nornir-job-bragi-scrape.sh`
- `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md`
