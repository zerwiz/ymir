# docs · 2026-11-25 — the README shows the GitHub numbers beside the npm ones

**What was wrong.** The README's badge row showed npm downloads and the npm version, but not how many people starred
or forked the repository on GitHub.

**What changed.** `README.md`: a second badge row under the npm badges, in the same bronze (`c9973f`): GitHub stars,
GitHub forks, and a "Star on GitHub" link.

**Proof.** `grep -n "img.shields.io/github" README.md` names the two badges. The app repositories' READMEs carry no npm
downloads badge, so none was added there.
