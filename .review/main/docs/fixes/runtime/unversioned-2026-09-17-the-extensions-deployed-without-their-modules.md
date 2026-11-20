## runtime · unversioned · 2026-09-17 — the extensions deployed without their modules

### Why
- **pi would not start a seated worker, and the reason was a half-deploy.**
  The four shared pi extensions all reported
  `Failed to load extension: Cannot find module ./lib/<module>.ts` — and every one
  of those modules was present in the repo, one level away under the extensions'
  own `lib/`. The loader copied the top-level extension files and never their
  supporting modules.
- **Mended in two places.** (1) The missing modules are now beside the deployed
  extensions, so a running pi loads all four. (2) `bin/valknut-load.sh` — the
  loader — now deploys that lib alongside the extensions, idempotently (identical
  files untouched), so a fresh machine cannot hit it. A deploy that copies a file
  but not the module it imports is not a deploy.
- **What this cost:** the Forseti audit was seated on a **local** model, and the
  pane fell back to a bare shell when pi could not start — which is why the brief
  was typed at a prompt and answered `bash: syntax error near unexpected token '('`.
  With the extensions mended, pi's remaining blocker is the model: the llama-router
  has no raisable seat tonight (`:8080` unbound, and the installed llama.cpp cannot
  load the Apodex weights), so a local-first dispatch has nothing to reach.

### Files
- *(carried from the frozen CHANGELOG.md)*
