# The seat could not be admitted, and the door spoke a retired API

**Date:** 2026-11-13 · **Component:** snotra · **Doors:**
`systems/snotra/services/ear/snotra-cdp.py` (the CDP seat),
`snotra-bot.sh` (the Vexa door), `snotra-autojoin.sh` (the clock),
`.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md`

The question was the Allfather's, twice: *why is Snotra not joining the meetings on my
calendar?* This note records what was measured, what was mended, and the one thing that
still needs him.

## What the machine said at the start

The calendar half works. `snotra-autojoin.sh scan` read the calendar cache and planned a
join for the one meeting that was live. The rules that keep it out of the wrong room
(private, blocked titles, declined, cancelled) all fired correctly.

The engine half was absent, and one long-standing assumption was wrong. Port `8090` on the
tailnet address answers — but it is **Element**, the Matrix client of the Gladsheim stack,
not a Vexa runtime. Port `18080` answers nothing. There is no `VEXA_API_URL`,
`VEXA_API_URLS` or `VEXA_API_KEY` in the vault, so `snotra-bot.sh` refusing with *"VEXA_API_URL
is not set"* was telling the truth. Plan 147's runtime is gone from this box, and no other
machine on the tailnet serves one.

## The disk, measured twice

At 23:10 this box had **3.9 GB free, 99% used**. The chicken is small but not that small:
`vexaai/vexa-lite` is 2.31 GB compressed, about 5.1 GB unpacked, and its PostgreSQL and
storage sidecars carry their own volumes on top. That does not fit, so the first answer to
this errand would have been a number, not a join.

Then, at 23:27, the same disk read **29 GB free, 87% used**: another hand had pruned the
unused images (a 17.4 GB application image with no container behind it, among others).
The fit is now real, and the engine install was started — the lite stack pulls the published
image, it does not build one, so a modest box is enough.

## The seat: three faults, all measured

Snotra's own road into a meeting is the CDP seat: a Chromium whose `getUserMedia` is
replaced by a stream the bridge fills over the DevTools protocol, so the audio never
touches the OS mixer. It had never run on this box, and three faults explain why.

**It could only launch headed.** `cmd_seat` defaulted to a headed browser, and this is a
server with no display it may attach to — the only X sockets belong to `gdm` and their
authority file is unreadable. A seat now launches headless unless the environment actually
has a display (`DISPLAY` or `WAYLAND_DISPLAY`), and `--headed` still forces the old way.

**The default profile was a path the browser could not write.** The Chromium here is a
snap, and its AppArmor profile permits `~/.config/chromium` and `~/snap/chromium/**` but not
an arbitrary hidden directory. The old default (`~/.local/share/skirnir/meet-profile`) died
before the DevTools port ever opened:

```
Failed to create .../SingletonLock: Permission denied (13)
```

The profile now follows the browser that will use it, never a fixed path.

**The session was closed before the bridge could survive.** `Page.addScriptToEvaluateOnNewDocument`
is registered on a CDP session; the seat closed that session right after navigating and
then re-attached to verify — so the seat reported `bridge=False` on every run, even when
`bridge-installed` had just printed. Measured directly: install on a page, re-attach, navigate,
and `window.__skirnir` is gone. One session now runs from install to verdict.

**And the refusal now names what the page actually said.** Until tonight every failed seat
claimed it was *"still in the lobby"*, which was a guess. It now reads the page and quotes it.

## The platform's answer, and what it means

The seat was then run, for real, against the meeting the calendar had open. Chromium reached
Meet, the page loaded, and Meet answered:

> You can't join this video call — your meeting is safe. No one can join a meeting unless
> invited or admitted by the host.

A control run with a **made-up meeting code** produces the identical sentence. So the text
is Meet's generic "this guest is not admitted", not a specific verdict about that meeting:
it does not prove a Workspace guest restriction, and it does not prove the link was dead.
Both remain possible, and the difference matters — the next attempt should learn which from
the Allfather rather than from a guess.

One thing the control does establish: an anonymous headless guest was **not** admitted, and
the seat never reached the lobby. The road that survives that answer is an *invited or
signed-in participant* — Vexa supports authenticated bots for exactly this case, which needs
the Allfather's word on which Google account the bot may be.

Nothing in this note calls that a join. A bot is in the room when `status` reads it running
**and** the participants see it.

## The door was speaking an API that no longer exists

Independent of the engine being absent: `snotra-bot.sh` posted to `/meetings`, which Vexa
0.12 does not serve. The current contract, read from the source rather than from memory, is
`POST /bots` with `platform` and `native_meeting_id`, `GET /bots/status` for the running
bots, and `DELETE /bots/{platform}/{id}` to stop one.

The door now speaks that contract, and its words match what it knows:

- a `201` prints `dispatched`, with the line *"accepted is not joined"* beside it;
- `status` reads the **running** list, not a stored meeting row, and exits `4` when nothing
  is running — the exact distinction plan 147 was written about;
- `503` is named for what it is: no transcription backend wired, so a capture-only bot would
  be a meeting nobody can read.

## The clock was recording refusals as joins

`snotra-autojoin.sh run --apply` appended the meeting key to the joined list **whether or not
the door succeeded**, so a refused join was written down as done and the meeting was never
retried. Proven both ways with a stub door: with a failing join the joined file is not
written at all, and with a succeeding one the key is recorded.

