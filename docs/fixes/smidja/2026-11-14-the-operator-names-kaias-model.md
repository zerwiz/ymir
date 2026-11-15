# smidja · 2026-11-14 — the operator names the chat's model

**Component:** smidja · **Branch:** `eindri/smidja-header-chat` (plan 275; the Allfather's word, 2026-11-14)
**Files:** `server/chat.ts`, `server/index.ts`, `src/lib/chat-store.ts`, `server/kaia.test.ts`,
`config/smidja.env.example` (new), `.agents/skills/galdr-ymirsystem/assets/smidja.md`,
`docs/features/smidja-and-volundr.md`, `docs/fixes/smidja/2026-11-14-the-operator-names-kaias-model.md`

## Why

The Allfather's word: *"make the default model in Smíðja for me opencode-go/deepseek-v4.1-flash."*

By the house's agnostic law the repository carries no operator's shape. So the repo keeps its
generic default (`DEFAULT_CHAT_MODEL = opencode-go/deepseek-v4.1-flash` in code) **and** ships the
template for the operator's own value; the value itself lives in the home.

## What changed

**The ladder** — `chatModelDefault(root)`:

| Order | Source | Why |
|---|---|---|
| 1 | `SMIDJA_CHAT_MODEL` in the environment | a unit or a wrapper that knows better |
| 2 | `<home>/config/smidja.env` → `SMIDJA_CHAT_MODEL=…` | **the operator's own choice** |
| 3 | `DEFAULT_CHAT_MODEL` in `server/chat.ts` | the repo's generic default |

`runPi` uses it when the picker sends no model, and `GET /api/chat/default-model` serves it so the
**picker opens with that model already selected** (`init()` in `chat-store.ts` reads it, and only
accepts an id the catalog actually offers).

**The template ships in the repo:** `config/smidja.env.example`, commented and with the one
supported key — a copy-and-edit file, never a value.

**The operator's value is in his home:** `~/Documents/ymirhome/config/smidja.env` with
`SMIDJA_CHAT_MODEL=opencode-go/deepseek-v4.1-flash` (committed there as `7658aa15`; see "Not done").

## Proof

Real window (private Electron, temp `--user-data-dir`, DevTools 9444) over this worktree's `dist`,
the Chat page:

```
GET /api/chat/default-model → {"model":"opencode-go/deepseek-v4.1-flash"}
picker placeholder          "opencode-go/deepseek-v4.1-flash ..."
dropdown opens (452 options), and the option marked active is
                            "deepseek-v4.1-flash  opencode-go"
PASS — the operator's model is the option marked selected
```

Static: `bun run typecheck` 0 · `bun run build` 0 · `bun test` **22 pass, 0 fail** (four new tests:
no config → the repo default; the home's file wins; the environment wins over the file; a blank
line never becomes an empty model id).

## Not done, named

The home commit `7658aa15` is **not pushed**: `bin/vault/home-sync.sh begin` and `ship` both refused
because another hand's `hodd/memory/runes_audit.md` is dirty and overlaps the incoming origin merge.
The value is live on this machine and committed locally; the next `home-sync` that finds a clean
ledger will carry it up. Named in the handoff packet too.

## Closed after testing

The Electron window (temp profile, port 9444), its DevTools session, and the dev server on `:8537`
— all closed, the temp profile removed, and `hyprctl clients` shows no window of mine. The
Allfather's own windows were never touched.

## CHANGE LOG

- 2026-11-14 — `chatModelDefault()` ladder (env → home → repo default), `/api/chat/default-model`,
  the picker opening on the operator's model, the repo template, four tests; the home's value
  written and committed but unpushed (another hand's ledger blocks the merge).
