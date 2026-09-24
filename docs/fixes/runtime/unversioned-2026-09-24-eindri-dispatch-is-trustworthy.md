## runtime · unversioned · 2026-09-24 — eindri dispatch is trustworthy — never mute, machine-resolved, hard-isolated

### Why
On 2026-09-24 every fault that cost hours was a silence: the dispatcher died mute at rc=1 twice (ymir_volume_suffix returning 1 on non-SELinux hosts under set -e at line 40, and the unguarded USERNS_FLAG substitution at einherjar-spawn.sh:41), so NO Eindri could spawn on heimdall with no message, no meta, and no worktree. Isolation was decided by whether a file existed instead of by a judgement; the dispatch template's <your-model-id> placeholders counted as ACTIVE and steered opencode against the fleet's pi-only law; --backend fell to tmux while herdr server ran; the local-model lock was documented but never taken; worth-a-smith lived only in herdr-run's help; a dead worker looked exactly like a thinking one.

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
