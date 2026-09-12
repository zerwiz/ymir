# Porting Brokk to Norse — the methodology we actually used

> Purpose: the reproducible record of how Ymir adopted the validated **Brokk** agent distro and retargeted it to the Brokk runtime — copy-then-edit, the coupling audit, the mechanical rename rules, the two critical invariants, what was deferred, and the verification protocol.

Reference is read-only: the upstream distro lives at `/home/zerwiz/Brokk` and is cited here by path as **provenance**, never as a Ymir component name. Ymir follows the **open-source-first** law (`AGENTS.md:91-97`): reuse the validated OSS pattern, do not rebuild it. This document is the porting record, not a second architecture.

## 1. Why adopt rather than rebuild

`/home/zerwiz/Brokk` is an **agent distro** (`README.md:36-41`): a directory of instructions, skills, tooling, policies, and state conventions that turns a general-purpose agent into a specialized one. Its mechanism is exactly the function Ymir needed — a harness opened in the repo instantiates the primary and injects context before the first turn.

| What Brokk proved | What Ymir inherited |
|---|---|
| Role adoption on launch (`AGENTS.md:1-12`) | `AGENTS.md` mandate: "You are Brokk; the operator is the Allfather" |
| One-command session start (upstream digest) | `bin/saga-session-start.sh` |
| Native harness injection (`bin/fm-sessionstart-run.sh`, `.opencode/plugins/fm-primary-sessionstart-nudge.js`, `.pi/extensions/fm-primary-turnend-guard.ts`, `.claude/settings.json`) | `bin/saga-sessionstart-run.sh`, `.opencode/plugins/saga-sessionstart.js`, `.pi/extensions/syn-turnend-guard.ts`, `.claude/settings.json` |
| Home separation (`FM_HOME`, `AGENTS.md:42-54`) | `BROKK_HOME`; private `data/ state/ config/` |
| Context sources (`data/Allfather.md · projects.md · learnings.md`, state metas) | `data/operator.md · projects.md · learnings.md` |
| Harness detection + dispatch (`bin/fm-harness.sh`, `bin/fm-spawn.sh`, `config/eindri-harness`, `config/crew-dispatch.json`) | `bin/hamr-harness.sh`, `bin/einherjar-spawn.sh`, `config/eindri-harness`, `config/eindri-dispatch.json` |
| Supervision, no cron (`bin/fm-watch-arm.sh`, `bin/fm-turnend-guard.sh`, `docs/supervision-protocols/`) | `bin/syn-watch-arm.sh`, `bin/syn-turnend-guard.sh`; Nornir added for the scheduled spine |
| Isolation (Yggdrasil worktrees, Eindri-home homes) | Yggdrasil worktrees; Eindri-home dropped |

**Ymir only builds what differentiates it** — the UI/UX, the agent runtime, and A2A collaboration. Everything else is adopted. The port is therefore a *retarget*, not a rewrite.

## 2. Method — copy-then-edit

The method is deliberately mechanical:

1. **Copy the generic mechanism**, file for file, from `/home/zerwiz/Brokk` into the Ymir tree at the same role position.
2. **Preserve the contract shape** (argument grammar, exit codes, environment overrides, output lines) so the ported scripts remain behaviorally identical where the mechanism is generic.
3. **Retarget the labels** with a fixed rename table (§4). The retarget is a find-and-replace over names, not a redesign.
4. **Trim to the Ymir surface.** Drop features that have no Ymir owner (Eindri-home homes, extra backends, presentation theming, relays).
5. **Re-verify** with the protocol in §7 before calling any ported file production.

Why not rebuild: the upstream scripts encode years of edge-case handling (lock ancestry, pid reuse, heartbeat staleness, date-guarded scheduling, chain-locked ledgers). Rebuilding would re-learn those edges at the cost of production incidents. Copying carries the learned behavior across; editing the labels makes it ours.

## 3. Coupling audit

Before retargeting, every upstream file was classified. The rule: **generic mechanisms are copied; coupled surfaces are either retargeted or dropped.**

