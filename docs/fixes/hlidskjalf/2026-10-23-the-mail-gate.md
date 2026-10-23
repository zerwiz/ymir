# The mail gate: a page that can read a mailbox and cannot send

**Date:** 2026-10-23 · **Component:** hlidskjalf · **Plan:** 116 (Gná)

## What was added

The twenty-first gate. `Gná` reads what the mail desk
(`hodd/bin/gna-agent/gna_desk.py`, loopback `:8490`) says, and adds no judgement of its own.

```
pieces[6]{path,what}:
  "src/gates/Mail.tsx","four columns — Needs you · Unsure · Waiting · Done — one row = sender · subject · proposed action · confidence; a row opens the message with its evidence and body"
  "src/services/api.ts","MailRow · MailMessage · MailQueue shapes and three methods; every shape is the desk's own answer"
  "src/data/realms.ts","gate id mail, label Gná, glyph ᚷ"
  "src/types.ts","'mail' added to GateId"
  "src/app/Shell.tsx","the stage case"
  "src/data/metadata.ts","the page's title and description (the surface's rule 6)"
```

```
server[2]{route,does}:
  "GET /api/mail/accounts","forwards to the desk's /accounts — the declared scope is the truth, so no account is hardcoded in the gate"
  "GET /api/mail/queue · /api/mail/message","forwards with the desk's bearer token, passing its refusals through unchanged"
```

`GNA_DESK_URL` overrides the desk address (default `http://127.0.0.1:8490`, Rule 07); the token is read
from `$YMIR_HOARD/state/gna-desk.token`. A missing token answers **503 with the command that raises the
desk**, never an empty queue.

## Why a proxy and not a branch in the server

`server/index.ts` is ~2,700 lines and already carries auth, OAuth, PTY and the desk. Mail carries a
per-account security boundary, and the house's pattern for that is a small service of its own — the
fourth after the desk, the MCP and Snotra.

## Proofs run in this change

```
proofs[4]{check,result}:
  "npx tsc --noEmit","clean"
  "npx vite build","built (2.76 s)"
  "GET /api/mail/accounts (gate :3899 → desk :8490)","{\"accounts\":[\"<one declared account>\"]}"
  "GET /api/mail/queue without account · with an undeclared account","400 \"account scope required…\" · 400 \"account not declared…\" — the desk's own sentences, unchanged"
```

## What the page must never gain

No send button, no draft box, no cross-account view, no model call from the browser. Drafts and
approvals are plan 116's P1, behind the same gate, and only after the store's account scope is proven
by a test that a cross-account query fails — which it already is
(`tests/test_gna.py::StoreScope`).
