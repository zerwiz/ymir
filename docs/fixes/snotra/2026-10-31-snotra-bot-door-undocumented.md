# Fix: Snotra's meeting-join door was undocumented

**Date:** 2026-10-31
**Component:** snotra
**Severity:** medium (agent missed a capability, wrong advice given)

## Problem
An agent was asked to "invite Snotra to a meeting so she can listen." The agent
only knew about `snotra-capture.sh` (local mic + system-audio capture) and
concluded Snotra could not join a Meet. In fact `bin/time/snotra/snotra-bot.sh`
sends Snotra into a meeting through the Vexa API (`join <url>`), and
`snotra-autojoin.sh` reads the calendar and auto-joins. None of this was
surfaced by the `snotra-meeting-outcomes` skill, which only covers the
transcript→record half. The bot door existed, was working (meeting id 6
completed successfully), but was invisible to any agent that searched the skill
shelf.

## Root cause
The Snotra tooling surface is split across `bin/time/snotra/*` (capture, bot,
autojoin, calendar-invite, talk, detect, render-email, mail-send, mail-watch)
but only the outcomes half has a skill. An agent following "find a skill on
demand" never discovers the bot door. Additionally, the bot requires the Vexa
worker to be running on the server to actually spawn a container; when it is
idle, `status` reports `idle` with no `bot_container_id`, which reads as "not
joined" and is indistinguishable from "failed to join."

## Fix
1. Add a `snotra-bot` / `snotra-capture` section to the snotra-meeting-outcomes
   skill (or a new `snotra-ear` skill) listing: capture, bot join, autojoin,
   calendar-invite, status, stop.
2. Make `snotra-bot.sh status` distinguish "registered but worker not spawned"
   from "joined", so an agent (and operator) can tell whether Snotra is actually
   in the call.
3. Ensure the Vexa worker is running on whynot/zerwizserver (systemd) so joins
   spawn containers.

## Lesson for the agent
Before asserting a capability does not exist, search bin/ (not just skills) for
the verb ("join", "bot", "capture"). Skills are the craft, but bin/ is the
full tool surface.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the fleet's always-on heart. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