### 3.1 Generic (copied, then label-retargeted)

| Upstream file | Generic mechanism | Ymir file |
|---|---|---|
| `bin/fm-harness.sh` | two-layer harness detection (env markers, ancestry walk) | `bin/hamr-harness.sh` |
| `bin/fm-session-start.sh` | one ordered startup digest | `bin/saga-session-start.sh` |
| `bin/fm-sessionstart-run.sh` | source routing (startup/compact/resume) | `bin/saga-sessionstart-run.sh` |
| `bin/fm-session-lock-lib.sh`, `bin/fm-lock-lib.sh` | per-home lock bound to a live pid | `bin/gleipnir-lock-lib.sh` |
| `bin/fm-wake-drain.sh` | durable wake presentation | `bin/saga-wake-drain.sh` |
| `bin/fm-watch-arm.sh` | one event-driven watch cycle | `bin/syn-watch-arm.sh` |
| `bin/fm-turnend-guard.sh` | refuse a blind turn end | `bin/syn-turnend-guard.sh` |
| `bin/fm-arm-pretool-check.sh` | deny backgrounding the arm | `bin/syn-arm-pretool-check.sh` |
| `bin/fm-cd-pretool-check.sh` | deny escaping the home | `bin/syn-cd-pretool-check.sh` |
| `bin/fm-operational-input.sh` | structured operational wire (encode/kind/classify/body) | `bin/rodd-operational-input.sh` |
| `bin/fm-brief.sh` | worker brief scaffold with a fixed delivery-contract line | `bin/erindi-brief.sh` |
| `bin/fm-spawn.sh` | worktree + backend launch + meta record | `bin/einherjar-spawn.sh` |
| `bin/fm-crew-state.sh` | reconcile status log vs backend liveness | `bin/vor-crew-state.sh` |
| `.pi/extensions/fm-primary-turnend-guard.ts` | inject digest, re-emit on compaction, refuse blind end | `.pi/extensions/syn-turnend-guard.ts` |
| `.pi/extensions/fm-primary-pi-watch.ts` | watcher continuity (arm/re-arm/deliver) | `.pi/extensions/gna-pi-watch.ts` |
| `.pi/extensions/lib/fm-sessionstart-supervisor.mjs` | supervise the digest child | `.pi/extensions/lib/vordr-sessionstart-supervisor.mjs` |
| `.pi/extensions/lib/fm-operational-input.ts` | wire bridge for Pi | `.pi/extensions/lib/rodd-operational-input.ts` |
| `.opencode/plugins/fm-primary-sessionstart-nudge.js` | nudge-tier session-start injection | `.opencode/plugins/saga-sessionstart.js` |
| `.opencode/plugins/fm-primary-watch-arm.js` | watcher-arm continuity in the TUI | `.opencode/plugins/syn-watch-arm.js` |
| `.opencode/plugins/fm-primary-turnend-guard.js` | turn-end guard for OpenCode | `.opencode/plugins/syn-turnend-guard.js` |
| `.opencode/plugins/fm-primary-pretool-check.js`, `…-cd-check.js` | seatbelt pre-tool checks | `.opencode/plugins/syn-pretool-check.js`, `syn-cd-check.js` |
| `config/crew-dispatch.json` | per-task harness/model/effort rules | `config/eindri-dispatch.json` |
| `docs/supervision-protocols/*.md` | per-harness operating blocks | (folded into the Sága supervision stage; protocols deferred) |

### 3.2 Coupled (retargeted or dropped)

