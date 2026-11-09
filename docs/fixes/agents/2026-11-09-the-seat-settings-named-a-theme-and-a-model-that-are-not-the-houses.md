# The seat's settings said a theme and a model that are not the house's

**Date:** 2026-11-09 · **Component:** agents · **Door:** `.pi/settings.json` (project scope)

## What was wrong

The repo ships its own `.pi/settings.json`, and project scope outranks the operator's user
settings (`~/.pi/agent/settings.json`). It said:

```json
{ "defaultModel": "deepseek-v4-flash", "theme": "dark" }
```

Both were wrong for this house, and one was wrong in a way that hid itself:

- `theme: "dark"` is pi's **built-in** dark, not the Omarchy dark (`omarchy-system`) the Allfather
  keeps — so every agent started in a Ymir worktree came up in a theme that was not his.
- `deepseek-v4-flash` **is not in the catalogue**:

  ```
  $ bin/model/catalog.sh --has opencode-go/deepseek-v4-flash
    "opencode-go/deepseek-v4-flash","NOT IN THE CATALOG"
  ```

  A model the catalogue does not list is a refusal, and a refusal at `defaultModel` becomes a
  **fallback provider** at startup — which is why the seat kept arriving on an openrouter model
  no matter what the user settings said.

## What was forged

```json
{
  "defaultProvider": "opencode-go",
  "defaultModel": "deepseek-v4.1-flash",
  "theme": "omarchy-system",
  "packages": []
}
```

## Verified

```
$ bin/model/catalog.sh --has opencode-go/deepseek-v4.1-flash
  "opencode-go/deepseek-v4.1-flash","listed"
$ python3 -c 'json.load(open("~/.pi/agent/themes/omarchy-system.json"))'
  name: omarchy-system · background #121212 · foreground #bebebe
```

## Still open

Two code defaults in other components name the same unlisted id and are worth the same repair in
their own changes: `apps/hlidskjalf/server/index.ts:233` and
`apps/smidja-factory/apps/visualizer/server/chat.ts:189`.
