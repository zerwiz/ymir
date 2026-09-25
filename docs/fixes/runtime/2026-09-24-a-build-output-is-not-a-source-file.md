## runtime · unversioned · 2026-09-24 — a build output is not a source file, and a local backup is not a repo file

### Why
A `git add -A` of mine swept two things into a commit that should not have carried either, and
for different reasons:

- **73 built visualizer files.** The build output is **deliberately un-ignored** so that npm packs
  it at `prepack` time (`bin/app-build.sh`), and it has **never been tracked** in this repository.
  Committing it would put a regenerated artifact under review forever, and every build would show
  as a diff.
- **One local `opencode.json` backup.** A local file, in a **public** repository. It carried no
  credentials (checked by field name and by value shape), but it does not belong.

### What
Both are untracked again, and the backup pattern is ignored so it cannot be swept a second time.

**And the rule that was broken, restated for the record:** stage **named paths, never a blanket
add.** That rule is written into the private home's ignore file, and I broke it inside the very
change whose subject is discipline. The ward that would have caught it is the one this branch adds:
`bin/runtime-guard.sh` declares what runtime output is allowed, and a blanket add defeats a
declaration by adding things it never declared.

### Files
- `.gitignore`
