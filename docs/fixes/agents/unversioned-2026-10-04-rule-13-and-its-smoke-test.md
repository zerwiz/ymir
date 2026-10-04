## harness-integration · unversioned · 2026-10-04 — Rule 13, and a smoke test that proves it

### Why

The layout investigation produced findings but no **law**. Everything it uncovered —
the split source, the stale deploy, the two contradictory descriptions, the collision
that seats nobody — was a *fact someone had to remember*. A rule makes the memory
unnecessary, and a test makes the rule enforceable.

The Allfather asked for both: *"make a rule for how to build and use pi extensions
based from www.pi.dev"*, then *"make a smoke test for this"*, then *"update ymir so
ymir knows about this rule like galdr etc"*.

### Fix

**`RULES/13-pi-extensions.md` is new**, built on pi's own documentation and the
installed loader's rule, with the three facts it rests on stated up front:

1. An extension is a file, or a **directory with an `index.ts`** — *"No recursion
   beyond one level."* A `lib/` with no `index.ts` is therefore never scanned, and
   **that is correct, not a mistake.**
2. Pi loads `~/.pi/agent/extensions/` **and** `.pi/extensions/` and does **not**
   de-duplicate. An extension in both makes pi exit with a tool-name conflict and
   **no agent can be seated.**
3. **A deploy is a copy and nothing re-runs it** — which is how a repo edit and the
   running harness drift apart without anything failing.

The law's nine clauses cover one home, what `.pi/extensions/` may contain, the
directory-with-`index.ts` shape, **why thin loaders can never be built**, taking
`pi` as `any` (the package is not installed, so importing its types cannot load),
starting nothing in the factory, load order as a contract, deploying what you
import, and the gate.

**`.agents/tests/pi-extensions.test.sh` is new** — sixteen checks across nine
groups, following the house `.agents/tests/*.test.sh` TAP convention: the rule
exists and is registered; the three trees are what the rule says; every
project-local file is a no-op; `lib/` has no `index.ts`; **every relative import
resolves where extensions actually run**; the deployed tree matches source; no test
file is live; nothing is in two load paths; the root pointer resolves; the gate
exists; and the asset names no extension at the wrong path.

### The test was wrong twice, and fault injection found both

**A test that only ever passes is worse than no gate** — Rule 13 §9 says so, so the
test was held to it.

- **It checked imports in the wrong tree.** The source extensions say
  `./lib/ro-visibility.ts`, which resolves only in the **deployed** tree — that is
  where pi loads them. The test was asserting about a layout that does not exist at
  runtime. It now checks the deployed tree and reports the sideways `lib/` reach as
  a standing **NOTE**, so the unfinished migration cannot be forgotten.
- **Its stale-root count was broken** (`[: 0\n0: integer expected`).

Faults injected and caught: a stub grown into a real extension · a stale deployed
copy (`8654 vs source 8645`) · a test file leaked into the live tree · an extension
byte-identical in both load paths · the rule file deleted · the rule unregistered.
Two more faults were injected and **did not fire** — a stub grown past a kilobyte
in a file that was never a stub, and a rule line removed from `AGENTS.md` by a `sed`
that matched nothing. Both were bad tests of the test, and the checks were re-run
properly before trusting them.

### Registered, so Ymir knows

| where | |
|---|---|
| `RULES/13-pi-extensions.md` | the law |
| `RULES/README.md` | the rules index |
| `AGENTS.md` — rules table | every session reads it |
| `AGENTS.md` — governed paths | the router sends Pi-extension work to the rule |
| `galdr-ymirsystem/SKILL.md` | the Galdr router names it, next to the Hodd law |
| `assets/harness-integration/README.md` | the adapter reference points at it |
| `assets/harness-integration/pi.md` | the Pi deep dive states it at the top |

### Not done

**The layout is unchanged.** Eighteen imports still reach sideways into `lib/`. Rule
13 §3 says those modules belong inside their own extension's folder, and the test
says so on every run. That move is steps 3–5 of
`~/Documents/ymirhome/hodd/docs/developer-setup/2026-10-01-pi-extension-system-layout.md`
— a separate change on `fix/pi-extension-restructure`, because it touches what pi
loads at seat time.

### Verified

```
$ bash .agents/tests/pi-extensions.test.sh
ok - Rule 13 exists
ok - Rule 13 is registered in RULES/README.md
ok - Rule 13 is reachable from the always-loaded contract (AGENTS.md)
ok - every .pi/extensions/*.ts is a no-op factory
ok - lib/ has no index.ts — pi will never scan it as an extension
ok - every relative import resolves where extensions run (extensions)
ok - deployed extensions are byte-identical to source
ok - no test files in the deployed tree
ok - no extension is present in two load paths
ok - the first VALID root in .ymir-root resolves (/home/heimdall/ymir)
ok - valknut-load.sh carries --check (Rule 13 §9)
# pi-extensions: all checks pass                       exit 0
```
