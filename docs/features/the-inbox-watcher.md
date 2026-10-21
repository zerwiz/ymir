# The inbox watcher — do the people we wrote to answer us?

**What it is.** `bin/people/inbox-watch.sh` reads the mailbox for replies from the people in the
collaborator registry, and says so in three places: the **Runes** ledger, the desktop, and the
phone. `bin/people/inbox.sh` is the read door underneath it — "has Andrej answered?" asked as a
command.

**What you need.** The Gmail grant in the vault (`SNOTRA_GOOGLE_REFRESH_TOKEN` with its client id and
secret), and a registry entry for the person (`bin/people/collaborators.sh add …`).

**The commands**

```sh
bin/people/inbox.sh --from andre.matejic@gmail.com --days 7      # what he wrote to us
bin/people/inbox.sh --to   andre.matejic@gmail.com --days 1      # what we sent him
bin/people/inbox.sh --unread --days 2                            # anything unread
bin/people/inbox-watch.sh                                        # everyone in the registry
bin/people/inbox-watch.sh --dry-run                              # say what it would announce
```

**How it decides what is new.** One message id, announced once. The ids live in
`$YMIR_HOME/hodd/state/people/inbox-seen.json`, so a reply is never spoken twice, and a quiet run is
genuinely quiet.

**The schedule.** `config/cron.yaml` runs it at **08:20, 14:20 and 19:20** — three times a day, which
is often enough for a client and rare enough to stay out of the way. It is stateless otherwise:
read → compare → announce → exit.

**What it does when it finds one.** A Rune (`REPLY from <id> <address>: <subject>`), a desktop line,
and a phone message through the hound's own mouth — the same severity ladder and quiet-hour rules as
every other alert. Nothing is answered automatically; the letter to a client is a human's.

**Limits.** It reads; it never sends, marks, or deletes. It only watches addresses that are in the
registry — a stranger's mail waits for the operator, which is correct.

**If it does not work.** `inbox.sh` first: if that fails, the grant is the problem (refresh token,
client id or secret missing from the vault). If `inbox.sh` works but the watcher says nothing new,
check `inbox-seen.json` — an id already there will not be announced twice.