## The engine, standing, and the bot it really spawned

The lite stack is installed on this box and answers: `vexa-lite` reports **healthy**, the
gateway on `8056` answers `/health` with `200`, the agent API is on `8100`, the terminal on
`3001`, and the bundled CPU transcription service on `8083`. It costs about 600 MB resident,
48 MB for PostgreSQL and 152 MB for the transcriber.

Then the door was used for real, twice: once on a made-up meeting code, and once on the
meeting the calendar had live. Both times the engine answered `201` and the door printed
`dispatched`, and both times the engine really did spawn the bot — the API row carries
`bot_container_id: mtg-…`, the very field that was `null` in plan 147, and a Playwright
Chromium ran inside the container with its own workload log.

The clock did the second one — `bin/time/nornir-job-snotra-autojoin.sh` was run by hand
exactly as the schedule will run it, and it found the live meeting, dispatched the bot and
recorded nothing as joined.

## What Meet did with the bot

The engine's own record of that meeting is unambiguous:

- `completion_reason: join_failure`, `failure_stage: joining`;
- the bot found the name field, typed its name, muted itself, and then searched for the join
  button for sixty seconds;
- its reason: *"Could not locate join button by any locale-agnostic or English selector after
  60000ms (url=https://workspace.google.com/products/meet/…)"*.

The screenshot the bot saved at that moment is Google's Workspace marketing page for Meet.
Meet did not show the bot a lobby, a knock, or a refusal sentence: it moved the browser off
the meeting entirely.

That is the same place this seat's own headless Chromium landed earlier the same night. Two
independent browser stacks, one answer. An anonymous, automated guest is not admitted to a
Meet link from this calendar, and no amount of retrying changes that.

> [!IMPORTANT]
> **The one thing that is still owed is a decision, not a script.** A bot that may join these
> meetings has to be a *signed-in or invited participant*. Vexa supports that (sign in once,
> persist the browser session), and it needs a Google account the bot may use — the
> Allfather's word, never a guess and never an invented account. A transcript follows from
> the same decision: with no seat in the room there is nothing to transcribe, and the door
> will not pretend otherwise.

## The clock: a cadence the scheduler could not express

Auto-join needs to run every few minutes; a meeting that starts at `:10` and lasts thirty
minutes is gone before an hourly job wakes. Nornir's shapes were `HH:MM`, `@hourly`,
`@hourly:MM` and `@daily` — none of them every-five-minutes.

`@every:N` is now a shape: fires when the minute of the hour is a multiple of `N`, stamped
per `N`-minute slot, so a 45-second tick cannot fire it twice in a minute. The validator
accepts `@every:1` … `@every:59` and refuses `0`, `60` and anything non-numeric; at `N=5`
it fires twelve times an hour.

The row itself is `@heart @every:5 bin/time/nornir-job-snotra-autojoin.sh`, and the job is
honest about the engine: it asks `snotra-bot.sh health` first, and with no engine it prints
one clean skip and exits 0 — a clock that fires without a bot is not a red row, and it never
dresses a refusal as a join.

> [!IMPORTANT]
> The scheduler that is running on this box was started six days ago and carries its loop in
> its own command line, so it does not know the new shape yet: until the runtime is renewed
> and the loop restarted, the row is recorded in `state/.cron-invalid` and `--status` reports
> it. A seat cannot restart the house scheduler; the primary owns that start.

## CHANGE LOG

- `systems/snotra/services/ear/snotra-cdp.py` — headless by default where there is no
  display; the profile follows the browser (snap-aware); one CDP session from install to
  verdict; the refusal quotes the page instead of assuming a lobby.
- `systems/snotra/services/ear/snotra-bot.sh` — speaks Vexa 0.12 (`/bots`, `/bots/status`,
  `DELETE /bots/{platform}/{id}`); link parsing for Meet, Zoom and Teams codes; `dispatched`
  instead of "joined"; `status` reads the running bots and exits 4 when none is running;
  `health` added; `503` explained.
- `systems/snotra/services/ear/snotra-autojoin.sh` — a refused join is no longer recorded as
  a join, so the meeting stays eligible for the next run.
- `bin/time/nornir-cron-start.sh` — the `@every:N` shape, so a cadence finer than an hour can
  be declared; `config/cron.yaml.example` documents it.
- `bin/time/nornir-job-snotra-autojoin.sh` — the clock: health first, a clean skip with no
  engine, a Rune per dispatched run.
- `tests/test_snotra_bot.sh` — rewritten against the current contract (17 assertions, was 6
  passing of 11); `tests/test_snotra_autojoin.sh` gained the refused-join-is-not-recorded
  proof and two of the clock's own (18 assertions).
- `docs/features/snotra-meetings.md` — the commands and the honest word (`dispatched`, not
  "joined"), and the headless-guest limit.
- The Vexa Lite stack installed on this box: `vexa-lite` (gateway `8056`, agent `8100`,
  terminal `3001`), `vexa-lite-postgres`, `vexa-lite-storage`, `vexa-lite-whisper` on `8083`.
  The door resolves its key from the engine's own `/run/vexa/key.env` and its URL from one
  documented loopback default, so no credential is copied into the vault or a document.
- `.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md` — the owning asset carries
  the same three faults and the admission finding.