| Upstream surface | Coupling | Disposition |
|---|---|---|
| `Allfather` / `Allfather.md` | Brokk identity | **retargeted** to Allfather / `data/operator.md` |
| `Eindri` / `fm-crew-state.sh` | Brokk identity | **retargeted** to Eindri / `bin/vor-crew-state.sh` |
| `crew` subcommand of `fm-harness.sh` | Brokk identity | **retargeted** to `eindri` (see §9 for the caller bug) |
| `Yggdrasil` worktrees | Brokk tooling | **retargeted** to Yggdrasil (`.yggdrasil/<id>`) |
| `Eindri-home` homes, `config/Eindri-home-harness`, `fm-Eindri-home-*.sh` | Brokk fleet scope | **dropped** — one Brokk home; realm homes cover scope |
| `calm` presentation (`config/calm`, `.pi/extensions/fm-calm*.ts`, `docs/calm*`) | Brokk UX | **deferred** — presentation only; not required to seat Brokk |
| Pi supervision branch (`fm-branch-supervision.ts`, `docs/pi-supervision-branch.md`) | Brokk runtime | **deferred** to W0073 |
| `bin/backends/{zellij,orca,cmux}.sh`, `codex-app` | Brokk backends | **dropped** — Ymir keeps `tmux` and `herdr` (Þjazi 14+) |
| `bin/fm-voice-*.py`, `fm_voice_*.py`, X/Discord relay (`fm-x-*.sh`, `fm-public-followup*`) | Brokk channels | **dropped** — Ratatoskr/Hlidskjalf own Ymir channels |
| `bin/fm-bootstrap.sh`, `fm-home-seed.sh`, `fm-remote-*.sh`, quota/procevent | Brokk infra | **dropped** — out of the Ymir surface |
| `AGENTS.md:1-...` personality and nautical voice | Brokk identity | **rewritten** into `AGENTS.md` SYSTEM MANDATE (Norse) |
| `.env`, `config/calm`, `config/startup-memory-budget` | Brokk preferences | **dropped/deferred** |

**Coupling rule.** A surface is *coupled* if its name, voice, or scope is Brokk-specific. Coupled surfaces are never copied verbatim; they are either retargeted (name/scope preserved, labels changed) or dropped. A copied file that still contains `Allfather`, `Eindri`, `Yggdrasil`, `FM_`, or `fm-` is a port defect.

## 4. Mechanical retarget rules

Apply these in order. After each pass, run the audit in §7.5.

| Pattern | Replacement | Notes |
|---|---|---|
| `FM_HOME` | `BROKK_HOME` | the private home selector |
| `FM_ROOT_OVERRIDE` | `BROKK_ROOT_OVERRIDE` | tracked code root |
| `FM_STATE_OVERRIDE` | `BROKK_STATE_OVERRIDE` | |
| `FM_CONFIG_OVERRIDE` | `BROKK_CONFIG_OVERRIDE` | |
| `FM_DATA_OVERRIDE` | `BROKK_DATA_OVERRIDE` | |
| `FM_*` (remaining) | `BROKK_*` | every upstream env var |
| `fm-` prefix | figure prefix (see below) | file and function names |
| `Brokk` | Brokk / Ymir (by role) | never a component name in Ymir |
| `Eindri` / `crew` | **Eindri** / `eindri` | |
| `Allfather` | **Allfather** | operator address |
| `Yggdrasil` | **Yggdrasil** | worktree root `.yggdrasil/` |
| `Eindri-home` | **dropped** | no replacement |
| `calm` | **deferred** | no replacement yet |
| `fm-crew-state.sh` | `bin/vor-crew-state.sh` | Vör = awareness of state |

Figure-prefix mapping for the `fm-` → `<-prefix>` pass:

| Upstream stem | Ymir stem | Figure |
|---|---|---|
| `fm-session-start`, `fm-sessionstart-run`, `fm-wake-drain` | `saga-*` | Sága (seeress / digest) |
| `fm-watch-arm`, `fm-turnend-guard`, `fm-arm-pretool-check`, `fm-cd-pretool-check` | `syn-*` | Sýn (watch) |
| `fm-harness` | `hamr-harness.sh` | Hamr (shape) |
| `fm-spawn` | `einherjar-spawn.sh` | Einherjar (gathered warriors) |
| `fm-brief` | `erindi-brief.sh` | Erindi (errand) |
| `fm-crew-state` | `vor-crew-state.sh` | Vör (awareness) |
| `fm-lock-lib`, `fm-session-lock-lib` | `gleipnir-lock-lib.sh` | Gleipnir (binding) |
| `fm-operational-input` | `rodd-operational-input.sh` | Rödd (voice) |
| `fm-sessionstart-supervisor` | `vordr-sessionstart-supervisor.mjs` | Vörðr (warden) |
| `fm-primary-pi-watch` | `gna-pi-watch.ts` | Gná (messenger) |
| `fm-primary-*` (OpenCode) | `saga-*` / `syn-*` by role | Sága / Sýn |

