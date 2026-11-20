## Summary

<!-- What does this change, and why? -->

## Checklist

- [ ] I ran `bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh` and it passes.
- [ ] I ran `bin/secret-guard.sh --all` — no secrets introduced.
- [ ] No private data is added: `workspace/{work,personal,memory,companies}/`,
      `assets/reference/state/`, `.env.local`, `.env.realm` stay out of the tree.
- [ ] A change to a governed path is reflected in its Galdr asset
      (see `.agents/skills/galdr-ymirsystem/SKILL.md`).
- [ ] I recorded a fix note under `docs/fixes/<component>/` (`bin/fixes.sh record`) …
      or updated `docs/masterplan.md` where the change warrants it.

## Notes for reviewers

<!-- Anything risky, migration steps, or open questions. -->
