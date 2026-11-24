# The kit's header gains creation dates and board fields, and one prefix per product

**2026-11-24 · component: collab**

## What was wrong

The kit's header described a plan with an `updated` date but no creation date, so a board mirror could not say when
a plan or document began. A repository that holds two products also had no way to give each its own plan numbers:
a product renamed mid-flight kept sharing the other's counter.

## What changed

`bin/collab/kit/docs/headers.md` now lists the board fields (`created`, `product`, `id`, `legacy_id`, `co_owners`,
`start`, `due`, `labels`, `parent`, `links`) and states one prefix per product, with an earlier number kept in
`legacy_id` when a product is renamed. The ticket README points to the same fields.

## Checker

`scripts/status.py` reads `created`, `product` and `legacy_id` when present and reports a plan that has a header but no `created` as a warning only. The required fields and the exit code are unchanged.

## References

- `bin/collab/kit/docs/headers.md`
- `bin/collab/kit/plans/tickets/README.md`
