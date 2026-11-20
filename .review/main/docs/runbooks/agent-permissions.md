# Runbook — setting an agent's permissions

Every agent profile declares what it may do. Permissions are **law for that
agent** — set them deliberately. The default that ships is a starting point, not
a recommendation.

## Where permissions live

In the profile's frontmatter: `.agents/agents/<name>-<craft>.md`.

```yaml
---
name: kvasir
mode: subagent
permission:
  read: allow
  glob: allow
  grep: allow
  edit: deny
  write: deny
  bash:
    "*": ask            # everything else asks first
    "ls *": allow
    "rg *": allow
    "cat *": allow
    "git status*": allow
    "git diff*": allow
  skill: allow
  webfetch: deny
---
```

After editing, rebind:

```bash
bin/valknut-load.sh --all
```

## The one rule that matters most

**A flat `bash: allow` overrides every other restriction.** An agent with
`edit: deny` but `bash: allow` can still write files (`sed -i`, `cat > f`),
delete them, or reach the network (`curl`, `ssh`). `edit`/`write: deny` only
stops the *edit tool*, not the shell.

So: **never give a read-only agent a flat `bash: allow`.** Give it a **pattern
map** — only the read commands it needs are `allow`, everything else is `ask` or
`deny`.

## What each key does

| Key | Controls |
|-----|----------|
| `read` | reading files |
| `glob` / `grep` | finding files / searching content |
| `edit` | the edit tool (in-place changes) |
| `write` | creating/overwriting files |
| `bash` | the shell — `allow` is total; prefer a pattern map |
| `skill` | loading skills |
| `webfetch` / `websearch` | outbound network from tools |
| `task` | dispatching subagents |

Values: `allow`, `ask`, `deny`. `bash` may also be a map of command patterns.

## Recommended postures

```
postures[4]{role,read,edit/write,bash,notes}:
  "read-only (scout, researcher, reviewer)","allow","deny","pattern map: ls/rg/cat/git-status allow, \"*\": ask","never flat allow; no curl/wget/ssh"
  "builder (developer)","allow","allow","pattern map: package manager + build + git allow, \"*\": ask","the widest real need; still ask on unknown"
  "content (marketer)","allow","allow","* ask; allow the editor/crawl commands only","network only where the task truly needs it"
  "designer","allow","allow","* ask; allow the design CLI only","keep the shell narrow even when runnable"
```

## Modes

`mode:` decides how an agent can be reached:

- `primary` — run directly as a top-level agent.
- `subagent` — dispatched by another agent (Task tool).
- `all` — both. Widest; pair it with a narrow `bash`.

A runnable (`all`) agent with a full shell is the biggest door — usually not
what you want.

## Network and untrusted work

- Treat `curl`, `wget`, `ssh`, and arbitrary binaries as `ask` at least.
- Code you do not fully trust belongs in **Utgard** (no host root, no network),
  not on the host with a permissive shell.

## Check your posture

```bash
bin/perm-guard.sh          # flags a flat bash:allow, especially with edit/write denied
bin/valknut-load.sh --all  # rebind after edits
```

The rule of thumb: **grant the narrowest shell that does the job.**
