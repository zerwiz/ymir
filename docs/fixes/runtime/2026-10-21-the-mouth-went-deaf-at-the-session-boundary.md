## runtime · 2026-10-21 — the mouth went deaf at the session boundary

### Why
He wrote into Brokk's Telegram DM for half an hour and got nothing, while Skírnir answered
his own bot throughout. The fault was one layer under both, in the Pi bridge's inbound
journal, and it had two parts plus an aggravator.

**1 · The header lost a field the receipt scope is built from.** `createTelegramUpdateJournalReceiptScope`
(`@llblab/pi-telegram`, `dist/lib/journal.js`) hashes `{version, profile, bot:{botId}}` when a
bot id is known, else `{version, profile, bot:{tokenSha256}}`. The journal header on disk
(`sessions/01a15e12…/inbox.json`) carried the **token-only** form, written by an older runtime,
while every segment written since carried `botId: 8961261921`. Same bot, same token, two
different scope strings — so every read was refused:

```
bin/…/journal.js:1642  identity-mismatch — "does not retain the expected receipt scope"
```

Nine such events between 22:30 and 22:38, and `queue-receipt-publish` failed for updateId
44783265 at 22:43:33. Nothing was lost: the entries sat in the segments with `state: pending`.

**2 · The journal stayed bound to the previous session.** After the session boundary at
22:43:32 the persisted `transport.journalPath` still pointed at `01a15e12…`, so inbound kept
landing in a journal the new session (`01a15ffd…`) never reads.

**3 · Three `pi` processes were alive** (57146 · 587220 · 754482) and each takes the bridge on
start: `ownership-lost`, `getUpdates` aborted, then `follower-restore` **skipped** because
Threaded Mode is disabled — so the losing session goes deaf rather than recovering.

### Fix
- `transport.journalPath` repointed at the live session's inbox (`state.json`, backup
  `state.json.bak-20261021-2253`).
- The stale header patched to carry `botId` (`inbox.json.bak-20261021-2250`).
- The live process holds `journalPath` in memory, so the binding only takes effect on a
  reconnect: `/telegram-connect`, which performed the extension's own damaged-state reset at
  22:51:43 (`previous runtime continuity was discarded`). From then the leg held.

### What is owed upstream
A version bump that adds `botId` to the scope leaves **every existing journal unreadable**.
The correct behaviour is to adopt the segment's scope (or re-scope the journal) once on read
and record it, not to refuse. Reported with the times above.

### Verified
`[telegram] hi` arrived as a turn and was answered; the DM leg has held since.

### Files
- `~/.pi/agent/tmp/pi-telegram/state.json` (runtime state, not a tracked file)
- `~/.pi/agent/tmp/pi-telegram/sessions/*/inbox.json` (runtime state)
- `$YMIR_HOME/svartalfaheim/whynotproductions/projects/ymir/plans/101-the-assistant.md` §8
