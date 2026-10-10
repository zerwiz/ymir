## extensions · unversioned · 2026-10-10 — global reach, still one home: the extensions load in every pi session

### Why

**Fix:** Ymir's extensions loaded **only** when a pi session's cwd sat inside the repo. A session
working in another checkout (`~/CodeP/excalidraw`) got none of them — including the new
`excalidraw` door, which exists precisely to be used from there. A project tree is discovered by
cwd and by nothing else.

**Now:** `bin/seat/valknut-load.sh --pi` also writes this checkout's `.pi/extensions` into
`~/.pi/agent/settings.json`'s `extensions` array. Idempotent; every other entry is kept (a flag
such as `-builtin:mcp` is untouched); a path pointing at some *other* checkout's extensions tree
is pruned. A dated backup (`.bak-ymir`) is written before the first change.

**Why it is not a second home, and cannot double-register.** Pi's discovery has **three** sources
— `<cwd>/.pi/extensions`, `~/.pi/agent/extensions`, and the user settings `extensions[]` — and
`discoverAndLoadExtensions` de-duplicates with `const seen = new Set()` keyed on
`path.resolve(p)`. Sources 1 and 3 produce **absolute paths to the same files**
(`discoverExtensionsInDir` returns `path.join(dir, name)`), so the second is skipped. A **copy**
would double-register, and a **symlink** would too: the Set is keyed on the resolved path, never
on `realpathSync` — which is the whole reason the mechanism is a named path.

The gate grew the assertion: `--check` now fails when the settings do not name this checkout, and
it was **proved by breaking it** — the assertion reported FAIL before the loader ran.

### Verified

- **Pi's own loader, called directly** with the real `~/.pi/agent/settings.json`, from three cwds:

  | cwd | extensions loaded | duplicates | `excalidraw/index.ts` present |
  |---|---|---|---|
  | `~/CodeP/excalidraw` | 20 | **0** | yes |
  | `~/ymir` | 20 | **0** | yes |
  | `/tmp` | 20 | **0** | yes |

- `settings.json` after the run keeps `-builtin:mcp` and gains
  `$HOME/ymir/.pi/extensions`.
- `bin/seat/valknut-load.sh --check` → the new line `pi settings name the extensions tree PASS`,
  overall **PASS**. Before the loader ran it reported **FAIL** — the gate is not one that only
  ever passes.
- No wiring change was needed: `bin/engine/ymir-install.sh` already runs the loader bare (which
  defaults to `--opencode --pi`) and `--install`; `bin/agents/groa-update.sh` runs `--all
  --global`. Both therefore reach the `--pi` block, so **installs and updates both apply this**.
- `bash -n bin/seat/valknut-load.sh` → syntax OK.

### Files

- `bin/seat/valknut-load.sh` — `pi_settings_extension_root()` and
  `pi_settings_extension_root_present()`; the `--pi` call site; the `--check` assertion
- `RULES/13-pi-extensions.md` — appended correction (append-only); its §"global home holds no
  extension" still holds — nothing is *stored* there, the one home is merely *named*
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` — dated note beside the
  paragraph that said pi reads only the global home
- `~/.pi/agent/settings.json` — machine-local; gains the extensions path (not tracked)

### Known cosmetic

A path-like entry such as `-builtin:mcp` is passed through untouched to pi's resource resolver by
the loader, which reports it as an unloadable path when called directly. The pi CLI resolves
`builtin:` itself; it is a probe artefact, not a defect, and is left alone.

### Pre-existing failure found, NOT caused by this change

`compliance-check.sh` reports `hoard · the hoard boundary (Rule 04) · FAIL — private-guard:` with an
empty detail. The cause is a **stale path**: the check calls `bin/private-guard.sh`, but the guard
lives at `bin/gates/guards/private-guard.sh`. Verified pre-existing — with this change stashed, the
same row fails identically on the committed HEAD. Left alone deliberately: it belongs to the
compliance component, not this one, and a change there needs its own proof.
