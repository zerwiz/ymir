# tasks — AXI-compliant Task Management CLI

An AXI-compliant task management tool following the Agent eXperience Interface specification.

## Installation

```bash
# Global install
npx -y @ywir/tasks@latest

# Or via npm
npm install @ywir/tasks
```

## AXI Compliance

This tool follows the **Agent eXperience Interface (AXI)** specification from Ymir Architecture.md #151:

- **Token-efficient output** via TOON (Token-Oriented Object Notation)
- **Minimal default schemas** (3-4 fields in lists, not 10)
- **Content truncation** with preview + `--full` escape hatch
- **Pre-computed aggregates** (counts included, not just page size)
- **Definitive empty states** — says "0 tasks found" explicitly
- **Structured errors on stdout** with exit codes (0=success, 1=error, 2=usage)
- **No interactive prompts** — all operations via flags alone
- **Content first** — shows live data, not usage manual
- **Contextual disclosure** — suggests next steps from current output
- **Consistent help** — `--help`, `--version`, executable path on stdout

## AXI Specification Reference

Per AXI spec §1: "Use TOON (Token-Oriented Object Notation) as the output format on stdout. TOON provides ~40% token savings over equivalent JSON while remaining readable by agents. Convert to TOON at the output boundary — keep internal logic on JSON."

Per AXI spec §10: "$ tasks bin: ~/.local/bin/tasks description: Manage project tasks in the current workspace"

## TOON Output Format

All stdout output uses TOON (Token-Oriented Object Notation):

```text
tasks[3]{id,title,state}:
  "1",Fix auth bug,open
  "2",Add pagination,open
  "3",Update docs,closed
```

## Usage

```bash
# List tasks
tasks list

# List with state filter
tasks list --state open

# View task detail (truncated body preview)
tasks view 42

# View task full body
tasks view 42 --full

# Create a task
tasks create --title "Fix auth bug" --body "User reports login failure"

# Close a task (no-op if already closed — exit 0)
tasks close 42
```

## TOON Format Details

**List schema** (3-4 fields default, not 10):
```text
tasks[2]{id,title,state}:
  "1",Fix auth bug,open
```

**Task detail** (truncated body with total size):
```text
task:
  number: 42
  title: Fix auth bug
  state: open
  body: First 500 chars of the issue body...
    ... (truncated, 8432 chars total)
help[1]: Run `tasks view 42 --full` to see complete body
```

**Empty state** (definitive):
```text
tasks: 0 closed tasks found in this repository
```

**Structured errors on stdout**:
```text
error: --title is required
help: tasks create --title "..." [--body "..."]
```

**Exit codes**:
- `0` = success (including no-ops: `task already closed`)
- `1` = error
- `2` = usage error (unknown flag, missing required flag)

## AXI Rules Compliance

### Rule 1 — Token-efficient output
- All output uses TOON format
- Internal logic stays on JSON; TOON at output boundary
- ~40% token savings over equivalent JSON

### Rule 2 — Minimal default schemas
- List shows 3 fields: id, title, state
- Default limit: 100 (covers most repos in one call)
- `--fields` flag lets agents request additional fields
- Bodies/tr descriptions omitted from lists

### Rule 3 — Content truncation
- Body preview: first 500 chars + "(truncated, N chars total)"
- Total size always shown so agent knows how much is missing
- `--full` escape hatch for complete body
- Never omit large fields entirely

### Rule 4 — Pre-computed aggregates
- Count always included: "30 of 847 total"
- Derived status inline when cheap: "checks: 3/3 passed"
- Comments: "7" (not full comment list)

### Rule 5 — Definitive empty states
```text
tasks: 0 closed tasks found in this repository
```
- States the zero with context
- Clear the command succeeded — absence of results is the answer

### Rule 6 — Structured errors & exit codes
- Errors on stdout in structured format
- No interactive prompts — all via flags
- Fail loud on unrecognized input: `error: unknown flag --stat for \`list\``
- Per-subcommand flag sets validated independently
- Error self-correcting in one turn: inline --help listed

### Rule 7 — Ambient context via session integrations
- Session hook registers tool into agent's session lifecycle
- At session start, tool provides compact dashboard as context
- Portable commands using PATH-verified binary name
- Idempotent: repeated installs silent no-ops
- Directory-scoped: shows only state relevant to CWD
- Token-budget-aware: ruthlessly minimize context

### Rule 8 — Content first
- Running with no arguments shows live data, not manual
```text
tasks
tasks[3]{id,title,state}:
  1,Fix auth bug,open
  2,Add pagination,open
  3,Update docs,closed
```
- help text secondary

### Rule 9 — Contextual disclosure
- After open item → suggest closing
- After empty list → suggest creating
- After list → suggest viewing
- Relevant + actionable suggestions with placeholders: `<id>`, `<title>`
- Omit when self-contained (detail view has full answer)
- Reveal truncated lists: `Run 'tasks list' for all 47 items`

### Rule 10 — Consistent way to get help
```text
$ tasks
bin: ~/.local/bin/tasks
description: Manage project tasks in the current workspace
```
- Identifies executable path, collapsed home dir to ~
- One-sentence description
- `--help` on every subcommand with concise reference
- `-V`, `--version` prints bare version, exits 0
- Version in leaf module importing only node builtins
- `tryFastPath` pattern: version check before heavy graph loads

## Development

```bash
# Run development mode
npx tasks

# Build
npm run build

# Test
npm test
```

## AXI Skill Integration

This tool can be registered as an OpenCode skill:

```bash
npx skills add @ywir/tasks --skill tasks
```

Or as a session hook in `~/.config/opencode/plugins/`:
```json
{
  "name": "tasks-axi-hook",
  "activate": ["tasks"],
  "provides": ["task_list", "task_view", "task_create", "task_close"]
}
```

The session hook is the primary integration (ambient context + live state), while the skill is secondary (lower overhead, broader agent support). Both are complementary.

## License

MIT — see LICENSE file.