## skills · unversioned · 2026-09-25 — federation is the engine's gap, measured

### Why
The ratatoskr skill said "`cert` (ed25519) before federation", as if a cert
opened the wire. The Allfather asked to set the mesh up fully; before touching
federation, the engine's surface was measured — and it has no wire to open.

- **a2abridge 3.0.0 offers `cert generate` and nothing else.** No trust store, no
  peer list, no key exchange. `a2abridge bridge` carries no TLS/trust/peer flag
  (only `-advertise-host · -directory · -id · -name · -skills · -model
  · -state-dir`), and the directory has no federation endpoint.
- **So a cert today writes two files nothing consumes.** The skill now says this
  plainly instead of implying certs are sufficient: cross-machine discovery is
  **per-seat** (each bridge registers with its own local directory), and a peer
  on another seat is invisible unless `A2A_DIRECTORY` points at a shared,
  reachable directory.
- **Where federation lands:** the native Ratatoskr backbone (plan 25) or a newer
  engine release — never a Ymir wrapper over `cert generate`.

galdr-reread: `ratatoskr-a2a` (the federation section).

### Files
- `.agents/skills/ratatoskr-a2a/SKILL.md`
