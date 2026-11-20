## docs · unversioned · 2026-10-11 — the user's front door: `FEATURES.md` + `docs/features/` (Rule 14)

### What

The Allfather's ask: *almost no feature is explained for the users of Ymir.* This
adds the two records that fix that, and a new rule that keeps them alive:

- **`FEATURES.md`** (repo root) — the **master, append-only catalogue** of every
  feature and function Ymir has: *area · feature · what it gives you · how-to link*.
- **`docs/features/`** — one plain-language how-to per user-facing feature. First
  page: [`unlock-the-vault-with-your-phone.md`](../../features/unlock-the-vault-with-your-phone.md).
- **`RULES/14-features.md`** — the law: a user-facing feature has a page, the same
  change adds/updates both, `FEATURES.md` is append-only, README links them,
  AGENTS.md carries the duty.
- **`README.md`** — a "Features — how to use Ymir" section linking both.
- **`AGENTS.md`** — a "Feature how-tos" section: the duty, in the always-loaded contract.
- **`bin/gates/guards/features-guard.sh`** — a new ward (seated in `guards.sh`), so the
  claim is enforced: every `docs/features/*.md` must be named in `FEATURES.md`.

### Verified

- `guards.sh` → runtime · defaults · cron · **features** all **PASS**.
- `features-guard check` → `"none"` (the phone page is catalogued).
- `bash -n` clean; TOON blocks parse.

### Files

- `FEATURES.md` (new)
- `docs/features/README.md`, `docs/features/unlock-the-vault-with-your-phone.md` (new)
- `RULES/14-features.md` (new), `RULES/README.md`
- `README.md`, `AGENTS.md`
- `bin/gates/guards/features-guard.sh` (new), `bin/gates/guards.sh`
