# Smíðja — the smithy (agent factory)

Load this when working with the smithy: installing it, configuring its roster,
running a chain, reading its trace, or wiring it into Hlidskjalf.

- **Norse:** **Smíðja** = the smithy (the workshop). Its orchestrator seat is
  **Völundr**, the master smith — *Kaia's seat inside the factory* (Kaia decides
  *what* is forged; Völundr decides *how* the smithy runs). Its trace UI is
  **Smíðja's eye**.
- **Registry:** `.agents/assets/agents/naming.md`, `docs/lore.md` §XI/§XIII.
- **Skill (adopted upstream):** `.agents/skills/smidja-factory/` (internals + cookbooks +
  references + `apps/visualizer/` + sibling skills `smidja-launcher`, `smidja-start`,
  `smidja-instructions`, `volundr`).

**Two layouts, one smithy — do not confuse them.** A *target* repo the smithy is
installed into gets the stamped `smidja/` tree (what `install.py` writes). **In
Ymir itself the instance lives at `apps/smidja/`** — it moved out of the repo root
so the smithy sits with the other apps, and its runtime data
(`apps/smidja/smidja_data/`, gitignored) may also live at `$YMIR_HOME/smidja/`,
which the runtime prefers when it exists. Every path in *this* repo points at
`apps/smidja/`.

## What it is

*Agents plus code*: deterministic Python scripts own sequencing, retries, and
acceptance; coding agents (Pi) work inside bounded **phases**; typed JSON
**envelopes** carry context between them; everything streams into **SQLite** so it
can be watched. *Agent proposes, code disposes.*

## Install into a repo (idempotent)

```bash
cd <repo-root>            # e.g. $YMIR_ROOT
uv run .agents/skills/smidja-factory/scripts/install.py
```

Stamps `smidja/` (the starter smithies + `smidja_modules/`), the prompt and harness
engineering dirs, `smidja/smidja_smidja_config/smidja.config.yaml`, `.env.sample`,
`justfile`, and `.gitignore` entries. Existing files are skipped unless `--force`.

Not writable, it fails plainly: a `PermissionError` never escapes as a traceback —
the script checks the target and returns exit 1 with the reason, so a failed
stamp is legible rather than a stack of Python.

There is **no separate CLI install**: the launcher `scripts/smidja` belongs to the
`~/command` provenance repo; in Ymir use the `justfile` recipes or `uv run
smidja/smidja_*.py` directly.

## Roster & models — through pi's `models.json`

- The roster: `smidja/smidja_smidja_config/smidja.config.yaml`. `defaults.model`
  and each agent's `model:` are **`provider/id`**, resolved by **pi** from
  `~/.pi/agent/models.json`. List what resolves with `pi --list-models`.
- They are written as env-expandable placeholders so one backend can be chosen
  without editing the roster: `${SMIDJA_LOCAL_MODEL:-…}` and per-role
  `${SMIDJA_<ROLE>_MODEL:-…}`. `just` loads `.env` (`set dotenv-load`).
- Example local model (llama.cpp router on `:8080`):
  `llama-cpp/qwen3.6-35b-a3b@iq3_s`. Verify one-shot:
  `pi -p --no-session --model "llama-cpp/qwen3.6-35b-a3b@iq3_s" "reply OK"`.
- Keys: the starter roster names cloud providers (`google`, `fireworks`, `openai`)
  → `OPENROUTER_API_KEY` / `FIREWORKS_API_KEY` / `OPENAI_API_KEY` in `.env`. A local
  llama roster needs no key.

## Run

```bash
# via justfile (repo root)
just demo                       # two cheap read-only runs (scout), end to end
just prompt "summarize this repo"
just scout "where is auth handled"
just sdlc "add a /health endpoint"
just sessions                   # last 10 runs
just phases <smidja_id>         # phase status in sequence
just tail   <smidja_id>         # live event tail
just procs  <smidja_id>         # live pids

# raw
uv run apps/smidja/smidja_prompt.py --agent scout "…"
uv run apps/smidja/smidja_scout.py "…"
```

The watch recipes use **`python3 -c`** over the SQLite db (the `sqlite3` CLI is not
installed on this machine) — do not reintroduce `sqlite3`.

## The trace

- DB: **`$YMIR_HOME/smidja/smidja.db`** (WAL; read-only readers never block a run).
  `0003-private-data-separation` moved it out of the checkout; an in-repo
  `apps/smidja/smidja_data/smidja.db` is the fallback. Created at the first run
  (`bin/smidja-bootstrap.sh`); `scripts/start.sh` resolves the same pair.
- Tables: `sessions` (`smidja_id, smidja_name, request, status, engineer,
  started_at, ended_at, total_tokens, total_cost, archived`), `phases`
  (`phase_id, smidja_id, seq, name, kind, owner, description, status, attempt,
  retries, error, …`), `events` (`event_id, smidja_id, phase_id, parent_id, type,
  name, payload_json, tokens, …`), `gate_results`, `envelopes`, `agent_sessions`,
  `processes`.

## Smíðja's eye — the trace visualizer

