## agents · unversioned · 2026-10-01 — Constellation: the mesh discovers peers and refuses to call them

### Why

An install of Ymir had no way to know that other installs of Ymir exist. The mesh
was a claim, not a surface: `packages/contracts/src/agent-card.ts` defined the card,
`packages/a2a/ratatoskr` served one, and nothing on any seat could READ one. So
discovery — the cheapest, safest half of a federation — was simply absent.

The tempting half-built version reads a registry and fires JSON-RPC at whatever
address it finds. That is not a mesh, it is a door with no key in it: a card is
untrusted input from a stranger, and calling it without a grant means any peer can
make this seat spend tokens and open its memory. The grant vocabulary is `skills[]`
plus a short-lived, skill-scoped JWT, and phase 61.2 (Forgejo identity + the minting
door) has not landed. So the honest deliverable is **discovery plus a refusal that
names what is missing** — and the refusal is provable.

### The fix

1. **`.pi/shared/extensions/constellation.ts`** — a Pi extension that makes a Ymir
   install a node of the mesh. Three tools, exactly: `constellation_list`,
   `constellation_ask <peer> <skill>`, `constellation_card <peer>`.
2. **`.pi/extensions/lib/constellation-registry.ts`** — discovery, validation,
   rendering, and the refusal. Configured by `CONSTELLATION_REGISTRY` (a git URL or
   a local path of the registry repo) and `CONSTELLATION_CACHE` (the cache dir for a
   pulled copy). Resolution order: an explicit local path, else `git clone --depth 1`
   into the cache, else a SKIP carrying the reason.
3. **`.pi/extensions/lib/constellation-contract.ts`** — the ONE agent-card contract,
   imported, never copied. Types come from the shared module; the VALUES are located
   at runtime through the root `bin/valknut-load.sh` recorded in `.ymir-root`,
   because the deployed copy lives in `~/.pi/agent/extensions/` and has no `packages/`
   under it — a relative import there is a deploy that cannot load.
4. **`.pi/extensions/constellation.ts`** — the no-op shim, so a project-local pi
   session does not register the same tools twice (pi refuses the duplicate).

### The four laws it keeps

- **Unknown is not empty.** No registry configured ⇒ a loud SKIP naming
  `CONSTELLATION_REGISTRY`, never "0 peers found, all clear". The two look identical
  downstream and only one of them is the truth.
- **A card is metadata.** Read, validated, printed — never written anywhere but the
  cache. A card carrying something that looks like a secret is REFUSED with the field
  named (a bare `security: [{apiKey: []}]` is a reference to a scheme, not a
  credential, and still validates). An endpoint is printed with any userinfo redacted.
- **No call without a grant.** `constellation_ask` refuses, names the missing grant
  (`skills[]` — a Forgejo identity plus a short-lived skill-scoped JWT, phase 61.2),
  points at the skill the card declares, and sends nothing. A peer that does not
  exist, or a skill the card does not declare, is refused for its own named reason.
- **Read-only.** Nothing here writes to a peer, opens a socket to one, or invents a
  transport. There is no fake call to fail a test against.

### Proved

- `node --check` clean on all six files (via `stripTypeScriptTypes`, then `--check` —
  node's `--check` does not strip types itself).
- `node --test .pi/extensions/lib/constellation-registry.test.ts .pi/extensions/lib/constellation-load.test.ts`
  — 11 tests, 11 pass: a sound card parses; a card missing `skills` is reported
  invalid with the field `skills` named; `constellation_ask` refuses with the
  missing-grant reason; no registry ⇒ SKIP, not an empty list; a cache dir inside the
  tree ⇒ SKIP; a shallow clone lands outside the tree; an endpoint's credentials are
  redacted.
- The deployed shape loads: the test reproduces `bin/valknut-load.sh`'s deploy into a
  scratch home (shared `*.ts` + `lib/*` + `.ymir-root`), drives the factory with a
  stub `pi`, and reads back exactly `constellation_list`, `constellation_ask`,
  `constellation_card` plus the load marker `state/.pi-constellation-loaded` — the
  same shape `gna-pi-watch` proves itself with. The project-local file registers
  nothing.
- `bash bin/guards.sh` — runtime-guard PASS, defaults-guard PASS.
- `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` — 16 checks, all
  PASS/NOTE.

### What was NOT built, and why

The grant verifier, the minting door, any write to a peer, and any public door. Those
are phases 61.2 and 61.4, and they are the Allfather's to unseal. Until a grant
exists, `constellation_ask` refuses — correctly, loudly, and provably.
