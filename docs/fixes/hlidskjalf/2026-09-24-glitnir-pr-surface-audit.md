# hlidskjalf · 2026-09-24 — Glitnir: the audit of every PR surface

## Why
The Allfather asked why real GitHub statuses never appear on the board. The
audit found the mechanisms half-there and the meaning impossible: **at the
moment of the screenshots there genuinely were zero open PRs** (#176, #185,
#186 were either merged or not yet born) — but the surface could never have
shown real status even when PRs stood open, for four code reasons:

1. **`approved` was structurally unreachable.** `reviews()` fetched only
   `statusCheckRollup`; no review state was ever read, so the "Approved · ready
   to merge" tile could only ever be 0, and the seal path could never light.
2. **The synthetic lint card inflated "Open PRs".** `Open PRs = reviews.length`
   counted the Brokk lint + compliance gate card (`number: 0`) as a PR.
3. **Every gh failure was swallowed silently** by `catch {}` — a dead token,
   a missing repo context, an offline seat each painted a bare blank board with
   no word of why, and a packaged install (no `.git`) could never detect the
   repo at all (gh found no remote context).
4. **The board never refreshed** — cards were read once per page load (60s
   server memo), so a PR opening while the board sat open never appeared until
   a reload, and the stream's "reviews" bucket only ever saw runes emitted
   while the page was open.

## What
- `reviews()` now requests `reviewDecision,mergeable` per open PR and maps the
  state: draft → `open`; CI failing → `changes`; GitHub `APPROVED` + green →
  `approved`; else `open`. The repo is passed explicitly (`--repo` from the
  origin remote, default `zerwiz/ymir`) so a packaged install still reads PRs.
  The response is now `{ cards, ghError }` — a failing gh read is REPORTED,
  never silenced.
- `Reviews.tsx`: the four tiles count **real PRs only** (`number > 0`); a
  `ghError` warning banner renders above the cards.
- The store refreshes the cards on a 30s beat (`refreshReviews`, server memo
  caps the gh read); `Rail.tsx` badge reads the new shape.

## Verified
- `tsc --noEmit` clean; `npm run build` green.
- Live on a fresh gate instance: `/api/reviews` →
  `{"cards":[{lint card}],"ghError":""}` — the shape answers, and the next open
  PR (ReviewDecision fetched) lights Open PRs within the 30s beat.
- `gh pr list --repo zerwiz/ymir` verified working with the seat's token (all
  three PRs now MERGED — hence 0, correctly).

## Files
- `apps/hlidskjalf/server/index.ts` · `apps/hlidskjalf/src/gates/Reviews.tsx`
- `apps/hlidskjalf/src/state/store.ts` · `apps/hlidskjalf/src/app/App.tsx`
- `apps/hlidskjalf/src/app/Rail.tsx` · `apps/hlidskjalf/src/services/api.ts`
- `apps/hlidskjalf/src/types.ts` · `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`

## The other half — the served bundle
The SPA the operator's browser loads comes from the **installed npm package**
(`node_modules/@zerwiz/ymir/apps/hlidskjalf`, pid on :3888), not the live tree.
UI fixes behave like ghosts until the shelf is re-published and the SPA server
restarted — the deployment wiring (publish on merge, or serve the tree) is the
second errand of this audit.