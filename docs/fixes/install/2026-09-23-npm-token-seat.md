## install · unversioned · 2026-09-23 — the npm publish's key seater

### Why
The publish resolves NPM_TOKEN from the vault; the vault held an EMPTY shell.
The Allfather's token must never touch a transcript or a file — stdin only.

### What
`bin/npm-token-seat.sh` — reads the token from stdin, decrypted the vault in
memory, sets NPM_TOKEN, re-encrypts with age. Then `bin/npm-publish.sh`
publishes 0.1.40 (fleet mode = a documented setup option).

### Files
- `bin/npm-token-seat.sh`
