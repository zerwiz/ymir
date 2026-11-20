## runtime · 2026-09-24 · 2026-09-24 — eindri dispatch is trustworthy — never mute, machine-resolved, hard-isolated

### Why
On 2026-09-24 every fault that cost hours was a silence: the dispatcher died mute at rc=1 twice (ymir_volume_suffix returning 1 on non-SELinux hosts under set -e at line 40; the unguarded USERNS_FLAG substitution at einherjar-spawn.sh:41), so no Eindri could spawn with no message, no meta, and no worktree; isolation was decided by the presence of a file, not by a judgement; the dispatch template counted as ACTIVE and steered opencode against the fleet pi-only law; the backend fell to tmux while herdr server ran; the local-model lock was documented but never taken; worth-a-smith lived only in help text; a dead worker looked exactly like a thinking one.

### Files
- `bin/einherjar-spawn.sh`
- `bin/ymir-platform.sh`
- `bin/erindi-brief.sh`
- `bin/eindri-watch.sh`
- `bin/local-model-lock.sh`
- `bin/ymir-install.sh`
- `bin/dispatch-profile.sh`
- `bin/eindri-heartbeat.sh`
- `bin/eindri-acclaim-silent.sh`
- `.agents/skills/galdr-ymirsystem/assets/eindri-orchestration.md`
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`
- `.agents/skills/galdr-ymirsystem/assets/runtime-components.md`
- `.agents/skills/galdr-ymirsystem/assets/porting-upstream-to-norse.md`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`