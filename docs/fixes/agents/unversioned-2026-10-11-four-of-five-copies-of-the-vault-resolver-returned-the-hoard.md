## agents · unversioned · 2026-10-11 — four of five copies of the vault resolver returned the hoard, not its parent

**Cites:** `.pi/extensions/ymirhome.ts:8` — the one copy that learned this on
2026-10-08, and wrote the lesson in its own comment.

### Why

`bin/vault/hodd.sh path` answers the **hoard** (`$YMIR_HOME/hodd`). But the shelf
strings every door in these files builds are home-relative *with* the `hodd/`
prefix — `<home>/hodd/memory/daily/<day>.md`, `<home>/hodd/memory/runes_audit.md`,
`<home>/hodd` — so the base must be the hoard's **parent**, the operator's home.

Five extensions each carry their own private copy of that resolver. One
(`ymirhome.ts`) returns `dirname(v)`. The other four returned `v` — the hoard
itself — and every path they built therefore doubled the prefix.

Measured, 2026-10-11, twice in one session:

- `ymir_daily` (elder.ts) wrote the day's line to
  `hodd/hodd/memory/daily/2026-10-10.md` — outside every legal shelf, and the
  day's real file silently went without it.
- `ymir_push` (elder.ts) ran git with the hoard as its working directory and the
  path `hodd/memory/daily/…`, so a push **by name** matched no file and failed.
- `ymir_plan` would have seated plans at `hodd/svartalfaheim/…`,
  `gna-pi-watch` would have seated the state dir at `hodd/state`, and
  `skuld-branch-supervision` would have read the plan ledger from
  `hodd/svartalfaheim/…`.

A misdirected write is worse than a failed one: `ymir_daily` reported success and
wrote to a path no shelf owns.

### What

All four now `return dirname(v)`, each carrying the lesson and citing
`ymirhome.ts:8`:

- `.pi/extensions/elder.ts` — `ymir_daily`, `ymir_push`, `ymir_note`, `ymir_plan`,
  `ymir_header`, `ymir_find_home`
- `.pi/extensions/odrerir.ts` — the runes ledger path
- `.pi/extensions/gna-pi-watch.ts` — `${ymirHome}/state`
- `.pi/extensions/skuld-branch-supervision/index.ts` — the plan-ledger reads

### Verified

Resolved live against this seat, reading the real home:

```
hoard      : /home/<user>/Documents/ymirhome/hodd
home (new) : /home/<user>/Documents/ymirhome
OLD daily  : …/hodd/hodd/memory/daily/2026-10-10.md   missing
NEW daily  : …/hodd/memory/daily/2026-10-10.md        EXISTS
NEW plans  : …/svartalfaheim/whynotproductions/projects/ymir/plans   EXISTS
NEW state  : …/state                                  EXISTS
```

The OLD base resolves to a path that does not exist — which is precisely where
the day's line was written. The NEW base resolves to the real file, the real plan
ledger and the real state dir.

Also: `ext-api` and `ext-smoke` in `bin/gates/ci-verify.sh` — every Ymir tool must
still answer when called the way Pi calls it, which is the only syntax proof that
matters for an extension whose language is TypeScript.

### Owed, not done here

**Five private copies of one resolver is five chances to drift** — and this note
exists because four drifted. The remedy is ONE resolver in
`.pi/extensions/lib/ymir-home.ts` which all five import. Left owed rather than
half-done: the extensions must stay loadable on every harness, and a shared
import is a change in what the deploy carries.

Ticket: ymir/40.

### Files

- `.pi/extensions/elder.ts`
- `.pi/extensions/odrerir.ts`
- `.pi/extensions/gna-pi-watch.ts`
- `.pi/extensions/skuld-branch-supervision/index.ts`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md` — dated note
