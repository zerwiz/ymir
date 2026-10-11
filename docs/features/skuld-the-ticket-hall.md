# Skuld — the ticket hall

## What it is

**Skuld** is Ymir's ticket hall: the ledger of **tickets** (asks) and **plans**, with a
fixed lifecycle and a **review gate**. A ticket moves **Backlog → Planned → Ready →
In Progress → Submitted for Review → In Review → Approved → Done** — each step legal
only in order, so an agent cannot declare work done without the review. The store
lives on the **heart**; every body reaches it through its own gateway.

## What you need

- Ymir installed; the heart's Skuld service reachable (the local gate fronts it).
- Agents reach it as MCP tools (`skuld_tickets_*`, `skuld_plans_*`).

## Do it

Agents use the **MCP tools** (the ticket hall is a service, not a shell script):

```
skuld_namespaces_list      the registered projects
skuld_namespaces_create    register one — a slug + a display name (tickets and plans refuse an unregistered namespace)
skuld_tickets_list         filter by namespace/status/priority
skuld_tickets_create       a registered namespace, title, description, priority
skuld_tickets_get          one ticket
skuld_tickets_update       the legal march only (an illegal step is REFUSED)
skuld_comments_post        a word on the ticket
skuld_plans_*              the roadmap (create/list/get/update/pending)
skuld_sync                 push this body's journal to the heart; refresh link
```

On the shell side, the seat's ticket/role doors live under `bin/skuld/`:

```bash
bin/skuld/role.sh            # this machine's role (heart | forge | dev | hand)
bin/skuld/role-lib.sh        # the role resolution used by the installer
```

## Notes and limits

- **The march is law.** `tickets_update` refuses an illegal step (`Backlog → Done`) **and
  blocks the agent** until the operator clears it — make tickets to the shape, always.
- **The store is on the heart.** A body serves a cached catalogue when the heart is dark
  and **queues its writes** to a local journal, flushed by `skuld_sync`. The ledger of
  record is always the heart.
- **A ticket is not a plan.** Plans hold the reasoning; tickets hold the *state*.

## If it does not work

| What you see | What to do |
|---|---|
| `blocked: illegal march …` | You attempted an illegal transition. The operator clears it (`skuld_blocks_clear`); then walk the steps in order. |
| A write is `queued to the journal` | The heart is unreachable; it will flush on `skuld_sync` — the write is not lost. |
| A create is refused | The namespace is not registered — `skuld_namespaces_list`, then `skuld_namespaces_create` (a slug like `odrerir` and a display name). |