Runtime extension beyond the upstream distro: **Nornir** (`bin/nornir-cron-start.sh`, `bin/nornir-job-*.sh`, `config/cron.yaml`) and **Runes** (`bin/runes-append.sh`) have no Brokk equivalent. Brokk used a watcher only; Ymir adds the scheduled spine (plan 29 §6 stage 8) and the chained audit ledger.

## 5. The two critical invariants

These are the port's load-bearing fixes. Both came from observed Brokk behavior that does not survive a naive retarget.

### 5.1 Bind the lock to the live session pid

**Problem:** the digest runner is short-lived. If Gleipnir keyed `state/.lock` to the digest helper's pid, the lock would appear dead the moment the helper exited — and a second session could mutate shared state.

**Fix:** harnesses pass `BROKK_SESSION_PID`, and `gleipnir_lock_acquire` writes `${BROKK_SESSION_PID:-$$}`:

```bash
# bin/gleipnir-lock-lib.sh
printf '%s\n' "${BROKK_SESSION_PID:-$$}" >"$lock"
```

Ownership is proved by walking up to 8 ancestry levels (`gleipnir_lock_owned`), so the short-lived helper can still confirm the live session owns the chain. The Pi extension's `lockOwnership()` reads the same pid from `state/.lock` and treats missing / other / pid 1 as non-owned.

**Test:** open a session, note the pid in `state/.lock`, confirm it is the harness pid (not the digest pid) with the session still live.

### 5.2 Turn-end guard inert until first arm

**Problem:** Brokk's turn-end guard fires on every stop. If ported unchanged, a fresh Ymir session with no supervision yet would be told "supervision is off" on the very first turn — noise that trains the operator to ignore it.

**Fix:** `bin/syn-turnend-guard.sh` returns 0 unless `state/.supervision-armed` exists:

```bash
[ -f "$STATE/.supervision-armed" ] || exit 0
```

Only after a successful `bin/syn-watch-arm.sh` cycle writes the marker does the guard check `state/.watch.heartbeat` against `BROKK_WATCH_HEARTBEAT_STALE_SECONDS` and exit 2 when stale. **Do not arm the guard before the first successful arm.** This invariant is recorded in `data/learnings.md`.

## 6. What was deferred

Deferred means: named, bounded, and intentionally not built now. These are not bugs.

| Deferred item | Upstream source | Re-entry point |
|---|---|---|
| Presentation theming ("calm") | `config/calm`, `.pi/extensions/fm-calm*.ts`, `docs/calm*` | later plan; presentation only |
| Pi supervision branch | `.pi/extensions/fm-branch-supervision.ts`, `docs/pi-supervision-branch.md` | W0073 / W0053 |
| Per-harness supervision protocol docs | `docs/supervision-protocols/*.md` | when the Sága supervision stage needs per-harness blocks |
| Grok / Kimi adapters | Brokk hook scripts | plan 29 B-3 remainder |
| Eindri-home homes | `fm-Eindri-home-*.sh` | not planned (realm homes instead) |
| Extra spawn backends | `bin/backends/*.sh` | only if a validated need appears |
| Voice relay / X / Discord | `fm-voice-*`, `fm-x-*` | Ratatoskr/Hlidskjalf own channels |

The `.pi/extensions/README.md` records the same defers. Keep the two in sync.

## 7. Verification protocol

Every ported file must pass all five gates before it is called production. No mocks, no examples, no placeholders.

