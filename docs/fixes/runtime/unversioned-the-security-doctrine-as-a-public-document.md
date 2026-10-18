## runtime · unversioned · 2026-10-18 — the security doctrine as a public document; the dead editor helper removed

### Why

The ward was built (Rule 24, `bin/ward/`, plan 81) but had **no public document**: a
reader of the repo could find the law and the scripts, and no single place that explained
the threat model, the surfaces, the local-network checks, or the roadmap. The security
doctrine existed as a private plan and as code.

Separately, `bin/engine/ymir-edit.sh` carried `move_window_to()` — a leftover from the
`apps/` refactor (`a72ba5f6`). The script calls `window_to_desktop` from
`bin/desktop/display-lib.sh`; `move_window_to` was defined and reachable from nothing, so
`dead-code-guard` failed on `main` (Rule 17).

### Now

- **`docs/security.md`** (new, public) — the ward's doctrine: the seven laws, a seven-surface
  threat model (doors · the wall · the lock · tunnels · secrets · the watch · **the road**),
  what ships today, how to run it, the **local-network and router checks** (lying routes,
  rogue DHCP, ARP spoofing, plaintext DNS, UPnP/WPS, unmanaged hops, LAN sweep, wireless
  posture), the watchers to adopt, the five loops, the S0–S8 roadmap, and what the ward
  will never do. It carries doctrine and mechanism only — **no machine's measurements**,
  which stay in the vault (Rule 04).
- **`README.md`** — a *Security — the ward* section with the three commands, and the
  document added to the Docs index.
- **`bin/engine/ymir-edit.sh`** — the dead `move_window_to()` deleted (RULES/17).

### Also mended — pre-existing red on `main`

- **`AGENTS.md`** — the `rules[...]` TOON block declared `rules[9]` while carrying **ten** rows
  (Rules 01, 02, 03, 05, 06, 07, 13, 20, 23, 24), so `compliance-check.sh`'s TOON gate failed
  on `main` for any branch. The header now declares `rules[10]`.

### Verified

- `bin/gates/guards.sh` → **9 wards PASS** (was `dead-code-guard` FAIL on `main` before this).
- `bin/gates/guards/dead-code-guard.sh check` → `307 scanned, 0 findings`.
- `bash -n bin/engine/ymir-edit.sh` → clean.
- `bin/gates/ci-verify.sh` → see the run.

### Files

- `docs/security.md` (new)
- `README.md`
- `bin/engine/ymir-edit.sh`
- `AGENTS.md`
- `bin/README.md`, `.agents/assets/agents/capabilities.md` (regenerated)
