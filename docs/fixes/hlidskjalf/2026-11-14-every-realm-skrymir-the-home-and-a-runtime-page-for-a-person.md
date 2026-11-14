# hlidskjalf · 2026-11-14 — every realm shown, Skrymir shows the home, OmniChat puts the thread first, and the Runtime page is drawn for a person

**Component:** hlidskjalf · **Branch:** `eindri/hall-follow` (plan 275, items 11 follow-up, 21, 24, 25, 27)
**Files:** `apps/hlidskjalf/server/index.ts`, `server/digest.ts` (new),
`src/data/realms.ts`, `src/components/RealmScope.tsx` (new), `src/gates/Files.tsx`,
`src/gates/Forge.tsx`, `src/gates/OmniChat.tsx`, `src/gates/Runtime.tsx`,
`src/gates/Profile.tsx`, `src/services/api.ts`, `src/state/store.ts`,
`src/types.ts`, `src/styles/components.css`, `src/styles/mobile.css`,
`bin/engine/release.sh`, `bin/engine/release-services.sh` (new)

## Why

Five rows of plan 275 §2026-11-14, all measured there on 2026-11-14 03:30–03:55:

- **Item 11's follow-up.** `one-hlidskjalf` (commit `87278472`) pinned the active realm to
  `work`. That removed the *mode* — which was right — but it also made the Personal and Svein
  shelves invisible, and the rule is **never remove a feature**. `realm` is read in 183 places
  to scope search, fleet and data.
- **Item 21.** `/api/files` called `files(realm)` with `realm` defaulting to `work`, and
  `workspaceRoot()` returned `$YMIR_HOME/svartalfaheim/<realm>`: the browser showed one realm's
  tree (8 files under `work`), never the home.
- **Item 24.** `components.css:889` laid the chat out as three columns and moved the third
  *beneath* the thread under 1040 px, so the Model panel, the 35-name lanes list and the quick
  orders sat between the operator and the conversation.
- **Item 25.** `/api/runtime` (`index.ts:1123`) printed Sága's digest raw: TOON tables, a
  `liveness[163]` table of which ~155 rows are errands finished days ago. RULES/52 says a
  person never reads TOON.
- **Item 27.** The SPA (`:3888`) and the gate (`:3889`) ran release `e713188ca4e2` eight hours
  after the pin moved: a flip moves one link and never restarts what was raised from it.

## What changed

**Every realm is shown (item 11).** `WORKSPACES` in `realms.ts` is the registry's three realms
again — Work · Personal · Svein — with `DEFAULT_REALM` demoted to *the scope a realm-scoped
page opens on*, not a mode. `RealmScope` (new) is a small segmented filter rendered **inside**
the pages whose work a realm actually scopes: the Forge (a new card is forged into a realm) and
the OmniChat drawer (where Kaia dispatches). `baseGrants()` in `services/auth.ts` lists all
three, so Profile's workspace list is whole. Skrymir shows the realms as what they are now:
folders.

**Skrymir is the whole home (item 21).** `/api/files?path=` returns **one directory level** and
`/api/file?path=` reads one file; both resolve against `ymir_home_root()` and refuse a path that
escapes it. `hodd/secrets`, the vault folder (`vault/`), the vault's mount (`YMIR_VAULT_MNT`,
default `~/Vault`) and `.git` are never listed and never read — a hidden folder answers
`not shown: the vault and the secrets are never listed`, never a silent empty tree. The old
`?realm=` parameter still works and means the realm's folder, so an old client lands somewhere
true. The Files page lazy-loads: a folder's children are fetched when it is opened, so the home
is never walked to paint a tree.

**OmniChat: the thread first, one drawer (item 24).** `.chat-layout` is one column; the thread
is first in the DOM, fills the height at every width, and everything secondary — the chats
list, the Model panel, the Eindri lanes and the Quick orders — lives in **one** drawer that is
closed until it is asked for (`Drawer` button, `aria-expanded`). Nothing was removed: it was
folded. The lanes now name only **live** agents (those with a herdr pane), by name and by the
**errand** in the pane's own title, with their state as the tooltip.

**The Runtime page is drawn for a person (item 25).** `server/digest.ts` (new) reads the digest
into `DigestView`: the helm in one line (seat, machine, role, pin, pid, heartbeat), what needs
the Allfather (open decisions, new wakes, letters that ask for him — the mail desk's own count —
open todos with due dates), the errands that are **alive** by name/pane/last line, the finished
ones folded into a count, and the sections the digest carries. The raw text stays whole behind
a `show the raw text` fold. The page never invents a number: an unparsed shape says so
(`parsed: false`) and still shows the raw text. `/api/runtime` is memoised for 60 s — it runs a
700-line bash digest and shells `systemctl`.

**A flip restarts the services that run from a release (item 27).** `bin/engine/release-services.sh`
(new) is the one door: it takes the long-running services from the one register
(`.agents/config/units.yaml` → `bin/engine/units.sh list --restart`), and reads **which release
each is actually running from** from the process's own resolved cwd (the kernel's record, not
today's symlink), falling back to a start-time comparison against the release's build stamp when
a service has no path in the release. `release.sh flip` now calls it after the link moves (and
*before* pruning, so an old release a desktop window still runs from is kept); `--no-restart`
and `YMIR_RELEASE_RESTART=off` hold it, and `release.sh restart` runs it alone. Desktop windows
are deliberately never restarted: an open window keeps the release it started from.

**A stale mail port, fixed in passing.** The gate asked the mail desk at `:8490` while the desk
listens on `:8494` (the register retires 8490), so every mail surface read *"the desk did not
answer"*. The gate's default now follows `GNA_DESK_PORT` (8494).

## How it was proved

The gate API was run from this worktree on a private port and asked directly:

```
GET /api/files                        → the home's root, one level, folders marked lazy
GET /api/files?path=hodd              → 30 entries, `secrets` absent
GET /api/files?path=hodd/secrets      → error "not shown: the vault and the secrets are never listed"
GET /api/file?path=hodd/secrets/platform.env.age → refused
GET /api/file?path=../../../etc/passwd           → refused
GET /api/files?realm=work             → svartalfaheim/work (back-compat)
GET /api/runtime                      → view.helm {seat <a seat>, machine host-a, role dev, pin <a sha>},
                                        errands 3 alive, 156 finished, 4 unreadable panes,
                                        services.pin 7ae529759d0b with 14 rows,
                                        mail {needs 14, accounts [the operator's own address]}
```

`bin/engine/release-services.sh status` (this seat): `hlidskjalf-gate` and `hlidskjalf-spa` and
`smidja` report `released e713188ca4e2, on_pin 0` — which is exactly item 27's measurement, now
visible on the page. `restart --dry-run` names what a flip would restart.

## Not done, named

- **The raw digest is not changed.** Item 28 (`digest-head`, another errand) owns
  `bin/time/saga-session-start.sh`; this page parses whatever shape that script emits and
  degrades to the raw text when it cannot.
- **`/api/desktop`** (the launcher door the key bindings and the shell scripts use) is kept; it
  is a launcher, not a login.
- **`bin/engine/release-services.sh` proves itself only after a build**: the *current* release
  (`7ae529759d0b`) does not carry it yet, so `release.sh restart` answers
  `skipped — no bin/engine/release-services.sh in <release>` until the next release is built
  and flipped.

## CHANGE LOG

- 2026-11-14 — realms restored as a filter and as folders; Skrymir on the whole home, lazily;
  OmniChat's thread first with one drawer; the Runtime page drawn for a person, with each
  service's release and a flip that restarts them.
