## odrerir · unversioned · 2026-10-11 — the book had no door to register a namespace

**The Allfather, 2026-10-11:** *"can we add the namespace thru the mcp?"* — and,
when the answer was no: *"then we need to add that to the mcp if we cant."*

### Why

The tickets MCP served **`namespaces_list` and nothing that could add one**, while both
`tickets_create` and `plans_create` REFUSE a namespace that is not already registered:

```
refused: namespace '…' is not on the registry
```

So the registry could only be extended by hand with `psql` against the heart's Postgres
(`SKULD_DBPGHOST`/`skuld`), from a machine that has the book — a door no agent and no cron
row could run. **A registry with no door is a registry that only the operator's memory can
extend**, which is exactly the shape the hall's own laws forbid. It surfaced when a new
project needed a namespace and there was no tool to make one.

### What

`namespaces_create` is now served by `tools/tickets-mcp/server.mjs`:

- **a slug** — `2..40`, lower-case letters, digits and `-`, folded to lower case
  (`Probe-NS` → `probe-ns`)
- **a display name** (`about`, 2+ chars) — what the pickers show; the list already
  `COALESCE`s it to the slug
- a malformed slug or a thin display name is **REFUSED and blocks the agent**, the same
  blocking law a bad ticket carries
- registering one that already exists is a **no-op, not an error** — the door is safe to
  call twice
- a store refusal is reported **verbatim**, so a future schema drift names its own column

Also mapped `tools/tickets-mcp/*` to the `odrerir` component in the fixes guard — the book
is the hall's book (plan 43), and until now a change here matched no component, so the
guard had nothing to check the record against.

### Verified

Proven **without the heart**, against the real `server.mjs`, its real handler, with a stub
`psql` (the SDK lives on the heart, so the probe stubs both the SDK surface and the DB):

```
tools registered: 16 · has namespaces_create: true
BAD SLUG    -> "refused: a namespace is a SLUG — lower-case letters, digits and '-', 2..40 chars (e.g. odrerir)" | isError: true
SHORT ABOUT -> "refused: a namespace needs a display name (2+ chars) — it is what the pickers show" | isError: true
GOOD SLUG   -> "registered: probe-ns|Probe Namespace" | isError: false
```

and the SQL the door actually emitted:

```
SELECT reason FROM blocks WHERE agent = 'brokk'
INSERT INTO blocks (agent, reason) VALUES ('brokk', 'namespaces/create refused: about') …
SELECT 1 FROM namespaces WHERE name = 'probe-ns'
INSERT INTO namespaces (name, about) VALUES ('probe-ns', 'Probe Namespace') RETURNING name, COALESCE(about, name)
```

`node --check tools/tickets-mcp/server.mjs` clean. The probe's refusal wrote a *block* row —
into the stub, not the heart; `skuld_blocks_status` answered `clean: brokk` afterwards,
which is the check that the test harmed nothing.

**Honest limit:** the tool is exercisable end-to-end only once the heart redeploys
`tools/` (the fleet-ensure step). The check after that deploy is one call:
`skuld_namespaces_create(name="probe-ns", about="Probe Namespace")`, then
`skuld_namespaces_list` shows it.

### Files

- `tools/tickets-mcp/server.mjs` — the `namespaces_create` door
- `bin/gates/guards/fixes-guard.sh` — `tools/tickets-mcp/*` → `odrerir`
- `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md` — the tool list + the dated note
- `docs/features/skuld-the-ticket-hall.md` — the user-facing list and the refusal row
