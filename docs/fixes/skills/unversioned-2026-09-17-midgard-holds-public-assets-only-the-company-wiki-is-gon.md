## skills · unversioned · 2026-09-17 — midgard holds public assets only; the company wiki is gone

### Why
- **`midgard/company_wiki/` did not belong in this repo.** It was an empty
  placeholder (one `.gitkeep`), but a company wiki is *tenant data* — policies,
  vision, specs, client names — and this repo is public. Removed, with every
  reference to it corrected in `midgard/README.md`, `STRUCTURE.md`, `docs/lore.md`
  and `assets/Ymir.md`.
- **`midgard/` is now described precisely.** It was called "shared company
  assets" in one place and "cross-tenant" in another; a wiki is neither. The
  contract says **public assets**, and `midgard/README.md` names what does *not*
  belong: company knowledge, which lives at `$YMIR_HOME/hodd/identity/companies/`.
- **`bin/private-guard.sh` gains a tenant-document rule** so the shape cannot
  return: a `company_wiki/`, `wiki/`, `policies/`, `handbook/` or `vision`/
  `strategy`/`roadmap` document staged in the public tree is refused, with a
  message naming where it belongs. Verified by planting `midgard/company_wiki/policies.md`.
- **Nothing had leaked.** A full sweep of every tracked midgard file for personal
  handles, home paths, key shapes, tunnel UUIDs and LAN/tailnet addresses found
  no hits — the ingress configs use `${VARS}` and `example.org` throughout, and
  the DB schema is generic with row-level security on every tenant table.

### Files
- *(carried from the frozen CHANGELOG.md)*
