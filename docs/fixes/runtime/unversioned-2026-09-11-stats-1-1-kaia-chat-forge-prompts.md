## runtime · unversioned · 2026-09-11 — Stats 1:1, Kaia chat, Forge prompts

### Why
- **Stats:** ported the full Smiðja `StatsResponse` 1:1 into the gate API and
  the Stats gate — runs/success/fail/running/rate, token optimization
  (input/output/cache_read/cache_write, cache-hit ratio, avg CHR/run),
  local-vs-online provider split with per-model table, 40-model commercial
  catalog (cached/total/savings/%), by-chain and by-workflow. A real run
  renders live.
- **Chat (Kaia):** per-session JSONL store (`state/chat/`), list/history/delete
  endpoints, a rolling **40-message** window, query-grounded well recall before
  every dispatch, an animated "Kaia is thinking…" indicator, a session sidebar
  (new/switch/delete), a connected-model datalist (314 models) with free-type,
  and Eindri lane toggles.
- **Forge:** a Prompts mode to read/edit the smithy's
  `prompt_engineering/<agent>/{system,user}.md` (path-guarded save) and a
  connected-model datalist for agent models.
- **Verified:** `tsc` + `vite build` green, live chat via local model with
  recall on, prompt roundtrip + traversal guard, compliance 8/8, smoke 8/8,
  lint 4/4.

### Files
- *(carried from the frozen CHANGELOG.md)*
