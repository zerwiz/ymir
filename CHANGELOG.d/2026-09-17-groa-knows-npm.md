## 2026-09-17 — Gróa knows the npm half: how to renew the published packages

- **Her skill gains the whole procedure** — choose the number from the registry (never from memory: it can be ahead of main), land the bump by PR, publish through the vault, verify by the *version document* (the packument lags), and move the four apps pins in the same release.
- **And the traps, each of which cost a night:** a stale cached `latest` makes `npm i -g` a silent no-op that still prints success; npm gates Electron s postinstall so windows need `npm rebuild electron`; and a package must declare its own `name`/`files`/privacy where it lives rather than having a manifest rewritten at publish time.
- The token lives in the encrypted vault; when a tool reports it absent, the DOOR is broken, not the key — and `age -d -i hodd/secrets/age.key hodd/secrets/platform.env.age` opens it while `bin/hodd.sh emit` does not.
