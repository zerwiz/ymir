# Bilskirnir: every agent chooses one of the house's own characters

**Status:** built and tested on heimdall, 2026-11-13 (plan 275), at the Allfather's word: *"can't we have 14
characters from us then."*

Bot HQ let a person choose each bot's character from 14 shapes. When it was vendored, that choice was removed and
every agent wore the Ymir mark. The choice is back, with the house's own characters instead of the upstream shapes.

## What changed

| Part | Change |
|---|---|
| Characters | The Ymir mark (the default) and fourteen figures of the lore: Huginn, Fenrir, Jörmungandr, Sleipnir, Ratatoskr, Hræsvelgr, Heiðrún, Eikþyrnir, Gullinbursti, Mjölnir, Gungnir, Skíðblaðnir, Sól and Máni |
| Artwork | game-icons.net silhouettes (CC BY 3.0, credited in `THIRD_PARTY_NOTICES.md`), drawn in the mark's bronze on its stone, with the agent's hue as the ring |
| Pickers | One `CharacterPicker`, used by "Seat a new agent" and by an agent's settings: three rows of five |
| Server | The new names are valid shapes; a new agent wears the mark unless one is chosen; an unknown shape or colour is refused with 400 instead of being written |
| Old agents | An agent saved with an upstream shape still shows the Ymir mark, as before |

## How it was proven

- Both `tsc` checks (web and server) pass.
- The working tree's face, served on a spare port against the running server, was opened in a throwaway signed-in
  browser: "Seat a new agent" shows 15 characters with no console error; choosing Huginn and a hue updates the
  preview; an agent's settings show the same 15. Nothing was saved to the live agents.

## Files

- `web/artwork/characters/*.svg`, `web/scripts/gen-characters.mjs`, `web/src/avatar/characters.gen.ts`
- `web/src/avatar/BotAvatar.tsx`, `web/src/avatar/CharacterPicker.tsx`
- `web/src/components/modals/CreateBotModal.tsx`, `web/src/components/config/BotSettingsModal.tsx`
- `server/src/types.ts`, `server/src/routes.ts`, `THIRD_PARTY_NOTICES.md`
