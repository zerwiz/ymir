Read when: building or checking anything that must work on more than one machine, reading a machine's role, or touching a platform layer (Omarchy, macOS, Windows).

# The fleet, roles and platforms

Part of the Ymir contract. The prior text is kept verbatim in `docs/contract-history/AGENTS-2026-11-24.md`.

## Ymir is a program, and it runs globally (RULES/51)

At the operator's word, 2026-11-11: *"ymir are the logic. the tools. the programs."* · *"ymir must work GLOBALLY on the
users computers."* This repository is the **source** Ymir is built and shipped from; it is **not** where Ymir is used.
Ymir runs in the user's **root agents**, the global agent of every harness they have (pi, Claude Code, OpenCode, Codex,
Cursor, Hermes, and any harness to come), and in their home. A session opened in `~` or in any project has all of it: the
contract, the extensions (on pi at least `ro`, ask-user, `todo`, `open-editor`), the MCP doors, the skills and the hooks.

**Install and every update seat them; a root agent loads the pinned runtime, never a working tree.** Applications run
from the pin `~/ymir-runtime` → `releases/<sha>`: `bin/engine/release.sh build --ref main` builds one, and `flip <sha>`
switches to it. A feature is done when it answers from a session opened outside this checkout, on every harness, after
install and after update. When you develop Ymir, build for the root agent first. The full law is
`RULES/51-ymir-is-a-program.md`.

**Hermes is a root agent too** (plan 372, 2026-11-25). At the operator's word: *"in all places we mention what harness
pi works for, we need to add Hermes."* Install and every update seat it from the pin (`ymir hermes seat`,
`docs/features/ymir-whole-in-hermes.md`): the contract (`~/.hermes/SOUL.md`, `~/.hermes/AGENTS.md`, `.hermes.md`), the
MCP doors, the skills shelf, the Sága head on its first turn and the worker wake. When a Hermes session holds the arm, a
tell is posted into it through its gateway (`bin/voice/hermes-arm-wake.sh`, plan 369 item 1). Still owed: a recorded
end-to-end run proving the tell shows in a live Hermes chat.

## The fleet is the test (RULES/25, 2026-10-28)

*"this must be built so it works for this device and the fleet."* Agnostic is the floor; functional for the fleet is the
law. A capability is done when it answers on **every role** in `fleet.json` (heart · forge · dev · hand) and over
**every road** those roles have. The same verb must succeed on each role by taking that role's road, and `status` must
name the road that answered (`up (local)` vs `up (door)`). A clean skip that stands in for a capability the fleet needs
is not a pass; it is unfinished.

| Rule | Why |
|---|---|
| The role is read, once | `bin/skuld/role.sh resolve`, from the fleet registry by hostname, never a second table |
| One command, every role | a second flag the operator must remember is drift |
| A borrowed capability says so | a green that hides a borrow is the false green this house has paid for twice |
| Prove it on a second machine | the accept line names the machine and what it printed |

The first application shipped the same day: the well was dark on a hand because `bin/bridge/mimir-bridge.sh --start`
skipped wherever `engram` cannot be imported. It now probes: a local engine is served; otherwise it raises the door
(`bin/records/well-door.sh`, ssh to the heart) and says `4602,"door","borrowed from the heart"`. The path is carried
through plan **138** (Vár, the pledge book, inside Vörðr's ward).

**One core, every device** (RULES/25): probe, never assume; a clean skip is a pass only where the fleet does not need the
capability; a move is a migration. **No local network is assumed:** every cross-host path is a Tailscale MagicDNS name,
a tunnel, or another public endpoint read from the home, never a LAN address baked into code.

## The arm and the desk

- **The arm.** One session on each machine holds it: the session lock, the wake queue, dispatch and the answers. Ask
  `bin/voice/rodd-arm.sh who` (this machine) or `bin/fleet/arm-send.sh --who` (the fleet). Reach the holder with
  `bin/voice/rodd-arm.sh tell --from <you> "<text>"`; a tell is handed, not done, until the holder answers. A session
  that does not hold the arm is read-only for spawn, steer, merge and drain, and says so instead of acting. It never
  takes the helm: `rodd-arm.sh hold` only takes a vacant arm.
- **The desk.** While `bin/desk/in-call.sh holder` prints anything, no app restarts and no sound tests: the operator is
  on a call and the machine is theirs.
- **After every test, close what you started** (test windows, temporary profiles, dev and preview servers, browsers),
  check with `ps` and `hyprctl clients` that nothing of yours is left, and never close a window the operator had open.

## Platform installations (RULES/05)

Ymir is **Omarchy-first**. The **core is portable** (Linux, macOS, Windows under WSL2), and each platform may add its
own **installation layer**. The Omarchy layer is first-class: host sensing, numbered-desktop placement, launcher
entries, shell plugins, a post-update hook. macOS and Windows bring their own. A layer is gated on its host and reports a
clean skip elsewhere, never assumed.

**The duty:** when a core feature changes, **every platform layer is updated in the same change**. A layer still
installing the old shape is drift, and drift means a machine expecting a runtime it no longer has. Never call a core
change verified because one platform's install passed. The law is `RULES/05-platforms.md`.

## Configuration is never hardcoded (RULES/07)

Ports, hosts, paths and credentials resolve from env or config with one documented default.

## CHANGE LOG

- **2026-11-25** — written when the contract was split by topic (plan 369 item 7); its text is folded from the
  sections of the prior `AGENTS.md`, kept verbatim in `docs/contract-history/AGENTS-2026-11-24.md`.