- **Open at `http://127.0.0.1:8437/`.** One Bun server serves both the read-only
  API (`bun:sqlite` over the trace db) **and** the built Vue UI from
  `apps/visualizer/dist`. A Vite dev server on `:8438` is opt-in
  (`SMIDJA_VIZ_DEV=1`) and is not needed for use.
- **The carved cloth (2026-09-13).** The default theme is **fensalir** — the
  landing page's stone/bone/bronze/blood and its three faces (Cormorant display,
  Newsreader UI, IBM Plex Mono data), cut into `src/style.css` `:root` and into the
  components' role colours (`var(--accent)`, `var(--green)`, `color-mix(…)`). The
  titlebar toggle cycles **fensalir → classic → high-contrast**; `classic` (the
  preserved deep-space look) and `high-contrast` (WCAG AAA) are deliberate
  overrides and **win when chosen** — the cloth is the default, not a cage. A
  saved `neutral` from an older build resolves to fensalir. The categorical
  palettes (event dots, agent lanes in `src/lib/events.ts`) are data, not chrome,
  and were re-cut onto the cloth while staying mutually distinct.
- `scripts/start.sh` raises it (`CMD_DB=$YMIR_HOME/smidja/smidja.db`, else the
  in-repo fallback; `PORT=8437`); `scripts/stop.sh` lowers it. Port overrides:
  `SMIDJA_VIZ_API_PORT`.
- Served under Hlidskjalf's **Sessions** gate via **Open visualizer**
  (`VITE_VISUALIZER_URL`, default `http://127.0.0.1:8437`).
- **Shared login, verified live (added 2026-09-13).** The server exposes
  `GET /api/auth`, which forwards the browser's cookie to the gate's
  `/api/session` and returns `{authed, login}`; `App.vue` shows a "Sign in" link
  (to the gate) or "ᛉ <login>" from that live answer. It **never** reads a
  session file — a token on disk would let a user look logged in when they are not.
- **The Hall door (added 2026-09-13).** `App.vue`'s topbar carries a **To the
  Hall** pill (rune Othala ᛟ, `.hall-btn`) beside the theme toggle: a new tab to
  the Óðrerir Live Hall — `http://localhost:4322` when
  `window.location.host` starts with `localhost`/`127.0.0.1`, otherwise
  `https://hall.ymir.zerw.org`. It is a **plain anchor, not a `/api/desktop`**
  launcher: the Hall is the landing's live board, not one of the three apps the
  gate raises. Same door in Hlidskjalf's and Sessrúmnir's chrome.
- See `docs/lore.md` §XIII.

## In Hlidskjalf (the gate API)

`apps/hlidskjalf/server` exposes the trace read-only:
`/api/smidja/health · /api/smidja/sessions · /api/smidja/sessions/:id ·
/api/smidja/decisions · /api/smidja/stats`. Four gates render it: **Sessions**,
**Trace**, **Decisions**, **Stats**. Smíðja loads on its own track and is polled
every 5s, so a finished run appears without a reload.

## The observer (Huginn) — self-contained

`bin/nornir-job-observer.sh` runs on the Nornir schedule (06:00). It reads **only
Ymir's own runtime** — `docs/masterplan.md`, `.agents/agents`, `.agents/memory/well`,
`workspace/memory/runes_audit.md`, **`$YMIR_HOME/smidja/smidja.db`**, and the
read-only external worktree root — and writes only `state/observer.log` + Runes.
There is **no `~/command` connection** anywhere in Ymir. Rune sources:
`ymir.orders · ymir.agents · ymir.well · ymir.runes · smidja.runs ·
yggdrasil.worktrees`. See `assets/nornir-jobs.md`.

## Smoke test

```bash
SMIDJA_LOCAL_MODEL=llama-cpp/qwen3.6-35b-a3b@iq3_s \
  uv run apps/smidja/smidja_prompt.py --agent scout \
  "Reply with a single line: which top-level directories exist in this repo. Change nothing."
```

Expected: `2/2 phases passed`, a `smidja_id`, and the DB written. Then
`just sessions` and `just phases <id>` read it, and
`curl -s localhost:8437/api/health` reports `"sessions": N`.

## Gotchas

1. **`sqlite3` CLI is absent** — use `python3 -c` (the justfile already does).
2. **Local models are served by the llama.cpp router `:8080`**, addressed as
   `llama-cpp/<id>`; LM Studio `:1234` may be down. Confirm with `pi --list-models`.
3. **The visualizer's local `node_modules` may be a partial bun install** — the API
   still serves the prebuilt `dist/`, so open `:8437`, not `:8438`.
4. **Never edit `apps/smidja/smidja_data/sessions/`** — it is the run record.
5. **Protected files** (`apps/smidja/smidja_modules/`, `apps/smidja/smidja_*.py`, the config)
   are enforced by `smidja_modules/permissions.py`; agents roll back unauthorized
   changes. The smithy moved from the repo root `smidja/` to `apps/smidja/`
   (Amendment C); `bin/smidja-bootstrap.sh` searches both so a stale layout cannot
   break the DB seed again.
6. New skills synthesized for the smithy are validated in Utgard (Gungnir, W0007)
   before production.
