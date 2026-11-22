---
name: veil-arm
description: Report finished work to the arm holder with an id and get a RECEIVED back, or answer a steer — the Veil's arm contract (bin/agents/veil.sh). Use from any agent, Hermes included.
---

# The Veil's arm contract

Use this skill when you have finished something and must tell the arm holder, or when a line you
received starts with `[veil <id>] steer:`.

## Report your work

Run this from the Ymir runtime (`~/ymir-runtime`), or from the Ymir repository:

```bash
bin/agents/veil.sh send --from "<who you are>" --reply-to "<where you can be reached>" "<what you built> — proof: <the command you ran and what it printed>"
```

- `--reply-to` names your own road, so the RECEIVED comes back to you. Use `hermes:<your session id>`
  in Hermes, or your herdr pane id (`w12:p1`) in a pane.
- The command prints an id, such as `veil-1795317563-9524`.
- The arm holder answers **RECEIVED** within 2 minutes, and later **ACCEPTED** or **REWORK**.
- Check where it stands: `bin/agents/veil.sh status <id>`. Block on it: `bin/agents/veil.sh wait <id>`.

A report states what was proven, and how. "Fixed" without the command that proves it is not a report.

## Answer a steer

A steer arrives as `[veil <id>] steer: <the line>`. Say you have it first, then do the work:

```bash
bin/agents/veil.sh received <id> --by "<who you are>"
```

## If you hold the arm

Answer every report: `bin/agents/veil.sh received <id>`, then `accepted <id>` or
`rework <id> "<why>"`. See what is waiting with `bin/agents/veil.sh pending`. A report with no
answer is typed into your pane after 2 minutes, and turns red in the trouble panel after 10.
