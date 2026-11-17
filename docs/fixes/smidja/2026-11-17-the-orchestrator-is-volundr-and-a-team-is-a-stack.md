## smidja · unversioned · 2026-11-17 — the orchestrator is Völundr, a team is a stack, and a control you can see

### Why

Four faults, all found by the Allfather using the board rather than by a test.

**The `look` buttons did nothing.** They called `herdr agent focus`, which moves
herdr's own focus — invisible from the Smíðja window, so the POST returned
`{"ok":true}` and the screen did not change. A control whose effect cannot be seen is
a broken control.

**The orchestrator wore the wrong name and was not answering.** The chat's pi ran with
the house contract in front of it, so every reply began *"I am Hœnir, your
counsellor"*; and its model was a hardcoded `opencode-go/deepseek-v4-flash`, which the
catalog does not carry — so the provider answered `400` and the window said *"offline"*.

**A team could not be chosen.** The books say a team is a `stacks:` block in
`smidja/smidja_smidja_config/roster.yaml`; the engine had no reader for it, and the
picker looked in a different directory (`smidja/smidja_config/`), so a project that
followed the books got an empty Team dropdown.

### The mends

| mend | where |
|---|---|
| `look` **reads the pane into the board** — a live drawer with the agent's own words, its state and its tree; `raise` still moves herdr's focus and says so | `src/components/PaneDrawer.vue` (new), `src/lib/pane-drawer.ts` (new), `GET /api/herdr/pane` |
| a working agent's scrollback cannot be captured, so the read falls back to the visible screen and **names which it showed** | `server/herdr-api.ts`, `agent_herdr.read_pane` |
| the chat is **Völundr**: its prompt REPLACES pi's default and `-nc` turns the house context files off | `server/chat.ts` (`kaiaPromptArgs`), `templates/prompt_engineering/orchestrator/{system,user}.md` |
| the chat's model comes from **the machine's own resolver**, and a model the catalog does not list is refused by name before pi is spawned | `server/chat.ts` (`defaultChatModel`, catalog check) |
| the tree a run works in is **never derived from a database alone**: `SMIDJA_REPO_ROOT`, then a tree that actually holds the smithy, then the db's neighbours | `server/db.ts` (`repoRootOf`) |
| a **team is a `stacks:` block**, resolved in memory into the same config every chain reads — `SMIDJA_STACK=<name>`, no second file written | `smidja_modules/roster.py` (new), `agents.load_config` |
| the picker looks where the books put the roster | `server/roster_resolve.py` (`find_roster`) |
| the board names the orchestrator **Völundr** everywhere it is read | `ChatView`, `ChatThread`, `SettingsView`, `MemoryView`, `chat-store` |

### Proof

- **the drawer**: clicking `look` on `wN:p3` rendered `factory-herdr · wN:p3 · WORKING · the screen`
  with 2,501 characters of that pane's live output, in the Electron window through DevTools.
- **the chat**: `POST /api/chat/message` → *"I'm Völundr, the orchestrator seat of this window — a
  coordinator that doesn't do the work itself but dispatches sub-agents…"*.
- **a team as a stack**: `smidja doctor` on `roster.yaml` with `SMIDJA_STACK=plan-build-review` →
  `green — this roster would run`, three agents on `herdr`; then a real run —
  `4/4 phases passed`, panes closed — and the run's page shows `THE TEAM · 2 AGENTS · herdr×2`.
- **the picker**: `GET /api/rosters` on that project returns both stacks
  (`plan-build-review — 3 agents · cloud`, `plan-build-review-headless — 3 agents · cloud`).

### Not in this change

The stored chat message still carries `role: "kaia"` in its JSONL — that is data written by earlier
runs, and the board renders the display name from the orchestrator's own name, not from the literal.
Renaming the field would rewrite history to fix a label.
