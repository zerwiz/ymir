# TOON output + tasks-cli (loaded from AGENTS.md)

AGENTS.md loads this when a task builds an agent-facing tool or uses tasks-cli.
Full doctrine: `.agents/skills/galdr-cli/assets/principles.md`.

## TOON output format

All Ymir tool output uses TOON (Token-Oriented Object Notation) for ~40% token
savings:

```
tasks[2]{id,title,state}:
  "1","Fix auth bug","open"
  "2","Add pagination","closed"
```

```
toon_rules[5]{rule,detail}:
  "Header","type[count]{field1,field2,...}:"
  "Rows","CSV-like, quoted strings"
  "Truncation","always show `(truncated, N chars total)`"
  "Empty states","`tasks: 0 closed tasks found` — never blank"
  "Errors","`error: <message>` + `help: <fix>` on stdout, exit 1 or 2"
```

Validate any TOON with `.agents/skills/galdr-cli/scripts/toon-check.py`.

## tasks-cli — AXI task manager

`.agents/tools/bin/tasks-cli`, a Python script following the AXI spec. Output is
TOON. Exit codes: 0=success, 1=error, 2=usage error.

```bash
python3 .agents/tools/bin/tasks-cli list
python3 .agents/tools/bin/tasks-cli list --state=open
python3 .agents/tools/bin/tasks-cli list --assignee=alice --limit=50
python3 .agents/tools/bin/tasks-cli view <id>
python3 .agents/tools/bin/tasks-cli view <id> --full
python3 .agents/tools/bin/tasks-cli create --title="Fix navbar"
python3 .agents/tools/bin/tasks-cli create --title="Add pagination" --body="Support page 2+"
python3 .agents/tools/bin/tasks-cli close <id>     # idempotent: already-closed = no-op, exit 0
```
