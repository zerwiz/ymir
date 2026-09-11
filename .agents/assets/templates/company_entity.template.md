# Company Entity Card

> Template for `svartalfaheim/<realm>/companies/<house>/entity.md` (plan 21).
> Every venture the fleet carries is a **house** with an entity card. Copy and fill.

```yaml
---
name: <Venture name>
type: <company | personal>
owner: <operator login>
realm: <way-of | zerwiz | craig | …>
house: <ymirlabs | brokkforge | runestone | muninn | dvalin | utgard | askr | mannheim>
products:
  - <product>
repo: <git remote or local path>
status: <active | holding | paused | retired>
lore_line: "<the myth that names this venture>"
---
```

## Charter

One paragraph: what this house does, and for whom.

## Products

- **<product>** — what it is, where it lives.

## Delivery posture

Standing mode for house projects: `no-mistakes` | `direct-PR` | `local-only`
(never a substitute for a per-task decision; see `data/projects.md`).

## Notes

Realm-scoped only — a house card never reaches across realms. Split or merge a
house only by a new append-only entry.
