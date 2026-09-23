## runtime · unversioned · 2026-09-23 — the smoke test checks the layout map

### Why
- **Problem:** the hoard check only caught flat dirs beside `hodd/`; a
  `.ymir-layout.yaml` naming another machine's home (`/home/zerwizomar/...`)
  passed silently while Eir's placement ward failed.
- **Fix:** the `hoard` check now also validates that every path in
  `.ymir-layout.yaml` EXISTS on this machine, and fails naming the foreign ones.
  This is the same class as the lock pointer: a machine-local map carried in the
  synced home.

### Files
- `.agents/skills/lifecycle/smoke_test.sh`
