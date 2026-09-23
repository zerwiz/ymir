## runtime · unversioned · 2026-09-23 — the smoke test validates the layout map

### Why
- **Problem:** the hoard check only caught flat dirs beside `hodd/`. A
  `.ymir-layout.yaml` naming **another machine's home** (`/home/zerwizomar/...`)
  passed the smoke test silently while Eir's placement ward failed. The check was
  written earlier but merged into a branch that landed before it — so it never
  reached `main`.
- **Fix:** the `hoard` check now also validates that **every path in
  `.ymir-layout.yaml` EXISTS on this machine**, and fails naming the foreign ones.
  This is the same class as the lock pointer: a **machine-local** map carried in
  the **synced** home. On this box the map has been repointed to
  `/home/heimdall/Documents/ymirhome`, so the check now passes.

### Verified
- `smoke_test.sh` on this box: `"hoard","OK","layout honest; map paths exist"`;
  overall **exit 0**, no FAILs.
- A map naming an absent path produces
  `bad hoard "layout map names paths absent here:… — repoint to this machine's home"`.

### Files
- `.agents/skills/lifecycle/smoke_test.sh`
