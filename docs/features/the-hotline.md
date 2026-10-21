# Hófvarpnir — the one door that tells you what happened

**What it is.** `bin/notify/send.sh` — **Hófvarpnir**, Gná's horse: she rides it over sea and air,
and every rider in the house sends by the same mount. It is the single door every system calls when
it has something to say. Before it, each feature invented its own spout — a desktop popup, a file, or nothing — and
sixteen of twenty events in the house reached nobody.

**What you need.** Nothing for the first three legs. The pocket needs Gotify or ntfy (see
[the guardian](the-guardian.md)); Telegram needs the bot paired and `TELEGRAM_OWNER_ID` in the vault.

**The command**

```sh
bin/notify/send.sh --source snotra --severity HIGH --message "sign-off: Anna confirmed" \
  [--key <stable-id>] [--record <id>] [--ask] [--dry-run] [--no-telegram]
```

```
legs[5]{leg,when,what_it_reaches}:
  "Runes","always","the record — it must not depend on delivery"
  "the arm","MEDIUM+","a wake appended to .wake-queue: the live session sees it between turns"
  "the desktop","MEDIUM+ (not at 03:00)","ymir-say.sh — the room you are in"
  "the pocket","HIGH+","Gotify/ntfy through the guardian's own ladder, budget and quiet hours"
  "Telegram","HIGH+, or --ask","the Bot API directly — it works with **no session running**"
```

**What it refuses to do.** It will not let one `--key` speak twice inside an hour (a timer cannot
spam you), and it collapses a source louder than eight events an hour into one line. A channel that
cries wolf gets muted, and a muted channel is a dead one.

**The severity policy**, in one line each: `INFO` is a record only · `MEDIUM` reaches the session and
the screen · `HIGH` adds the pocket and Telegram · `CRITICAL` also bypasses quiet hours.

**Who calls it today.** The guardian (Garmr), the inbox watcher, and the calendar watch
(`bin/time/calendar-watch.sh`, every five minutes, one reminder fifteen minutes before a meeting and
one at five). A cron failure, a Trello due date and the rest follow in plan 100.

**If it does not work.** `--dry-run` prints the decision and all five legs; a `0` on a leg means that
leg did not answer. If everything is `0`, the message was still written to Runes — the door fails
loudly rather than silently.
