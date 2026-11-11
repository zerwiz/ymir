# A fleet has one guide from zero

**Date:** 2026-11-11 · **Component:** fleet (docs)

## What was missing

An operator setting up Ymir on several machines had the pieces spread over a dozen pages: install, the home contract,
the seats and the arm, the fleet wire, the home push door, the constellation road. No page said, in order, how to build
the private home, how to install each machine by role, what the arm holder must do every session, and how one fleet
speaks to another. A partner asked for exactly that.

## The fix

`docs/features/build-a-fleet.md` — one guide, top to bottom: the idea; a fleet laid out by duty
(heart · forge · dev · hand); the two channels proven to work (the arm's wake queue and a line into a herdr pane); how the
agents work on one machine; the home from zero (private repo, naming, encrypted secrets, pull-first/push-after); each
machine (Tailscale, keys, install by role, seat naming, harnesses, models, update and repair); a ten-point arm-holder
checklist; plans; how two fleets speak arm to arm through each operator's own Cloudflare Tunnel and Access service
token plus a countersigned grant; and what stands today versus what is being built. Catalogue entry `04-008`, index row
in `docs/features/README.md`.
