# assets/mock — archived UI seed data

Preserved copies of the Hlidskjalf mock/seed sources, kept for possible later use.
They are **not** imported by the shipped UI.

| File | Was | Purpose |
|---|---|---|
| `mock.ts` | `apps/hlidskjalf/src/data/mock.ts` | seed agents/tasks/runes/stream/recall/processes/reviews/files/skills/chat |
| `feeds.ts` | `apps/hlidskjalf/src/data/feeds.ts` | hardcoded per-page stream narration (`feedEvent` / `seedGateFeed`) |

Context: the Allfather directed the UI to carry no mock data in live mode; the
synthetic stream feed and seeded live paths were removed. A **hidden demo** may
still seed from `src/data/mock.ts`.

Law: `AGENTS.md` §Operational laws — *"No mocks, no examples, no placeholders in
shipped runtime or deliverables."* This directory is the archive, not the runtime.
