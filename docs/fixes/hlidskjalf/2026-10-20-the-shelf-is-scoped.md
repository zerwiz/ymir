## hlidskjalf · unversioned · 2026-10-20 — the shelf is scoped

### What

`/api/snotra/meetings` reads **every meeting shelf**, not only project meetings:

- private — `hodd/workspaces/meetings`;
- company/product — `svartalfaheim/<realm>/meetings`;
- project — `svartalfaheim/<realm>/projects/<project>/meetings`;
- store — `hodd/life/meetings/<lane>/<id>`.

Each row now carries `scope` (`private | company | product | project | store`) and the
company/realm as `workspace`. Synteon's record shows `workspace: synteon, scope: company`.

### Why

Synteon is a **company** with four members, not a project of `work`. The record moved to
`svartalfaheim/synteon/`; the registry is `hodd/identity/companies.yaml`, the shelf rules
`hodd/identity/meeting-locations.yaml`. Skrymir had been browsing the wrong shelf and too
shallow; both are corrected in the same branch.

### Verified

- API returns the pilot as `workspace synteon · scope company · 6 decisions`.
- Skrymir returns `projects/…` under `realm=work`; Synteon is browsed under its own realm.

### Not verified

- No scope filter in the page yet; no component test.
