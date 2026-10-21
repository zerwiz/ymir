# The bark reaches the pocket — and why both channels are in the code

**Component:** ward · **Seat:** heimdall · **Date:** 2026-10-21

## What was missing

The hound spoke on the desktop and nothing else. A CRITICAL at 03:00 reached a dark screen.
Plan 99's P0 is the mouth: `bin/ward/garmr/notify.py`, wired into the brain at HIGH and above.

## The channel, decided from the Allfather's own testing

He tested both self-hosted behind nginx and reported:

- **ntfy** — no channels to create, anyone may send or subscribe (simple), but **fragile to set up**
  and its web UI never confirmed that messages were posted.
- **gotify** — trivial to stand up, but apps belong to their creator and he found no shared apps;
  he will not share client logins.

**Gotify is the default**, for three reasons: it worked first try; a per-user **app token** is
exactly a revocable identity for a machine sender (the hound is a client, not a colleague, so the
shared-apps limitation does not bite); and its API returns a message id, which is **proof of
delivery** — the one thing his ntfy test could not confirm.

**ntfy is kept**, because the r/selfhosted thread he sent adds three facts: the web-UI fault is
known (with websockets the phone is reliable), ntfy now has **access control** — so "anyone can
post to a topic" is a configuration rather than a property — and topics are the right shape when
several devices or people must hear the same message. Switching is one word: `alert.phone`.

## What the code enforces

- Severity becomes priority (gotify 0-10, ntfy 1-5 + a tag), so a CRITICAL can bypass a quiet profile.
- The body is severity + the finding line + the Rune id — **no content** (Rules 15/26 hold at the phone).
- Delivery is **proved**: the server's id is returned; a failure names the channel or the network.
- Ten messages an hour at most, and a storm collapses to one line.
- Quiet hours suppress MEDIUM and never CRITICAL.
- The URL is configuration; the token is a **reference** (`GARMR_GOTIFY_TOKEN` /
  `GARMR_NTFY_TOKEN`) read from the vault.

## Proof without a phone

`.agents/tests/garmr.test.sh` stands a stub channel in for the phone: a CRITICAL reaches it,
priority is 10, the token travels as Gotify expects, **no secret is in the body**, INFO never
pages, the ntfy leg sends too and authenticates when a token is set. Seven assertions.

## Still needed from the Allfather

`GOTIFY_URL` (or `GARMR_NTFY_URL` + `GARMR_NTFY_TOPIC`) and the token, in
`hodd/secrets/platform.env`; then `bin/ward/garmr/notify.py --test`.
