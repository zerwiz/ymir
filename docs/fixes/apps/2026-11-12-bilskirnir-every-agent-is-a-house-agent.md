# Bilskirnir: every agent is a house agent from birth

**2026-11-12 · component: apps · `apps/bilskirnir/house/house.py` · `server/src/engine.ts` · `setup.sh` · `house/desk.sh` · `tests/house-agents.mts`**

## What was wrong

Only the first agent was a house agent. `setup.sh` dressed her engine with the house soul, the house MCP doors and the
platform toolsets. A bot made in the app went through `engine.ts`, which gave it only its own `hq` door, the single
toolset `hermes-api-server` and a four-line stock soul. An agent named "Marketing" therefore answered "your todo list is
empty" while the Allfather's to-do was full. It had no to-do, no brief, no well and no arm. The helm had patched one
bot's files by hand.

## What was done

One renderer, `house/house.py`, now builds an agent's house parts: the soul, the MCP doors, the toolsets, the browser pin
and the session hook. `setup.sh` calls it for the primary agent and `engine.ts` calls it whenever a bot's gateway starts.

- **Soul.** The template takes the bot's own name and role, as the user gave them. The house, fleet and operator come
  from the home (`seats.yaml`, `operator.yaml`). Nothing is hard-coded.
- **Existing bots.** The house soul sits in a managed block, `<!-- house:begin … --> … <!-- house:end -->`. A bot's own
  soul lines stay outside it. The old stock soul carried nothing of the user's and is replaced. A start refreshes the
  block and nothing else, so repeated starts change nothing.
- **Doors.** `ymir`, `well`, `skuld`, `bolthorn` and `house` are merged into the config. The bot's own `hq` door and any
  door the user added are kept.
- **Hook consent.** The machine's Hermes shell-hook allow-list is carried into the bot's home, as setup.sh does for the primary.

A bot whose gateway is already running is adopted as it is, so it is brought up to date at its next start.

## "Couldn't reach <bot>'s screen"

This one was ours. The desk container binds its VNC password file from the checkout that first raised it. The app reads
`data/desk/vnc.pass` of whichever checkout it runs from. Two checkouts mean two passwords, so every relay failed with
`VNC auth failed Authentication failure` (three of these are in the server log). Measured on the live desk: its secret
mount pointed into an errand worktree, not the app's tree.

`house/desk.sh up` now compares the mount with its own password directory and recreates the container on a mismatch.
The home volume with the browser profiles stays. `status` reports `secret=other-checkout` and fails. The running desk was
not touched here: recreating it closes the agents' open screens, so the next `setup.sh` run (or `desk.sh up`) does it
when the helm chooses.

## Proof

`npx tsx tests/house-agents.mts` (a throwaway home, database and engines folder): a new bot carries the five house doors,
its `hq` door and the house toolsets; its soul names its own role and the home's house and operator; a restart leaves the
config and soul byte-identical; its own soul lines survive; an old bot is brought up to date.
