# The maestro skill's fix note moves under a real component

**Date:** 2026-10-31 · **Component:** skills · **Status:** moved, note kept

## What was wrong

`docs/fixes/maestro-video-skill/2026-10-24.md` sits under a component directory that is not one of
the house's components (`install · runtime · snotra · skills · agents · hlidskjalf · odrerir ·
sessrumnir · smidja · hoard · gate`), so the fixes gate refused the branch when it was pushed: a note
in a directory no component owns is a note the gate cannot read.

## The mend

The note's content is kept, not rewritten — it is referenced from here and stays beside the skill it
describes (`.agents/skills/maestro-video/`). This file is the component-owned entry that makes the
change visible to `bin/gates/fixes.sh`, and the branch's push is what proved the gate was right.

**Lesson:** a fix note's *directory* is part of the note. `docs/fixes/<component>/` where `<component>`
is a real component, or the gate cannot see what you wrote.
