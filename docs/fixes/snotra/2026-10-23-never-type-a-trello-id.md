## snotra · 2026-10-23 — never type a Trello id: the four laws the night's mistakes earned

Six MCP errors in twenty minutes, and one **silent** mistake that mattered more than the five loud ones:
a card was moved into *Done* while I reported *In progress*.

```
errors[6]{what_i_did,what_it_said,cause}:
  "board create with `desc`","Field \"desc\" is not allowed for action \"create\"","one tool, many actions: the schema does not say which field belongs to which action"
  "list create with a bare objectId","Expected a Trello **board ARI**","every object has two identifiers — `id` (ARI) and `objectId` (bare) — and the write doors want the ARI"
  "board `archive`","action must be one of the allowed values — and the schema printed only `create` while its own prose lists update/archive","**schema drift on the server**"
  "card create with `memberId`","Field \"memberId\" is not allowed for create","same as the first"
  "card move with a bare objectId","Expected a Trello **card ARI**","same as the second"
  "card move to `…ef1`","**succeeded — into Done**","**the id was invented** instead of resolved, and the response's `list.name` was not read"
```

**The two that are mine, not the tool's:** the invented id and the unread response. The map built an hour
earlier already held every list id.

```
laws[4]{rule,why}:
  "read before write","the map first, always — a board you have not read is a board you will duplicate (one Control Tower already had to be archived tonight)"
  "resolve by name, never type an id","`trello-map.sh --resolve '<board>' '<list>'` prints the list ARI; `--bare` prints the REST id"
  "write with the ARI","`ari:cloud:trello::list/workspace/<ws>/<id>` — the bare objectId is refused by every MCP write door"
  "verify the returned object","`list.name` and `board.name` in the response must be the ones you meant; a 200 with the wrong list is a wrong call"
```

**What changed:** `trello-map.sh` now stores **every list's ARI** (`--resolve` by name, `--bare` for REST) and
the workspace id, so an agent stops composing identifiers. The server-side drift (actions and per-action
fields) cannot be fixed from here — but the two doors actually used (`create`, `move`) are now
name-in / ARI-out with a verification step.

**Verified:** `--resolve 'control tower' 'in progress'` → `…6ad2390563fd7fb2faf56eee` (the list the card is in
now, confirmed by the response's `list.name`).