### 7.1 Shell syntax

```bash
for f in bin/*.sh; do bash -n "$f" || echo "FAIL $f"; done
```

### 7.2 JSON parse

```bash
for f in config/*.json .claude/settings.json .codex/hooks.json .cursor/hooks.json .opencode/plugins/package.json; do
  jq -e . "$f" >/dev/null || echo "FAIL $f"
done
```

### 7.3 TypeScript/JS parse (adapters)

```bash
node --check .opencode/plugins/*.js .opencode/plugins/lib/*.js 2>/dev/null
# Pi .ts files are validated by the Pi runtime and by the extension's own load marker
```

### 7.4 Smoke tests (behavioral)

| Test | Command | Expected |
|---|---|---|
| Digest end-to-end | `bash bin/saga-session-start.sh` | 8 sections; lock line; cron running; context delimited; `ABSENT` explicit |
| Digest routing | `bash bin/saga-sessionstart-run.sh --source compact` | re-emit text, exit 0 |
| Harness detect | `bash bin/hamr-harness.sh` and `… eindri` | prints a verified harness / configured Eindri harness |
| Lock semantics | open two sessions | second says `READ-ONLY: session lock held by pid N` |
| Wake drain | `bash bin/saga-wake-drain.sh` | `wake queue: 0 pending` when empty, never blank |
| Cron status/start | `bash bin/nornir-cron-start.sh --status`; `…` | `cron: running pid=N jobs=4` / idempotent start |
| Watch arm | `bash bin/syn-watch-arm.sh --restart` | prints `watcher: started …`, writes `.supervision-armed` + heartbeat, exits on a `signal:`/`stale:`/`check:`/`heartbeat:` line |
| Turn-end guard inert | run before any arm | exit 0 |
| Turn-end guard armed+stale | remove heartbeat after arming | prints recovery, exit 2 |
| Rödd wire | `printf 'hi' \| bash bin/rodd-operational-input.sh encode session-start` | one `\u2063RODD_OP: v1 session-start: hi`; `kind`/`body` round-trip |
| Runes append | `bash bin/runes-append.sh smoke event --message hi` | `runes: appended … checksum=…`; ledger gains one chained line |
| Brief scaffold | `bash bin/erindi-brief.sh T-smoke repo --mode local-only` | `data/T-smoke/brief.md` with `Delivery contract: mode=local-only` |
| Spawn fail-closed | `bash bin/einherjar-spawn.sh T-smoke . --mode local-only --harness bogus` | refuses: not verified |
| Dispatch backstop | with `config/eindri-dispatch.json` present, omit `--harness` | refuses: pass an explicit `--harness` |
| Vör read | `bash bin/vor-crew-state.sh T-smoke` | one `state: … · source: … · …` line, exit 0 |

### 7.5 Naming audit

```bash
grep -rniE 'Allfather|Brokk|Eindri|Eindri-home|fm-|Yggdrasil|calm' \
  bin .pi .opencode config data .agents/skills/galdr-cli/assets/*.md \
  | grep -v 'porting-upstream-to-norse.md'
```

Expected: only provenance citations in this file and the known legacy strings listed in `norse-naming.md` §6.3.

## 8. File-by-file port status

