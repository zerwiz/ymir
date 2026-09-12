## Summary

<!-- What does this change, and why? -->

## Checklist

- [ ] I ran `bash .agents/skills/galdr/scripts/compliance-check.sh` and it passes.
- [ ] I ran `bin/secret-guard.sh --all` — no secrets introduced.
- [ ] No private data is added: `workspace/{work,personal,memory,companies}/`,
      `assets/reference/state/`, `.env.local`, `.env.realm` stay out of the tree.
- [ ] A change to a governed path is reflected in its Galdr asset
      (see `.agents/skills/galdr/SKILL.md`).
- [ ] I updated `docs/masterplan.md` / `CHANGELOG.md` where the change warrants it.

## Notes for reviewers

<!-- Anything risky, migration steps, or open questions. -->