| Ymir file | Upstream origin | Status |
|---|---|---|
| `bin/saga-session-start.sh` | `bin/fm-session-start.sh` | landed, verified |
| `bin/saga-sessionstart-run.sh` | `bin/fm-sessionstart-run.sh` | landed, verified |
| `bin/gleipnir-lock-lib.sh` | `bin/fm-session-lock-lib.sh`, `bin/fm-lock-lib.sh` | landed, verified |
| `bin/hamr-harness.sh` | `bin/fm-harness.sh` | landed |
| `bin/einherjar-spawn.sh` | `bin/fm-spawn.sh` | landed; **caller bug** see §9 |
| `bin/erindi-brief.sh` | `bin/fm-brief.sh` | landed, verified |
| `bin/vor-crew-state.sh` | `bin/fm-crew-state.sh` | landed, verified |
| `bin/rodd-operational-input.sh` | `bin/fm-operational-input.sh` | landed, verified |
| `bin/saga-wake-drain.sh` | `bin/fm-wake-drain.sh` | landed, verified |
| `bin/syn-watch-arm.sh` | `bin/fm-watch-arm.sh` | landed, verified |
| `bin/syn-turnend-guard.sh` | `bin/fm-turnend-guard.sh` | landed, verified |
| `bin/syn-arm-pretool-check.sh` | `bin/fm-arm-pretool-check.sh` | landed, inert v0 |
| `bin/syn-cd-pretool-check.sh` | `bin/fm-cd-pretool-check.sh` | landed, inert v0 |
| `bin/nornir-cron-start.sh`, `bin/nornir-job-*.sh` | none (Ymir extension) | landed, verified |
| `bin/runes-append.sh` | none (Ymir extension) | landed, verified |
| `.pi/extensions/syn-turnend-guard.ts` | `.pi/extensions/fm-primary-turnend-guard.ts` | landed, verified |
| `.pi/extensions/gna-pi-watch.ts` | `.pi/extensions/fm-primary-pi-watch.ts` | landed; calm + supervision branch dropped |
| `.pi/extensions/lib/vordr-sessionstart-supervisor.mjs` | `.pi/extensions/lib/fm-sessionstart-supervisor.mjs` | landed |
| `.pi/extensions/lib/rodd-operational-input.ts` | `.pi/extensions/lib/fm-operational-input.ts` | landed |
| `.opencode/plugins/saga-sessionstart.js` | `.opencode/plugins/fm-primary-sessionstart-nudge.js` | landed |
| `.opencode/plugins/syn-watch-arm.js` | `.opencode/plugins/fm-primary-watch-arm.js` | landed |
| `.opencode/plugins/syn-turnend-guard.js` | `.opencode/plugins/fm-primary-turnend-guard.js` | landed |
| `.opencode/plugins/syn-pretool-check.js`, `syn-cd-check.js` | `.opencode/plugins/fm-primary-pretool-check.js`, `…-cd-check.js` | landed |
| `.claude/settings.json` | `.claude/settings.json` | landed, retargeted |
| `.codex/hooks.json` | `.codex/hooks.json` | landed, retargeted |
| `.cursor/hooks.json` | `.cursor/hooks.json` | landed, retargeted |
| `config/eindri-dispatch.json` | `config/crew-dispatch.json` | landed, retargeted |
| `config/eindri-harness` | `config/eindri-harness` (documented upstream) | landed |
| `config/cron.yaml` | none (Ymir extension) | landed |
| `AGENTS.md` (mandate) | `AGENTS.md:1-12` adopted, voice rewritten | landed |

## 9. Known code/doc disagreements from the port

These are real mismatches between plan/source docs and the shipped tree, found while writing this reference. They are recorded here, not silently fixed, because the port was a documentation pass.

| # | Disagreement | Evidence | Impact |
|---|---|---|---|
| 1 | `bin/einherjar-spawn.sh:170` calls `hamr-harness.sh crew`, but `bin/hamr-harness.sh:231-236` accepts only `eindri`, `eindri-model`, `eindri-effort` (the upstream `crew` subcommand was renamed to `eindri`). `crew` falls through to `detect_own`. | upstream `bin/fm-harness.sh` header documents `crew`; the port renamed it but did not retarget the caller | Latent: masked while `config/eindri-dispatch.json` forces an explicit `--harness`; would mis-resolve the configured Eindri harness if the dispatch file were removed. Fix: call `hamr-harness.sh eindri`. |
| 2 | Plan 29 declares a **9-stage** digest (§1, §6, acceptance §8.3 "all nine stages"); the script header and implementation are **8 stages** (`NETWORK CHECKS` is deferred/not implemented). | `docs/plans/29-brokk-distro-runtime.md:171,207` vs `bin/saga-session-start.sh:9-17` | Doc drift; the runtime is correct at 8. Reconcile the plan or implement the network-checks stage. |
| 3 | Plan 29 §7/§13 names `.opencode/plugins/syn-sessionstart.js`; the shipped file is `.opencode/plugins/saga-sessionstart.js`. | `docs/plans/29-brokk-distro-runtime.md:139,188` vs the tree | Doc drift; the adapter works, the plan's filename is stale. |
| 4 | Plan 29 §13 "Still to build" lists `hamr-harness.sh`, the `.opencode`/Claude/Codex/Cursor adapters, `einherjar-spawn.sh`, `erindi-brief.sh`, `vor-crew-state.sh`, `config/eindri-dispatch.json`, `bin/nornir-job-*.sh`, `runes-append.sh`, real `data/`, `config/cron.yaml`, and the `AGENTS.md` header as unbuilt — all now exist. | `docs/plans/29-brokk-distro-runtime.md:318-322` | Stale status; the tree has advanced past the plan. |
| 5 | `.pi/extensions/README.md` says the `.opencode`/Claude/Codex/Cursor adapters are "not yet wired"; they are wired. | `.pi/extensions/README.md` "Not yet wired" section | Stale doc. |
| 6 | `AGENTS.md:231-244` (`PI / FIRSTMATE INTEGRATION`) still uses `fm-harness`, `fm-spawn`, `Yggdrasil`, and the `Brokk_crew` schema, contradicting the Norse naming law at `AGENTS.md:6` and the port. | root `AGENTS.md` | Imported terminology in the always-loaded contract. Retarget or strike the section. |
| 7 | `.claude/settings.json` passes `--claude` to `bin/syn-turnend-guard.sh`; the guard accepts no arguments and ignores it. | `.claude/settings.json` Stop hook vs `bin/syn-turnend-guard.sh` | Harmless argument mismatch. |
| 8 | `bin/runes-append.sh:101` titles the ledger `# YGGDRASIL Audit Trail` while the subsystem is **Runes**. | `bin/runes-append.sh:101` | Naming inconsistency; changing it must preserve append-only history. |

### §9 resolutions (2026-09-11)

The audit findings were reconciled in the same working session; the table above is kept as
the historical record.

| # | Resolution |
|---|---|
| 1 | **Fixed** — `bin/einherjar-spawn.sh` now calls `hamr-harness.sh eindri`. |
| 2 | **Reconciled** — plan 29 acceptance is now "all eight stages"; the network-checks stage remains deferred, not implemented. |
| 3 | **Fixed** — plan 29 §7/§13 now name `.opencode/plugins/saga-sessionstart.js`. |
| 4 | **Fixed** — plan 29 §13 now reads "Landed"; every listed component exists. |
| 5 | **Fixed** — `.pi/extensions/README.md` now lists all wired adapters. |
| 6 | **Fixed** — `AGENTS.md` §PI PRIMARY BOOT now uses Hamr/Einherjar/Yggdrasil/`rodd`; the imported heading and `Brokk_crew` schema are gone. |
| 7 | **Left as-is** — the `--claude` argument is ignored by the guard and is harmless. |
| 8 | **Fixed** — `bin/runes-append.sh` now titles the ledger `# RUNES Audit Trail`.

## Maintaining this

- **Owner:** Brokk. **Reference:** `/home/zerwiz/Brokk` (read-only). **Plan:** `docs/plans/29-brokk-distro-runtime.md`.
- **When adding a ported file**, add a row to §8 with its upstream origin and verification status.
- **When a §9 disagreement is resolved, remove its row** and note the fix in `data/learnings.md`.
- **Never edit `/home/zerwiz/Brokk`.** It is provenance; Ymir reads it and never writes to it (`AGENTS.md:96`, plan 29 §9 "NOT").
- **Re-run §7 gates** after any change to a ported script, and keep the naming audit (§7.5) clean of new imported terms.
- **Keep the coupling audit (§3) current:** a new upstream mechanism is generic or coupled, and this document must say which before it is copied.
