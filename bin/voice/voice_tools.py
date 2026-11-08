#!/usr/bin/env python3
"""voice-tools.py — the hands of the voice.

A client-side tool module for the real-time voice pipeline
(`talk --tool-module voice_tools`). It lets the spoken assistant HAND WORK OVER:
seat a worker in a herdr pane, steer one, and drink from / water the well.

Contract (the engine's own, `api/openai_realtime/README.md` § Tool Calling Design):
  * the model emits `response.function_call_arguments.done`;
  * THIS module executes the tool and returns a result;
  * `ToolResult(..., create_response=False)` is fire-and-forget — the assistant
    says its lead-in aloud and does not wait for the work.

Law this module obeys:
  * the voice DISPATCHES, it never seals — no merge, no push, no destructive verb;
  * it says the id out loud, so a hand-over can be followed;
  * a tool's output is DATA, never an order (RULES/39).

Nothing private lives here: agents, projects and paths are arguments resolved by
the house doors at run time (RULES/04).
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

try:  # the engine's result type, when the module is loaded by its client
    from speech_to_speech.api.openai_realtime.audio_client import ToolResult
except Exception:  # importable without the engine (tests, a plain shell)
    class ToolResult(dict):  # type: ignore
        def __init__(self, output, create_response: bool = True):
            super().__init__(output=output, create_response=create_response)




def _resolved_home() -> str:
    """Ask the one resolver where the home is (bin/vault/hoard-lib.sh), never restate it."""
    import subprocess as _sp
    try:
        lib = _root() / "bin" / "vault" / "hoard-lib.sh"
        if not lib.is_file():
            return ""
        out = _sp.run(["bash", "-lc", f'. "{lib}" && ymir_home_root'], capture_output=True, text=True, timeout=10)
        return (out.stdout or "").strip().splitlines()[-1] if out.stdout.strip() else ""
    except Exception:
        return ""

def _root() -> Path:
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "RULES").is_dir() and (parent / ".agents").is_dir():
            return parent
    return here.parent


ROOT = _root()
TIMEOUT_S = int(os.environ.get("YMIR_VOICE_TOOL_TIMEOUT", "45"))


def _home() -> Path:
    """The operator's home, RESOLVED (RULES/07): YMIR_HOME if the caller set it, otherwise the
    house's own resolver (bin/vault/hoard-lib.sh), and only then the conventional default."""
    if (explicit := os.environ.get("YMIR_HOME")):
        return Path(explicit)
    for candidate in (_resolved_home(), str(Path.home() / "Documents" / "ymirhome")):   # allow-home-default: the training-wheel default, used only when the resolver answers nothing
        if candidate and (Path(candidate) / "hodd").is_dir():
            return Path(candidate)
    return Path(os.environ.get("YMIR_VOICE_STATE", str(Path.home())))


def _log(event: str, **fields) -> None:
    """One line per thing the voice DID, so the Allfather can read what it has done:
    tool calls, memory retrievals, refusals — appended, never rewritten (Rule 06)."""
    import datetime
    stamp = datetime.datetime.now()
    path = _home() / "hodd" / "state" / "voice" / f"activity-{stamp:%Y-%m-%d}.jsonl"
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        row = {"ts": stamp.isoformat(timespec="seconds"), "event": event, **fields}
        with path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    except Exception:
        pass  # a log that cannot be written must never break the voice


def _run(argv: list[str], timeout: int = TIMEOUT_S) -> tuple[int, str]:
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, cwd=str(ROOT))
    except FileNotFoundError:
        return 127, f"missing door: {argv[0]}"
    except subprocess.TimeoutExpired:
        return 124, f"timed out after {timeout}s"
    out = (p.stdout or "") + (p.stderr or "")
    return p.returncode, out.strip()


def _detach(argv: list[str], log_name: str) -> str:
    """Run a door in its OWN session, so the voice client neither waits on it nor dies
    with it. The pane it seats belongs to herdr, not to this process."""
    import datetime
    stamp = datetime.datetime.now().strftime("%Y%m%dT%H%M%S")
    log = Path(os.environ.get("YMIR_VOICE_STATE", str(ROOT / "state"))) / f"{log_name}-{stamp}.log"
    try:
        log.parent.mkdir(parents=True, exist_ok=True)
        fh = open(log, "ab")
        subprocess.Popen(argv, stdout=fh, stderr=fh, stdin=subprocess.DEVNULL,
                         start_new_session=True, cwd=str(ROOT))
        return str(log)
    except Exception as exc:  # a refused dispatch must be said, never swallowed
        return f"detach failed: {exc}"


def _clean(text: str, limit: int = 400) -> str:
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    return " · ".join(lines)[:limit]


def _door(name: str) -> str:
    return str(ROOT / "bin" / name)


def _role_for(agent: str) -> str:
    """A spoken figure name (sindri) is mapped to its role id (developer) from the
    decision table, never guessed in code: .agents/roles.yaml is the data (RULES/07)."""
    agent = (agent or "").strip().lower()
    table = ROOT / ".agents" / "roles.yaml"
    if agent and table.is_file():
        role, fig = None, None
        try:
            for line in table.read_text(errors="ignore").splitlines():
                s = line.rstrip()
                if s.startswith("  ") and not s.startswith("    ") and s.strip().endswith(":"):
                    role = s.strip()[:-1]
                elif role and s.strip().startswith("figure:"):
                    fig = s.split(":", 1)[1].strip()
                    if fig.lower() == agent:
                        return role
        except Exception:
            pass
    return agent


TOOLS = [
    {
        "type": "function",
        "name": "pane_read",
        "description": "Read the last lines of a worker's terminal pane — what it is doing right now.",
        "parameters": {"type": "object", "properties": {
            "errand": {"type": "string", "description": "the errand id or pane id"},
            "lines": {"type": "integer", "description": "how many lines (default 20)"}},
            "required": ["errand"], "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "draft_write",
        "description": "Write a draft for the Allfather (email, letter, proposal) into his own shelf. It sends nothing.",
        "parameters": {"type": "object", "properties": {
            "title": {"type": "string"}, "body": {"type": "string"},
            "to": {"type": "string", "description": "who it is addressed to"}},
            "required": ["title", "body"], "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "home_recent",
        "description": "What the house has written lately — files changed in the last N hours, newest first.",
        "parameters": {"type": "object", "properties": {
            "hours": {"type": "integer"}, "match": {"type": "string"}},
            "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "last_session",
        "description": "The conversation before this one — the previous voice session's turns and the tools used.",
        "parameters": {"type": "object", "properties": {
            "turns": {"type": "integer"}}, "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "search_sessions",
        "description": "Search EVERY past voice session for a word or phrase, with the time each match was said.",
        "parameters": {"type": "object", "properties": {
            "query": {"type": "string"}, "limit": {"type": "integer"}},
            "required": ["query"], "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "todo_add",
        "description": "Add a task to the todo ledger; returns its short id. Optional due, priority, project.",
        "parameters": {"type": "object", "properties": {
            "item": {"type": "string"}, "due": {"type": "string"},
            "priority": {"type": "string"}, "project": {"type": "string"}},
            "required": ["item"], "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "todo_list",
        "description": "The todo ledger: open tasks with ids, due dates and priorities — or the done ones.",
        "parameters": {"type": "object", "properties": {
            "status": {"type": "string"}, "project": {"type": "string"}},
            "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "todo_done",
        "description": "Mark a todo done by its id or by words that match one item.",
        "parameters": {"type": "object", "properties": {"id": {"type": "string"}},
                       "required": ["id"], "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "todo_reopen",
        "description": "Put a done task back on the open list.",
        "parameters": {"type": "object", "properties": {"id": {"type": "string"}},
                       "required": ["id"], "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "todo_update",
        "description": "Change a task's due date, priority, project or wording.",
        "parameters": {"type": "object", "properties": {
            "id": {"type": "string"}, "due": {"type": "string"}, "priority": {"type": "string"},
            "project": {"type": "string"}, "item": {"type": "string"}},
            "required": ["id"], "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "hand_over",
        "description": (
            "Hand the Allfather's request to a worker agent and seat it in a herdr pane. "
            "Use when he asks for something to be built, checked, researched or executed. "
            "Say out loud that you are sending it before calling this."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "agent": {
                    "type": "string",
                    "description": "the worker's craft, e.g. sindri (code), bragi (marketing), huginn (research)",
                },
                "task": {"type": "string", "description": "the brief, in the Allfather's own words, one or two sentences"},
                "name": {"type": "string", "description": "a short kebab-case errand id; omit to derive one"},
                "confirm": {"type": "boolean", "description": "TRUE only after the Allfather has said yes out loud. Never on the first call."},
            },
            "required": ["agent", "task"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "gimle",
        "description": (
            "Gimlé — the house's collaboration suite — through its own MCP: places (workspaces), tasks assigned "
            "to him, a place's board, a meeting's record, who owes what, documents (AFFiNE) and scenes "
            "(Excalidraw). Read-only. Use when he asks about Gimlé, the board, a place, or a partner's tasks."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "tool": {"type": "string", "description": "one of: projects · who_am_i · list_places · my_tasks · place_board · meeting_record · who_owes_what · find_doc · read_scene · list"},
                "arguments": {"type": "object", "description": "that tool's own arguments — for `projects`: {workspace} to filter, or {assigned: true, person} to group his own tasks by project"},
            },
            "required": ["tool"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "plan_write",
        "description": (
            "Write the plan BEFORE any work is sent: the numbered steps you would hand to a worker, saved in the "
            "home so he can read it back, amend it, and approve it. Use for any request with more than one step."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "a short title, e.g. 'Control Tower architecture with Craig'"},
                "steps": {"type": "array", "items": {"type": "string"}, "description": "the numbered steps, one action each"},
                "agent": {"type": "string", "description": "who would do it (sindri, bragi, huginn …)"},
            },
            "required": ["title", "steps"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "context_left",
        "description": (
            "How much conversation the head is carrying: the tokens of the last turn, the window the model holds, "
            "and how many turns until the engine compacts. Use it when a task needs a long conversation, or before "
            "planning something multi-step, so you can summarise early instead of being cut off."
        ),
        "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "errand_state",
        "description": (
            "Ask how a worker's errand is going: its claimed state, its durable checkpoint and whether its pane "
            "is still alive. Use whenever he asks 'is Sindri done?', 'what happened to that errand?', or before "
            "reporting on work he sent out. Omit `id` to see every errand this seat knows."
        ),
        "parameters": {
            "type": "object",
            "properties": {"id": {"type": "string", "description": "the errand id; omit for all"}},
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "steer_worker",
        "description": "Send one line to a worker that is already seated, to correct or extend its errand.",
        "parameters": {
            "type": "object",
            "properties": {
                "target": {"type": "string", "description": "the worker's name or herdr pane, as it was seated"},
                "line": {"type": "string", "description": "one line of instruction"},
            },
            "required": ["target", "line"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "search_home",
        "description": (
            "Search the Allfather's own home (his documents, notes, plans and todo) for a phrase. "
            "Use this whenever he asks about his own files, notes, plans or lists."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "the words to look for"},
                "area": {"type": "string", "description": "a shelf under hodd/, e.g. life/personal (default: all of hodd)"},
            },
            "required": ["query"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "read_home_file",
        "description": "Read one text file from the Allfather's home (never the vault, never a secret).",
        "parameters": {
            "type": "object",
            "properties": {"path": {"type": "string", "description": "path relative to hodd/, e.g. life/personal/me/todo.md"}},
            "required": ["path"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "read_mail",
        "description": (
            "Read the Allfather's recent mail (read-only: this door can never send, reply or delete). "
            "Use when he asks what is new, what needs an answer, or what came in."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "hours": {"type": "integer", "description": "how far back to look (default 72)"},
                "max": {"type": "integer", "description": "how many messages (default 8)"},
                "scope": {"type": "string", "description": "inbox (default) · sent · drafts · all"},
            },
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "read_calendar",
        "description": (
            "Read the Allfather's Google calendar (what is coming, or when a meeting fits). "
            "Use when he asks about his day, his meetings, or whether a time is free."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "what": {"type": "string", "description": "'what' is coming (default) or 'free' for a free slot"},
                "minutes": {"type": "integer", "description": "meeting length, only for 'free' (default 30)"},
            },
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "read_board",
        "description": (
            "Read the Trello board (cards, lists, what is assigned). Read-only. "
            "Use when he asks what is on the board, in Trello, or on a project's cards."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "words to look for on the board (optional)"},
            },
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "calendar_respond",
        "description": (
            "Answer a calendar invitation: accept, decline or mark tentative, for the next matching event. "
            "Use when he says to accept or decline a meeting he was invited to."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "event": {"type": "string", "description": "words from the invitation's title, or its id"},
                "response": {"type": "string", "description": "accepted (default) · declined · tentative"},
            },
            "required": ["event"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "add_todo",
        "description": "Append one item to the voice's todo list beside his (hodd/life/personal/me/todo-voice.md); his own todo.md is written by him alone.",
        "parameters": {
            "type": "object",
            "properties": {"item": {"type": "string", "description": "the task, in his own words"}},
            "required": ["item"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "recall",
        "description": (
            "Drink from the house's memory (the well) before answering a question about past work, "
            "decisions or preferences. Returns short remembered facts."
        ),
        "parameters": {
            "type": "object",
            "properties": {"query": {"type": "string", "description": "what to remember, in words"}},
            "required": ["query"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "remember",
        "description": "Water the well with a durable lesson or decision from this conversation.",
        "parameters": {
            "type": "object",
            "properties": {"note": {"type": "string", "description": "the claim, in one or two sentences"}},
            "required": ["note"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "ls",
        "description": "List a directory — in your own documents, the home or the Ymir tree. Never the secrets shelf.",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "a path, home-relative such as hodd/docs, or absolute"},
                "all": {"type": "boolean", "description": "include dotfiles"},
            },
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "read",
        "description": "Read a file with line control (from/lines). For his notes, plans, code and ledgers.",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string"},
                "from": {"type": "integer", "description": "first line (1-based)"},
                "lines": {"type": "integer", "description": "how many lines to read"},
            },
            "required": ["path"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "edit",
        "description": (
            "Write a file: whole-file `content`, or one occurrence `old` -> `new`. It changes things, so it "
            "asks him out loud first: call WITHOUT confirm, ask, then call again with confirm=true."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string"},
                "content": {"type": "string", "description": "the whole new file body"},
                "old": {"type": "string", "description": "text to replace (one occurrence)"},
                "new": {"type": "string", "description": "replacement text"},
                "confirm": {"type": "boolean", "description": "true only after he says yes out loud"},
            },
            "required": ["path"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "bash",
        "description": (
            "Run a shell command on this seat from the Ymir tree. Ask him out loud first (no confirm, then "
            "confirm=true). Never for secrets, force-push, merge, sudo, or anything destructive — those are refused."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "command": {"type": "string"},
                "cwd": {"type": "string", "description": "working directory (default the Ymir tree)"},
                "timeout": {"type": "integer", "description": "seconds (max 300)"},
                "confirm": {"type": "boolean", "description": "true only after he says yes out loud"},
            },
            "required": ["command"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "mcp_tools",
        "description": "List the MCP servers this seat can reach, or one server's tools (chrome-devtools, gimle, well, trello …).",
        "parameters": {
            "type": "object",
            "properties": {"server": {"type": "string", "description": "a server name; omit to list them all"}},
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "mcp",
        "description": (
            "Call one tool on an MCP server — the browser (chrome-devtools), the board, the well, Gimle and the "
            "rest. Read-only tools run at once; anything that can change state asks him out loud first."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "server": {"type": "string"},
                "tool": {"type": "string"},
                "args": {"type": "object", "description": "the tool's own arguments"},
                "confirm": {"type": "boolean", "description": "true only after he says yes out loud"},
            },
            "required": ["server", "tool"],
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "cron_jobs",
        "description": (
            "The house's schedule (Nornir cron): whether the scheduler is running, every job and its "
            "hour, what last fired, and the log's last lines. Use it for 'are the cron jobs running' "
            "or 'what is scheduled'. Read-only."
        ),
        "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "type": "function",
        "name": "plans",
        "description": (
            "The plan ledger. A PLAN is not an ERRAND: plans are numbered design records in the home. "
            "Call with no arguments to list them, with `query` to find the ones about a subject, or "
            "with `number` to read one."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "a word or subject to find in the ledger"},
                "number": {"type": "string", "description": "a plan number, e.g. 132"},
            },
            "additionalProperties": False,
        },
    },
    {
        "type": "function",
        "name": "research",
        "description": (
            "Send Huginn (the raven) to research a question on the web and write a sourced report "
            "into the home. It seats a worker, so it needs his spoken yes first: call WITHOUT "
            "confirm, ask him out loud, then call again with confirm=true and the same question."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "question": {"type": "string", "description": "the question to research, in his words"},
                "confirm": {"type": "boolean", "description": "true only after he says yes out loud"},
            },
            "required": ["question"],
            "additionalProperties": False,
        },
    },
]


CREATE_RESPONSE = True  # a plain return value is spoken back unless overridden per call


async def _execute(name, arguments):
    args = arguments or {}

    impl = NEW_TOOLS.get(name)
    if impl is not None:
        return await impl(args)

    if name == "hand_over":
        agent = str(args.get("agent", "")).strip()
        task = str(args.get("task", "")).strip()
        if not agent or not task:
            raise ValueError("hand_over needs an agent and a task")
        errand = str(args.get("name", "")).strip() or f"voice-{abs(hash(task)) % 10**6:06d}"
        role = _role_for(agent)

        # THE ALLFATHER'S RULE (2026-11-07): no worker is sent out on a spoken word alone.
        # First call: remember the errand and ask him. Second call with confirm=true: send it.
        pending_path = _home() / "hodd" / "state" / "voice" / "pending-handover.json"
        if not args.get("confirm"):
            try:
                pending_path.parent.mkdir(parents=True, exist_ok=True)
                pending_path.write_text(json.dumps(
                    {"agent": agent, "role": role, "task": task, "errand": errand,
                     "asked_at": __import__("datetime").datetime.now().isoformat(timespec="seconds")}))
            except Exception:
                pass
            _log("handover.awaiting_confirmation", agent=agent, errand=errand, task=task[:160])
            return ToolResult(
                f"NOT SENT. Ask him out loud, in one short sentence: \"Shall I send this to {agent}?\" "
                f"Only if he says yes, call hand_over again with confirm=true and the same agent and task.",
                create_response=True)
        try:
            pending = json.loads(pending_path.read_text())
        except Exception:
            pending = {}
        if (pending.get("agent") != agent) or (pending.get("task") != task):
            _log("handover.refused_no_pending", agent=agent, task=task[:160])
            return ToolResult(
                f"Do NOT send to {agent}: nothing was confirmed. Ask him first, then call again.",
                create_response=True)
        errand = pending.get("errand") or errand
        try:
            pending_path.unlink()
        except Exception:
            pass
        _log("handover.confirmed", agent=agent, errand=errand)
        log = _detach([_door("agents/eindri-seat.sh"), errand, "--role", role, "--", task],
                      f"handover-{errand}")
        # the hand-over runs in its own session; the voice says the id aloud and keeps the chat
        return ToolResult(
            f"Sent to {agent} as errand {errand}. Its seat and log: {log}. "
            "Say that out loud in one short sentence.",
            create_response=True,
        )



    if name == "gimle":
        import base64, json as _json
        tool = str(args.get("tool") or "list").strip()
        arguments = args.get("arguments") or {}
        heart = str(os.environ.get("YMIR_VOICE_GIMLE_HOST") or "").strip()
        if not heart:
            try:
                heart = str(_json.loads((_home() / "hodd" / "data" / "fleet.json").read_text()).get("heart") or "")
            except Exception:
                heart = ""
        if not heart:
            return ToolResult("No heart seat is known, so Gimlé's MCP cannot be reached.")
        if tool == "my_tasks":
            # The MCP's `my_tasks` reads its own place record and answers 0 while the Plane board holds
            # nine cards for this person. The board is the truth; answer from it and say so.
            tool = "projects"
            arguments = {"assigned": True, "person": arguments.get("person") or os.environ.get("YMIR_VOICE_PERSON") or _operator_handle()}

        if tool == "projects":
            snippet_pr = (
                "import sys, json,os,urllib.request\n"
                f"assigned={bool(arguments.get('assigned'))!r}\n"
                f"person={str(arguments.get('person') or os.environ.get('YMIR_VOICE_PERSON') or _operator_handle())!r}\n"
                "if assigned:\n"
                "    sys.path.insert(0, os.path.expanduser('~/ymir/bin/gimle')); import plane_reader as pr\n"
                "    cards, detail = pr.board_for(person, 60)\n"
                "    from collections import Counter\n"
                "    tally = Counter(str(c.get('project','(none)')) for c in cards)\n"
                "    print(detail)\n"
                "    for proj, n in tally.most_common(): print('  %s: %d task(s)' % (proj, n))\n"
                "    raise SystemExit(0)\n"
                "tok=open(os.path.expanduser('~/gimle/desk/etc/plane-token')).read().strip()\n"
                "base='http://127.0.0.1:8099'\n"
                "def get(p):\n"
                "    r=urllib.request.Request(base+p, headers={'X-Api-Key':tok})\n"
                "    return json.loads(urllib.request.urlopen(r, timeout=20).read())\n"
                "def rows(d): return d if isinstance(d,list) else d.get('results',[])\n"
                "slugs=[s for s in os.environ.get('GIMLE_PLANE_WORKSPACES','wayof,opticat,synteon,whynotproductions,ymirhome').split(',') if s]\n"
                f"want=str({str(arguments.get('workspace') or '')!r}).lower()\n"
                "total=0\n"
                "for slug in slugs:\n"
                "    if want and want not in slug: continue\n"
                "    try: pr=rows(get('/api/v1/workspaces/%s/projects/?per_page=50' % slug))\n"
                "    except Exception as e: print('  %s: failed (%s)' % (slug, e.__class__.__name__)); continue\n"
                "    total+=len(pr)\n"
                "    print('  %s: %d project(s): %s' % (slug, len(pr), ', '.join((p.get('identifier','')+' · '+(p.get('name','') or '')[:30]) for p in pr)))\n"
                "print('total projects:', total)\n"
            )
            b64pr = base64.b64encode(snippet_pr.encode()).decode()
            code, out = _run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", heart,
                              f"echo {b64pr} | base64 -d | python3 -"], timeout=90)
            if code != 0 and not out.strip():
                return ToolResult("Plane did not answer on the heart; say so plainly.")
            return ToolResult("Gimlé · projects (Plane, read on the heart):\n" + _clean(out, 1400))

        snippet = (
            "import json,os,urllib.request\n"
            "toks=[l.split()[0] for l in open(os.path.expanduser('~/gimle/desk/etc/mcp-tokens')) if l.strip()]\n"
            f"tool={tool!r}\n"
            f"arguments={_json.dumps(arguments)!r}\n"
            "def call(method, params=None):\n"
            "    body=json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params or {}}).encode()\n"
            "    req=urllib.request.Request('http://127.0.0.1:8489/mcp', data=body, headers={\n"
            "        'Content-Type':'application/json','Accept':'application/json, text/event-stream',\n"
            "        'Authorization':'Bearer '+toks[0]})\n"
            "    with urllib.request.urlopen(req, timeout=25) as r:\n"
            "        return json.loads(r.read())\n"
            "if tool == 'list':\n"
            "    out = call('tools/list')\n"
            "    print('tools:', [t['name'] for t in out.get('result',{}).get('tools',[])])\n"
            "else:\n"
            "    out = call('tools/call', {'name': tool, 'arguments': json.loads(arguments)})\n"
            "    res = out.get('result', {})\n"
            "    text = ' '.join(c.get('text','') for c in res.get('content',[]) if isinstance(c, dict))\n"
            "    print(text[:1600] or json.dumps(res)[:1600])\n"
        )
        b64 = base64.b64encode(snippet.encode()).decode()
        code, out = _run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", heart,
                          f"echo {b64} | base64 -d | python3 -"], timeout=90)
        if code != 0 and not out.strip():
            return ToolResult("Gimlé's MCP did not answer on the heart; say so plainly.")
        return ToolResult(f"Gimlé · {tool}:\n" + _clean(out, 1500))


    if name == "plan_write":
        import datetime as _dt
        title = str(args.get("title") or "plan").strip()
        steps = [str(x).strip() for x in (args.get("steps") or []) if str(x).strip()]
        agent = str(args.get("agent") or "").strip()
        if not steps:
            raise ValueError("plan_write needs at least one step")
        plan_dir = _home() / "hodd" / "state" / "voice" / "plans"
        plan_dir.mkdir(parents=True, exist_ok=True)
        slug = "".join(ch.lower() if ch.isalnum() else "-" for ch in title)[:40].strip("-") or "plan"
        path = plan_dir / f"{_dt.datetime.now():%Y%m%dT%H%M%S}-{slug}.md"
        body = [f"# {title}", "", f"**written** {_dt.datetime.now():%Y-%m-%d %H:%M} · **by** Rödd (voice)",
                f"**for** {agent or 'unassigned'}", "", "## Steps", ""]
        body += [f"{i}. {step}" for i, step in enumerate(steps, 1)]
        body += ["", "## Approval", "", "Written by the voice, approved by the Allfather before any worker is sent."]
        path.write_text("\n".join(body) + "\n", encoding="utf-8")
        _log("plan.written", title=title, steps=len(steps), agent=agent, path=str(path))
        spoken = "; ".join(f"{i}) {step}" for i, step in enumerate(steps, 1))
        return ToolResult(
            f"Plan saved to {path}. Read it back to him in one sentence: {spoken}. "
            "Then ask him to approve or amend it — send nothing until he approves the STEPS, not just the idea.")


    if name == "context_left":
        import json as _json
        import re as _re
        candidates = []
        seat = str(os.environ.get("YMIR_VOICE_HOST_SEAT") or "").strip()
        if seat:
            candidates.append(seat)
        try:
            fleet = _json.loads((_home() / "hodd" / "data" / "fleet.json").read_text())
            candidates += [h for h in (fleet.get("ear") or []) if h not in candidates]
            if fleet.get("heart") and fleet["heart"] not in candidates:
                candidates.append(fleet["heart"])
        except Exception:
            pass
        heart = ""
        chat_size = int(os.environ.get("YMIR_VOICE_CHAT_SIZE", "12"))
        remote = (
            'h=$(bash -lc ". ~/ymir/bin/vault/hoard-lib.sh >/dev/null 2>&1; ymir_home_root YMIR_HOME >/dev/null 2>&1; printf %s \"\\$YMIR_HOME\"" 2>/dev/null); d="$h/hodd/state/voice/host.log"; '
            'tail -n 400 "$d" 2>/dev/null | grep -o "Token usage (response):[^,]*" | tail -1; '
            "awk '/Client session_/{c=0} /USER:/{c++} END{print c+0}' \"$d\" 2>/dev/null"
        )
        code, out = 1, ""
        for candidate in candidates or ([heart] if heart else []):
            code, out = _run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", candidate, remote], timeout=40)
            if code == 0 and "Token usage" in (out or ""):
                heart = candidate
                break
        last_input, turns = None, None
        if code == 0 and out:
            m = _re.search(r"input=(\d+)", out)
            last_input = int(m.group(1)) if m else None
            nums = [int(x) for x in _re.findall(r"^\s*(\d+)\s*$", out, _re.M)]
            turns = nums[0] if nums else None
        parts = []
        if last_input is not None:
            parts.append(f"last turn carried {last_input} tokens")
        if turns is not None:
            parts.append(f"{turns} user turns have been spoken in this session")
        parts.append(f"the engine keeps {chat_size} turns, then summarises older ones in the background (compaction is on)")
        if last_input:
            parts.append("at roughly a thousand tokens a turn, plan to summarise or save a plan by the "
                         f"{max(1, chat_size - 2)}th turn")
        if not parts:
            return ToolResult("No session log could be read; assume the window is small and summarise early.")
        return ToolResult("Context: " + "; ".join(parts) + ".")

    if name == "errand_state":
        errand = str(args.get("id") or "").strip()
        state_dir = ROOT / "state"
        if not errand:
            rows = []
            for f in sorted(state_dir.glob("*.status")):
                try:
                    claim = f.read_text(errors="ignore").strip().splitlines()[-1][:80]
                except Exception:
                    claim = "unreadable"
                rows.append(f"- {f.stem}: {claim}")
            if not rows:
                return ToolResult("No errand has a recorded state on this seat yet.")
            return ToolResult("Errands this seat knows (claimed state):\n" + "\n".join(rows[:12]))

        parts = []
        claim_file = state_dir / f"{errand}.status"
        if claim_file.is_file():
            try:
                parts.append("claim: " + claim_file.read_text(errors="ignore").strip().splitlines()[-1][:160])
            except Exception:
                parts.append("claim: unreadable")
        code, out = _run([_door("agents/eindri-checkpoint.sh"), "show", errand, "--json"], timeout=25)
        if code == 0 and out.strip():
            parts.append("checkpoint: " + _clean(out, 300))
        else:
            parts.append("checkpoint: none saved yet")
        code, out = _run([_door("agents/eindri-liveness.sh"), errand], timeout=25)
        if code == 0 and out.strip():
            parts.append("pane: " + _clean(out, 200))
        if not parts:
            return ToolResult(f"No errand {errand} is recorded on this seat.")
        return ToolResult(f"Errand {errand} — " + " · ".join(parts))

    if name == "steer_worker":
        target = str(args.get("target", "")).strip()
        line = str(args.get("line", "")).strip()
        if not target or not line:
            raise ValueError("steer_worker needs a target and a line")
        code, out = _run([_door("agents/eindri-send.sh"), target, line], timeout=30)
        return ToolResult(
            f"{'sent' if code == 0 else 'failed'}: {line!r} → {target}. {_clean(out, 160)}",
            create_response=False,
        )


    if name == "search_home":
        import re as _re
        import subprocess as _sp
        query = str(args.get("query", "")).strip()
        if not query:
            raise ValueError("search_home needs a query")
        area = str(args.get("area", "")).strip().strip("/")
        base = _home() / "hodd" / area if area else _home() / "hodd"
        if not base.exists():
            return ToolResult(f"no such shelf: {area or 'hodd'}")
        # A spoken question is words, not a phrase: match every word, never the literal string.
        words = [w for w in _re.findall(r"[A-Za-z\u00C0-\u00FF0-9][A-Za-z\u00C0-\u00FF0-9_.-]{2,}", query)]
        seen, stop = set(), {"the", "and", "for", "what", "with", "how", "our", "have", "does", "did"}
        words = [w for w in dict.fromkeys(words) if w.lower() not in stop][:6] or [query]
        pattern = "|".join(_re.escape(w) for w in words)
        deny = ("secrets/", ".env", ".age", "/state/", "/saves/", "memory/kaia", "identity/confidential")
        proc = _sp.run(["grep", "-rIniE", "--exclude-dir=.git", "--exclude-dir=node_modules",
                        "--exclude-dir=__pycache__", pattern, str(base)],
                       capture_output=True, text=True, timeout=45)
        priority = {"hodd/life/personal/me/": 0, "hodd/identity/": 1, "hodd/docs/": 2,
                    "hodd/life/": 2, "hodd/data/": 4, "hodd/workspaces/": 4}
        scored, one_per_file = [], {}
        for line in proc.stdout.splitlines():
            if any(d in line for d in deny):
                continue
            hits = sum(1 for w in words if w.lower() in line.lower())
            rel = line.replace(str(_home()) + "/", "")
            path = rel.split(":", 1)[0]
            # one line per file: a single noisy file must not fill the list
            if path in one_per_file and one_per_file[path] >= 1:
                continue
            one_per_file[path] = one_per_file.get(path, 0) + 1
            rank = next((v for k, v in priority.items() if rel.startswith(k)), 5)
            if path.endswith((".py", ".json", ".jsonl", ".full.md", ".log")):
                rank += 4
            if "/assistant/approved/" in path:   # a mirror of other documents, never the source
                rank += 5
            scored.append((rank, -hits, rel))
        if not scored:
            return ToolResult(f"nothing in {area or 'the home'} matches {query!r}.")
        scored.sort()
        rows = [rel for _, _, rel in scored[:10]]
        return ToolResult(f"Matches for {words} ({len(scored)} files, 10 shown):\n" + "\n".join(rows))

    if name == "read_home_file":
        rel = str(args.get("path", "")).strip().lstrip("/")
        target = (_home() / "hodd" / rel).resolve()
        home_hodd = (_home() / "hodd").resolve()
        if home_hodd not in target.parents and target != home_hodd:
            raise ValueError("that path is outside the Allfather's home")
        if any(d in str(target) for d in ("/secrets/", ".age", ".env", "/state/", "/saves/")):
            raise ValueError("that shelf is not readable by voice (vault and secrets are closed)")
        if not target.is_file():
            return ToolResult(f"no such file: {rel}")
        text = target.read_text(errors="ignore")
        return ToolResult(text[:3000] + ("\n…" if len(text) > 3000 else ""))


    if name == "read_mail":
        import json as _json
        import urllib.request as _ur
        hours = int(args.get("hours") or 72)
        most = int(args.get("max") or 8)

        def _desk() -> tuple[str, list[str]]:
            """The mail desk is the house's own record of what arrived, already
            classified into needs_you / saw / done. It is local to the seat."""
            base = os.environ.get("YMIR_GATE_URL", "http://127.0.0.1:3889")
            with _ur.urlopen(base + "/api/mail/accounts", timeout=8) as r:
                accounts = _json.loads(r.read()).get("accounts") or []
            rows: list[str] = []
            for account in accounts:
                with _ur.urlopen(f"{base}/api/mail/queue?account={_ur.quote(account)}", timeout=15) as r:
                    q = _json.loads(r.read())
                for column, items in (q.get("columns") or {}).items():
                    for m in items:
                        who = (m.get("from") or {}).get("name") or (m.get("from") or {}).get("email") or "unknown"
                        rows.append(f"- [{column}] {who} · {m.get('subject','(no subject)')} · "
                                    f"{(m.get('received_at') or '')[:16]} · {m.get('proposed_action') or ''}")
            return "desk", rows

        scope = str(args.get("scope") or "inbox").strip().lower()
        if scope not in ("inbox", "sent", "drafts", "all"):
            scope = "inbox"

        def _scan() -> tuple[str, list[str]]:
            code, out = _run([_door("mail/mail-scan.sh"), "--scope", scope,
                              "--hours", str(hours), "--max", str(most)], timeout=60)
            if code != 0:
                raise RuntimeError(_clean(out, 160))
            data = _json.loads(out)
            return "scan", [f"- {m.get('from') or m.get('sender')} · {m.get('subject')} · {(m.get('date') or m.get('received') or '')[:16]}"
                            for m in (data.get("messages") or [])][:most]

        road, rows = None, []
        roads = (("scan", _scan),) if scope != "inbox" else (("desk", _desk), ("scan", _scan))
        for name_road, fn in roads:
            try:
                road, rows = fn()
                if rows:
                    break
            except Exception as exc:
                _log("mail.road_failed", road=name_road, error=str(exc)[:200])
        if not rows:
            return ToolResult(
                f"No mail found in {scope} over the last {hours} hours. Say that plainly; never guess what it said.")
        return ToolResult(f"Mail ({scope}) by the {road} road ({len(rows)} shown):\n" + "\n".join(rows[:most]))


    if name == "read_calendar":
        what = str(args.get("what") or "what").strip().lower()
        door = _door("time/snotra/calendar-ask.sh")
        live = str(ROOT / "systems/snotra/services/calendar/calendar-ask.sh")
        if Path(live).is_file():
            door = live
        argv = [door, what]
        if what == "free":
            argv += [str(int(args.get("minutes") or 30))]
        code, out = _run(argv, timeout=45)
        if code != 0 and not out:
            return ToolResult("the calendar door did not answer; say so plainly")
        # the door answers JSON with status/reason — speak the reason, never invent an event
        try:
            import json as _json
            body = out[out.index("{"):] if "{" in out else out
            data = _json.loads(body)
        except Exception:
            return ToolResult(_clean(out, 400))
        if data.get("reason") or data.get("status") in ("unknown", "error"):
            return ToolResult(
                "The calendar cannot be read yet: " + str(data.get("reason") or data.get("status")) +
                ". Missing: " + str(data.get("missing") or "—") +
                ". Tell him plainly that the grant is owed; do not guess what is on his day.")
        # speak it, do not dump it: the next few events, in the Allfather's own time
        import datetime as _dt
        events = data.get("events") or []
        now_ms = int(_dt.datetime.now().timestamp() * 1000)
        upcoming = []
        for e in events:
            try:
                start_ms = int(e.get("start_ms") or 0)
            except Exception:
                start_ms = 0
            if start_ms and start_ms >= now_ms - 60_000:
                upcoming.append((start_ms, e))
        upcoming.sort(key=lambda pair: pair[0])
        if not upcoming:
            return ToolResult(f"His calendar is readable and shows {len(events)} events in the window, none ahead of now.")
        rows = []
        for start_ms, e in upcoming[:6]:
            when = _dt.datetime.fromtimestamp(start_ms / 1000)
            stamp = when.strftime("%a %d %b %H:%M") if not e.get("all_day") else when.strftime("%a %d %b (all day)")
            what = e.get("summary") or "(no title)"
            where = " · meet" if e.get("conference_type") else ""
            rows.append(f"- {stamp} · {what}{where}")
        return ToolResult(f"His calendar, next {len(rows)} of {len(upcoming)} ahead:\n" + "\n".join(rows))


    if name == "read_board":
        query = str(args.get("query") or "").strip()
        # road 1 — the house's own Trello door, when a key+token grant exists
        door = str(ROOT / "systems/snotra/services/cron/snotra-trello.sh")
        if not Path(door).is_file():
            door = _door("time/snotra/snotra-trello.sh")
        code, out = _run([door, "list"], timeout=45)
        low = (out or "").lower()
        if code == 0 and out.strip() and "no trello grant" not in low and "no grant" not in low:
            rows = [ln for ln in out.splitlines() if ln.strip() and (not query or query.lower() in ln.lower())]
            return ToolResult("Trello (read-only):\n" + "\n".join(rows[:15]))

        # road 2 — the Gimlé board (Plane) on the heart, through its own reader
        heart = str(os.environ.get("YMIR_VOICE_BOARD_HOST") or "").strip()
        if not heart:
            try:
                import json as _json
                fleet = _home() / "hodd" / "data" / "fleet.json"
                heart = str(_json.loads(fleet.read_text()).get("heart") or "")
            except Exception:
                heart = ""
        if heart:
            import base64
            person = os.environ.get("YMIR_VOICE_PERSON") or _operator_handle()
            snippet = (
                "import sys\n"
                "sys.path.insert(0, 'bin/gimle')\n"
                "import plane_reader as p\n"
                f"cards, detail = p.board_for({person!r}, 12)\n"
                "print(detail)\n"
                "for c in cards:\n"
                "    print('-', str(c.get('name',''))[:70], '|', str(c.get('project','')))\n"
            )
            b64 = base64.b64encode(snippet.encode()).decode()
            remote = f"cd ~/ymir && echo {b64} | base64 -d | python3 -"
            code, out = _run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", heart, remote], timeout=90)
            if code == 0 and out.strip():
                rows = [ln for ln in out.splitlines() if ln.strip()]
                if query:
                    rows = [ln for ln in rows if query.lower() in ln.lower()]
                if not rows:
                    return ToolResult(f"The Gimlé board answered and nothing matches {query!r}.")
                return ToolResult("The Gimlé board (read-only, on the heart):\n" + "\n".join(rows[:14]))
            _log("board.plane_failed", host=heart, error=_clean(out, 200))

        return ToolResult(
            "Neither board can be read right now: Trello has no grant on this seat, and the Gimlé board on the "
            "heart did not answer. Say that plainly; do not guess what is on a board.")

    if name == "calendar_respond":
        import json as _json
        import urllib.parse as _up
        import urllib.request as _ur
        want = str(args.get("event") or "").strip()
        answer = str(args.get("response") or "accepted").strip().lower()
        if answer not in ("accepted", "declined", "tentative"):
            raise ValueError("response must be accepted, declined or tentative")
        if not want:
            raise ValueError("calendar_respond needs the event")
        env = _run([_door("vault/hodd.sh"), "emit", "secrets/platform.env"], timeout=20)[1]
        def key(k):
            for line in env.splitlines():
                if line.startswith(k + "=") or line.startswith("export " + k + "="):
                    return line.split("=", 1)[1].strip().strip('"\'')
            return ""
        cid, csec, rt = key("GOOGLE_MCP_CLIENT_ID"), key("GOOGLE_MCP_CLIENT_SECRET"), key("MANAGANDR_OAUTH_REFRESH_TOKEN")
        if not (cid and csec and rt):
            return ToolResult("The calendar write grant is missing from the vault; say so plainly.")
        body = _up.urlencode({"client_id": cid, "client_secret": csec, "refresh_token": rt,
                              "grant_type": "refresh_token"}).encode()
        tok = _json.loads(_ur.urlopen(_ur.Request("https://oauth2.googleapis.com/token", data=body), timeout=20).read())
        at = tok.get("access_token")
        if not at:
            return ToolResult("Google refused the calendar token; the grant needs renewing.")
        hdr = {"Authorization": "Bearer " + at, "Content-Type": "application/json"}
        now = __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat().replace("+00:00", "Z")
        q = _up.urlencode({"timeMin": now, "maxResults": 50, "singleEvents": "false",
                           "fields": "items(id,summary,start,attendees)"})
        items = _json.loads(_ur.urlopen(_ur.Request(
            f"https://www.googleapis.com/calendar/v3/calendars/primary/events?{q}", headers=hdr), timeout=25).read()).get("items", [])
        match = next((e for e in items if want.lower() in (e.get("summary") or "").lower()), None)
        if not match:
            return ToolResult(f"No upcoming event matches {want!r}; say so and name the next few you can see.")
        att = match.get("attendees") or []
        me = next((a for a in att if a.get("self")), None)
        if me is None:
            return ToolResult("That event has no attendee row for him — it may be his own event, so nothing to answer.")
        me["responseStatus"] = answer
        patch = _json.dumps({"attendees": att}).encode()
        req = _ur.Request(
            f"https://www.googleapis.com/calendar/v3/calendars/primary/events/{_up.quote(match['id'])}?sendUpdates=all",
            data=patch, headers=hdr, method="PATCH")
        try:
            _ur.urlopen(req, timeout=25).read()
        except Exception as exc:
            detail = getattr(exc, "read", lambda: b"")()
            return ToolResult(f"Google refused the change: {detail[:200] or exc}. The grant may be read-only; "
                             "say that plainly and offer to renew it with write access.")
        return ToolResult(f"Marked {answer} on \"{match.get('summary')}\"; the organiser is notified.", create_response=True)

    if name == "add_todo":
        import datetime as _dt
        item = str(args.get("item", "")).strip()
        if not item:
            raise ValueError("add_todo needs an item")
        # his own day/todo file says "his half is written by him and never by a machine",
        # so the voice keeps its own list beside it and never writes into his
        path = _home() / "hodd" / "life" / "personal" / "me" / "todo-voice.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as fh:
            fh.write(f"- [ ] {item}  ({ _dt.date.today().isoformat()} · by voice)\n")
        return ToolResult(
            f"Added to the voice's own todo list beside his (todo-voice.md): {item}", create_response=True)

    if name == "recall":
        query = str(args.get("query", "")).strip()
        if not query:
            raise ValueError("recall needs a query")
        code, out = _run([_door("records/mimir.sh"), "recall", query, "--k", "5"], timeout=40)
        return ToolResult(_clean(out, 700) if code == 0 else f"the well did not answer: {_clean(out, 120)}")

    if name == "remember":
        note = str(args.get("note", "")).strip()
        if not note:
            raise ValueError("remember needs a note")
        code, out = _run([_door("records/mimir.sh"), "observe", note, "--source", "voice"], timeout=40)
        return ToolResult(f"{'watered' if code == 0 else 'not kept'}: {_clean(out, 200)}", create_response=False)

    raise ValueError(f"Unknown tool: {name}")


async def execute_tool(name, arguments):
    """Every tool the voice uses passes through here, and leaves a line behind."""
    import time as _time
    started = _time.monotonic()
    _log("tool.start", tool=name, args={k: (str(v)[:160]) for k, v in (arguments or {}).items()})
    try:
        result = await _execute(name, arguments)
    except Exception as exc:
        _log("tool.error", tool=name, error=str(exc)[:300], ms=int((_time.monotonic() - started) * 1000))
        raise
    out = getattr(result, "output", result.get("output") if isinstance(result, dict) else result)
    speaks = getattr(result, "create_response", result.get("create_response") if isinstance(result, dict) else True)
    _log("tool.done", tool=name, ms=int((_time.monotonic() - started) * 1000),
         spoke_back=bool(speaks), output=str(out)[:400])
    return result


# ── the newer doors: one implementation each, dispatched through NEW_TOOLS ────
# Appending here and naming the entry in NEW_TOOLS is the whole contract. A tool that is
# declared in TOOLS but missing from NEW_TOOLS is a fault the smoke suite catches by name.

async def _tool_pane_read(args):
    import re as _re
    target = str(args.get("errand") or "").strip()
    lines = int(args.get("lines") or 20)
    if not target:
        raise ValueError("pane_read needs an errand or pane id")
    pane = target if ":" in target else _pane_for(target)
    if not pane:
        return ToolResult(f"No pane is seated for {target} — it may have finished, or never started.")
    code, out = _run(["herdr", "pane", "read", pane, "--source", "recent",
                      "--lines", str(max(5, min(lines, 60))), "--format", "text"], timeout=30)
    if code != 0 or not out.strip():
        return ToolResult(f"The pane {pane} gave no output; say so plainly.")
    clean = _re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", out)
    rows = [ln.rstrip() for ln in clean.splitlines() if ln.strip()]
    return ToolResult(f"What worker {pane} is doing (last {min(len(rows), lines)} lines):\n"
                      + "\n".join(rows[-lines:])[:1600])


async def _tool_draft_write(args):
    import datetime as _dt
    import re as _re
    title = str(args.get("title") or "draft").strip()
    body = str(args.get("body") or "").strip()
    to = str(args.get("to") or "").strip()
    if not title or not body:
        raise ValueError("draft_write needs a title and a body")
    shelf = _home() / "hodd" / "workspaces" / "work" / "drafts"
    shelf.mkdir(parents=True, exist_ok=True)
    slug = _re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:50] or "draft"
    path = shelf / f"{_dt.date.today().isoformat()}-{slug}.md"
    head = [f"# {title}", "", f"**drafted** {_dt.datetime.now():%Y-%m-%d %H:%M} · **by** Rödd (voice)"]
    if to:
        head.append(f"**to** {to}")
    head += ["", "---", ""]
    path.write_text("\n".join(head) + body + "\n", encoding="utf-8")
    _log("draft.written", title=title, to=to, path=str(path), chars=len(body))
    _run([_door("records/mimir.sh"), "observe", f"Draft written by voice: {title}" + (f" (to {to})" if to else ""),
          "--source", "voice", "--task", "rodd", "--force"], timeout=30)
    return ToolResult(f"Draft saved: {path}. It is a DRAFT — nothing was sent.", create_response=True)


async def _tool_home_recent(args):
    import datetime as _dt
    hours = int(args.get("hours") or 6)
    match = str(args.get("match") or "").strip().lower()
    cutoff = _dt.datetime.now().timestamp() - hours * 3600
    base = _home() / "hodd"
    rows = []
    for path in base.rglob("*"):
        if not path.is_file():
            continue
        rel = str(path).replace(str(base) + "/", "")
        if any(d in "/" + rel for d in ("/secrets/", "/state/", "/saves/", ".age")):
            continue
        if match and match not in rel.lower():
            continue
        try:
            st = path.stat()
        except OSError:
            continue
        if st.st_mtime >= cutoff:
            rows.append((st.st_mtime, rel, st.st_size))
    if not rows:
        return ToolResult(f"nothing under the home changed in the last {hours} hours"
                          + (f" matching {match!r}" if match else ""))
    rows.sort(reverse=True)
    stamp = lambda t: _dt.datetime.fromtimestamp(t).strftime("%H:%M")
    return ToolResult(f"Changed in the last {hours}h (newest first):\n"
                      + "\n".join(f"- {stamp(t)} · {rel} ({size} B)" for t, rel, size in rows[:14]))


def _session_log() -> str:
    remote = ('h=$(bash -lc ". ~/ymir/bin/vault/hoard-lib.sh >/dev/null 2>&1; ymir_home_root YMIR_HOME >/dev/null 2>&1; printf %s \"\\$YMIR_HOME\"" 2>/dev/null); d="$h/hodd/state/voice/host.log"; cat "$d" 2>/dev/null')
    seat = str(os.environ.get("YMIR_VOICE_HOST_SEAT") or "").strip()
    if not seat:
        try:
            import json as _json
            seat = str(_json.loads((_home() / "hodd" / "data" / "fleet.json").read_text()).get("ear", [""])[0])
        except Exception:
            seat = ""
    if not seat:
        return ""
    code, out = _run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", seat, remote], timeout=45)
    return out if code == 0 else ""


async def _tool_last_session(args):
    import re as _re
    turns = int(args.get("turns") or 12)
    log = _session_log()
    if not log.strip():
        return ToolResult("The host's session log could not be read; say so plainly.")
    lines = log.splitlines()
    cut = max((i for i, l in enumerate(lines) if "Client session_" in l), default=len(lines))
    said = []
    for text in lines[:cut]:
        m = _re.search(r"(USER:|ASSISTANT:)\s*(.*)", text)
        if m:
            said.append(("Allfather" if m.group(1) == "USER:" else "Skírnir") + ": " + m.group(2)[:180])
    if not said:
        return ToolResult("No earlier spoken turns are in the host's log yet.")
    return ToolResult(f"The conversation before this session — {min(turns, len(said))} of {len(said)} turns:\n"
                      + "\n".join(said[-turns:]))


async def _tool_search_sessions(args):
    import re as _re
    query = str(args.get("query") or "").strip()
    if not query:
        raise ValueError("search_sessions needs a query")
    limit = max(1, min(int(args.get("limit") or 8), 20))
    log = _session_log()
    if not log.strip():
        return ToolResult("The host's session transcript could not be read; say so plainly.")
    stamp, session, hits = "", 0, []
    for line in log.splitlines():
        if "Client session_" in line:
            session += 1
        m_time = _re.match(r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})", line)
        if m_time:
            stamp = m_time.group(1)
        if query.lower() in line.lower():
            m = _re.search(r"(USER:|ASSISTANT:)\s*(.*)", line)
            if m:
                who = "Allfather" if m.group(1) == "USER:" else "Skírnir"
                hits.append(f"[session {session} · {stamp}] {who}: {m.group(2)[:200]}")
    if not hits:
        return ToolResult(f"Nothing about {query!r} appears in any recorded voice session.")
    return ToolResult(f"{len(hits)} match(es) across {session} sessions (newest last):\n"
                      + "\n".join(hits[-limit:]))


def _todo_paths():
    base = _home() / "hodd"
    return (base / "state" / "voice" / "todos.jsonl",
            base / "life" / "personal" / "me" / "todo-voice.md")


def _todo_events():
    import json as _json
    ledger, _ = _todo_paths()
    rows = []
    if ledger.is_file():
        for raw in ledger.read_text(encoding="utf-8", errors="ignore").splitlines():
            try:
                rows.append(_json.loads(raw))
            except Exception:
                continue
    return rows


def _todo_state():
    tasks, order = {}, []
    for ev in _todo_events():
        tid = str(ev.get("id") or "")
        if not tid:
            continue
        a = ev.get("action")
        if a == "add":
            tasks[tid] = {"id": tid, "item": ev.get("item", ""), "status": "open",
                          "due": ev.get("due") or "", "priority": ev.get("priority") or "medium",
                          "project": ev.get("project") or "", "added": ev.get("ts", "")}
            order.append(tid)
        elif tid in tasks:
            if a == "done":
                tasks[tid]["status"] = "done"
            elif a == "reopen":
                tasks[tid]["status"] = "open"
            elif a == "update":
                for k in ("due", "priority", "project", "item"):
                    if ev.get(k):
                        tasks[tid][k] = ev[k]
    return [tasks[t] for t in order]


def _todo_render():
    _, view = _todo_paths()
    view.parent.mkdir(parents=True, exist_ok=True)
    tasks = _todo_state()
    opened = [t for t in tasks if t["status"] == "open"]
    done = [t for t in tasks if t["status"] == "done"]
    prio = {"high": 0, "medium": 1, "low": 2}

    def line(t):
        bits = [f"- [{'x' if t['status'] == 'done' else ' '}] {t['item']}", f"`{t['id']}`"]
        if t["due"]:
            bits.append(f"due {t['due']}")
        if t["priority"] != "medium":
            bits.append(t["priority"])
        if t["project"]:
            bits.append(t["project"])
        return " · ".join(bits)

    import datetime as _dt
    rows = ["# The voice's todo ledger", "",
            f"_rendered {_dt.datetime.now():%Y-%m-%d %H:%M} · derived from "
            "`hodd/state/voice/todos.jsonl` — a view, never the record_", "",
            f"## Open ({len(opened)})", ""]
    rows += [line(t) for t in sorted(opened, key=lambda t: (prio.get(t["priority"], 1), t["due"] or "9999", t["added"]))] or ["_nothing open_"]
    rows += ["", f"## Done ({len(done)})", ""]
    rows += [line(t) for t in done[-30:]] or ["_nothing done yet_"]
    view.write_text("\n".join(rows) + "\n", encoding="utf-8")


def _todo_append(ev):
    import json as _json
    ledger, _ = _todo_paths()
    ledger.parent.mkdir(parents=True, exist_ok=True)
    with ledger.open("a", encoding="utf-8") as fh:
        fh.write(_json.dumps(ev, ensure_ascii=False) + "\n")


def _todo_find(needle):
    needle = (needle or "").strip().lower()
    tasks = _todo_state()
    for t in tasks:
        if t["id"] == needle:
            return t
    for t in tasks:
        if needle and needle in t["item"].lower():
            return t
    return None


async def _tool_todo_add(args):
    import datetime as _dt
    item = str(args.get("item") or "").strip()
    if not item:
        raise ValueError("todo_add needs an item")
    tid = "t" + _dt.datetime.now().strftime("%H%M%S") + str(abs(hash(item)) % 100)[:2]
    _todo_append({"ts": _dt.datetime.now().isoformat(timespec="seconds"), "action": "add", "id": tid,
                  "item": item, "due": str(args.get("due") or ""),
                  "priority": (str(args.get("priority") or "medium")).lower(),
                  "project": str(args.get("project") or "")})
    _todo_render()
    return ToolResult(f"Added as {tid}: {item}. Say the id so he can tick it later.", create_response=True)


async def _tool_todo_list(args):
    status = str(args.get("status") or "open").lower()
    project = str(args.get("project") or "").strip().lower()
    tasks = _todo_state()
    if project:
        tasks = [t for t in tasks if project in t["project"].lower()]
    if status == "open":
        tasks = [t for t in tasks if t["status"] == "open"]
    elif status == "done":
        tasks = [t for t in tasks if t["status"] == "done"]
    if not tasks:
        return ToolResult(f"Nothing {status} on the todo ledger" + (f" for {project}" if project else "") + ".")
    rows = [f"- {t['id']} · {t['item'][:90]}" + (f" · due {t['due']}" if t["due"] else "")
            + (f" · {t['priority']}" if t["priority"] != "medium" else "")
            + (f" · {t['project']}" if t["project"] else "") for t in tasks[:15]]
    return ToolResult(f"{len(tasks)} task(s) {status}:\n" + "\n".join(rows))


async def _tool_todo_done(args):
    import datetime as _dt
    t = _todo_find(str(args.get("id") or ""))
    if not t:
        return ToolResult(f"No task matches {args.get('id')!r}; list the open ones and ask which.")
    _todo_append({"ts": _dt.datetime.now().isoformat(timespec="seconds"), "action": "done", "id": t["id"]})
    _todo_render()
    return ToolResult(f"Ticked {t['id']}: {t['item'][:80]}.", create_response=True)


async def _tool_todo_reopen(args):
    import datetime as _dt
    t = _todo_find(str(args.get("id") or ""))
    if not t:
        return ToolResult(f"No task matches {args.get('id')!r}; list the open ones and ask which.")
    _todo_append({"ts": _dt.datetime.now().isoformat(timespec="seconds"), "action": "reopen", "id": t["id"]})
    _todo_render()
    return ToolResult(f"Back open: {t['item'][:80]}.", create_response=True)


async def _tool_todo_update(args):
    import datetime as _dt
    t = _todo_find(str(args.get("id") or ""))
    if not t:
        return ToolResult(f"No task matches {args.get('id')!r}; list the open ones and ask which.")
    fields = {k: str(args.get(k) or "") for k in ("due", "priority", "project", "item")}
    if not any(fields.values()):
        return ToolResult("Nothing to change — give a due date, a priority, a project or new wording.")
    _todo_append({"ts": _dt.datetime.now().isoformat(timespec="seconds"), "action": "update",
                  "id": t["id"], **{k: v for k, v in fields.items() if v}})
    _todo_render()
    return ToolResult("Updated " + t["id"] + ": " + ", ".join(f"{k} → {v}" for k, v in fields.items() if v), create_response=True)


NEW_TOOLS = {
    "pane_read": _tool_pane_read,
    "draft_write": _tool_draft_write,
    "home_recent": _tool_home_recent,
    "last_session": _tool_last_session,
    "search_sessions": _tool_search_sessions,
    "todo_add": _tool_todo_add,
    "todo_list": _tool_todo_list,
    "todo_done": _tool_todo_done,
    "todo_reopen": _tool_todo_reopen,
    "todo_update": _tool_todo_update,
}

# ── shared helpers the newer doors need (module level, one copy each) ─────────

def _operator_handle() -> str:
    """The operator's board identity, read from the hoard — never a name in this repo (RULES/04)."""
    for name in ("operator.yaml", "seats.yaml"):
        path = _home() / "hodd" / "identity" / name
        if not path.is_file():
            continue
        try:
            text = path.read_text(errors="ignore")
        except Exception:
            continue
        for line in text.splitlines():
            low = line.strip().lower()
            for key in ("handle:", "board:", "person:", "user:", "login:"):
                if low.startswith(key):
                    value = line.split(":", 1)[1].strip().strip('"\'')
                    if value:
                        return value
    return ""


def _pane_for(errand: str) -> str:
    """The pane an errand is seated in — asked of herdr, by the pane's own working directory."""
    if not errand:
        return ""
    try:
        out = subprocess.run(["herdr", "pane", "list"], capture_output=True, text=True, timeout=20).stdout
        panes = json.loads(out).get("result", {}).get("panes", [])
    except Exception:
        return ""
    want = "/.yggdrasil/" + errand
    for pane in panes:
        cwd = pane.get("cwd") or ""
        if cwd.endswith(want) or want in cwd:
            return pane.get("pane_id") or ""
    return ""


async def _tool_errand_state(args):
    """The pane's truth for THAT errand — never the whole fleet's liveness sweep."""
    errand = str(args.get("id") or "").strip()
    state_dir = ROOT / "state"
    if not errand:
        rows = []
        for f in sorted(state_dir.glob("*.status")):
            try:
                claim = f.read_text(errors="ignore").strip().splitlines()[-1][:70]
            except Exception:
                claim = "unreadable"
            rows.append(f"- {f.stem}: {claim}")
        return ToolResult("Errands this seat knows:\n" + "\n".join(rows[:12]) if rows
                          else "No errand has a recorded state on this seat yet.")
    parts = []
    claim_file = state_dir / f"{errand}.status"
    if claim_file.is_file():
        try:
            parts.append("claim: " + claim_file.read_text(errors="ignore").strip().splitlines()[-1][:120])
        except Exception:
            pass
    pane = _pane_for(errand)
    if pane:
        try:
            listing = json.loads(subprocess.run(["herdr", "pane", "list"], capture_output=True,
                                                text=True, timeout=20).stdout)
            for p_ in listing.get("result", {}).get("panes", []):
                if p_.get("pane_id") == pane:
                    parts.append(f"pane {pane}: {p_.get('agent_status') or 'unknown'}")
        except Exception:
            parts.append(f"pane {pane}")
    else:
        parts.append("pane: none found (it may have finished and been closed)")
    return ToolResult(f"Errand {errand} — " + " · ".join(parts) +
                      ". If the pane says working, it is still running; say so and offer to read its pane.")


async def _tool_steer_worker(args):
    target = str(args.get("target") or "").strip()
    line = str(args.get("line") or "").strip()
    if not target or not line:
        raise ValueError("steer_worker needs a target and a line")
    if ":" not in target:
        pane = _pane_for(target)
        if pane:
            target = pane
    code, out = _run([_door("agents/eindri-send.sh"), target, line], timeout=30)
    return ToolResult(f"{'sent' if code == 0 else 'failed'}: {line!r} → {target}. {_clean(out, 160)}",
                      create_response=False)


NEW_TOOLS["errand_state"] = _tool_errand_state
NEW_TOOLS["steer_worker"] = _tool_steer_worker


async def _tool_read_home_file(args):
    """Read one file from the home; `tail` reads the END, which is where an append-only
    ledger keeps its newest words."""
    rel = str(args.get("path", "")).strip().lstrip("/")
    target = (_home() / "hodd" / rel).resolve()
    home_hodd = (_home() / "hodd").resolve()
    if home_hodd not in target.parents and target != home_hodd:
        raise ValueError("that path is outside the Allfather's home")
    if any(d in str(target) for d in ("/secrets/", ".age", ".env", "/state/", "/saves/")):
        raise ValueError("that shelf is not readable by voice (vault and secrets are closed)")
    if not target.is_file():
        name = Path(rel).name
        stem = name.split(".")[0]
        hits = []
        for cand in home_hodd.rglob("*" + stem + "*"):
            if cand.is_file() and not any(d in str(cand) for d in ("/secrets/", ".age", "/saves/", "/state/")):
                hits.append(str(cand).replace(str(home_hodd) + "/", ""))
            if len(hits) >= 5:
                break
        if hits:
            return ToolResult("no such file: " + rel + " — but these exist, read one of them:\n- " + "\n- ".join(hits))
        return ToolResult("no such file: " + rel + ", and nothing under the home resembles it")
    text = target.read_text(errors="ignore")
    if args.get("tail"):
        n = int(args.get("lines") or 60)
        rows = text.splitlines()
        return ToolResult(f"The last {min(n, len(rows))} lines of {rel}:\n" + "\n".join(rows[-n:])[:2500])
    return ToolResult(text[:3000] + ("\n… (use tail=true for the end)" if len(text) > 3000 else ""))


NEW_TOOLS["read_home_file"] = _tool_read_home_file

# ── the sessions shelf: list · count · read · find · digest ────────────────────

def _sessions() -> list[dict]:
    """Every session in the host's transcript, oldest first, each with its turns."""
    import re as _re
    log = _session_log()
    if not log.strip():
        return []
    out = [{"n": 0, "lines": [], "first": "", "at": ""}]
    for line in log.splitlines():
        if "Client session_" in line:
            out.append({"n": len(out), "lines": [], "first": "", "at": ""})
            continue
        cur = out[-1]
        m_time = _re.match(r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})", line)
        if m_time and not cur["at"]:
            cur["at"] = m_time.group(1)
        m = _re.search(r"(USER:|ASSISTANT:)\s*(.*)", line)
        if m:
            who = "Allfather" if m.group(1) == "USER:" else "Skírnir"
            cur["lines"].append(who + ": " + m.group(2)[:200])
            if not cur["first"]:
                cur["first"] = m.group(2)[:80]
    return [x for x in out if x["lines"]]


async def _tool_sessions_list(args):
    recent = max(1, min(int(args.get("recent") or 10), 40))
    match = str(args.get("match") or "").strip().lower()
    sessions = _sessions()
    if not sessions:
        return ToolResult("No session has been recorded in the host's transcript yet.")
    picked = sessions
    if match:
        picked = [x for x in sessions if any(match in l.lower() for l in x["lines"])]
        if not picked:
            return ToolResult(f"No session mentions {match!r}. There are {len(sessions)} in all.")
    rows = [f"- session {x['n']} · {x['at'] or 'undated'} · {len(x['lines'])} turn(s) · {x['first'][:70]}"
            for x in picked[-recent:]]
    return ToolResult(f"{len(sessions)} session(s) recorded; the last {len(rows)}:\n" + "\n".join(rows))


async def _tool_session_read(args):
    target = str(args.get("session") or "").strip()
    turns = max(2, min(int(args.get("turns") or 20), 60))
    sessions = _sessions()
    if not sessions:
        return ToolResult("No session has been recorded in the host's transcript yet.")
    chosen = None
    if target.isdigit():
        chosen = next((x for x in sessions if x["n"] == int(target)), None)
    if chosen is None and target:
        chosen = next((x for x in reversed(sessions) if any(target.lower() in l.lower() for l in x["lines"])), None)
    if chosen is None:
        return ToolResult(f"No session matches {target!r}; list them and ask which.")
    return ToolResult(f"Session {chosen['n']} · {chosen['at'] or 'undated'} · {len(chosen['lines'])} turn(s):\n"
                      + "\n".join(chosen["lines"][-turns:]))


async def _tool_session_digest(args):
    """A session that is only a log is a session nobody finds: this writes its shape into the well."""
    sessions = _sessions()
    if not sessions:
        return ToolResult("No session is recorded, so there is nothing to digest.")
    last = sessions[-1]
    words = [l.split(": ", 1)[1] for l in last["lines"] if ": " in l]
    topics = " · ".join(w[:70] for w in words[:3]) or "(no words)"
    tail = " · ".join(w[:70] for w in words[-2:]) or ""
    text = (f"Voice session {last['n']} ({last['at'] or 'undated'}, {len(last['lines'])} turns). "
            f"Opened with: {topics}. It ended on: {tail}.")
    code, out = _run([_door("records/mimir.sh"), "observe", text, "--source", "voice",
                      "--task", "rodd-sessions", "--force"], timeout=45)
    return ToolResult(("Digested into the well: " if code == 0 else "The well refused: ") + text[:300])


async def _tool_find_session(args):
    question = str(args.get("question") or "").strip()
    if not question:
        raise ValueError("find_session needs a question")
    import re as _re
    code, out = _run([_door("records/mimir.sh"), "recall", question, "--k", "6"], timeout=45)
    hits = _re.findall(r"Voice session (\d+)", out or "")
    if hits:
        numbers = list(dict.fromkeys(hits))[:3]
        return ToolResult("The well knows these sessions:\n" +
                          "\n".join(f"- session {n} — open it with session_read(session='{n}')" for n in numbers))
    return await _tool_search_sessions({"query": question, "limit": 6})


NEW_TOOLS["sessions_list"] = _tool_sessions_list
NEW_TOOLS["session_read"] = _tool_session_read
NEW_TOOLS["session_digest"] = _tool_session_digest
NEW_TOOLS["find_session"] = _tool_find_session


# ── the schedule, the ledger, and the raven ───────────────────────────────────
# Three things he asked for out loud on 2026-11-08 that the voice had no hand for:
# *"what is going on on the cron jobs"*, *"what is Northern Italy doing"* (a plan, not an
# errand), and *"can you do online research?"*. Each one is a DOOR he already had from the
# terminal, given to the voice — never a second implementation of the same thing.

def _home_config(name: str) -> Path:
    """The operator's own config shelf, resolved (RULES/04: never the repo's example)."""
    for cand in (_home() / "config" / name, ROOT / "config" / name):
        if cand.is_file():
            return cand
    return _home() / "config" / name


async def _tool_cron_jobs(args):
    """Is the schedule running, what is on it, and what last fired — read, never written."""
    parts = []
    code, out = _run([_door("time/nornir-cron-start.sh"), "--status"], timeout=25)
    parts.append(_clean(out, 200) if out.strip() else "the scheduler gave no answer")

    jobs = []
    cfg = _home_config("cron.yaml")
    if cfg.is_file():
        try:
            for line in cfg.read_text(errors="ignore").splitlines():
                s = line.strip()
                if not s or s.startswith("#"):
                    continue
                toks = s.split()
                gate = ""
                if toks and toks[0].startswith("@"):      # "@heart 06:00 bin/…" — the role comes FIRST
                    gate = toks[0]
                    toks = toks[1:]
                if len(toks) >= 2 and ":" in toks[0]:
                    job = Path(toks[1]).name
                    jobs.append(f"{toks[0]} {job}" + (f" {gate}" if gate else ""))
        except Exception:
            pass
    if jobs:
        parts.append(f"{len(jobs)} jobs on the schedule: " + ", ".join(jobs[:14])
                     + (" …" if len(jobs) > 14 else ""))

    fired_dir = ROOT / "state" / ".cron-fired"
    if fired_dir.is_dir():
        import datetime as _dt
        recent = []
        for f in sorted(fired_dir.iterdir(), key=lambda p: p.stat().st_mtime)[-5:]:
            try:
                recent.append(f"{f.name} at {_dt.datetime.fromtimestamp(f.stat().st_mtime):%m-%d %H:%M}")
            except Exception:
                continue
        if recent:
            parts.append("last fired: " + " · ".join(recent))

    log = ROOT / "state" / "cron.log"
    if log.is_file():
        try:
            tail = [ln for ln in log.read_text(errors="ignore").splitlines()[-6:] if ln.strip()]
            if tail:
                parts.append("the log's last lines: " + " | ".join(tail[-4:])[:300])
        except Exception:
            pass
    return ToolResult("The schedule: " + ". ".join(p for p in parts if p) + ".")


async def _tool_plans(args):
    """The plan ledger: search it, or open one plan. A plan is not an errand and the voice
    kept confusing the two."""
    query = str(args.get("query") or "").strip()
    number = str(args.get("number") or "").strip()
    home = _home()
    shelves = sorted(home.glob("svartalfaheim/*/projects/*/plans"))
    if not shelves:
        return ToolResult("No plan ledger is reachable from the home on this seat.")

    if number:
        num = str(number).lstrip("0")
        for shelf in shelves:
            for f in shelf.glob("*.md"):
                if f.name.split("-", 1)[0].lstrip("0") == num:
                    text = f.read_text(errors="ignore")
                    head = [ln for ln in text.splitlines()[:60]]
                    return ToolResult(f"Plan {num} — {f.stem}:\n" + "\n".join(head)[:2200])
        return ToolResult(f"No plan numbered {num} is in the ledger.")

    # Search the SHELVES, not one door's tail: `plan.sh list` prints the newest rows, and a
    # question is usually about an older plan than the last twenty.
    rows: list[tuple[str, str]] = []
    for shelf in shelves:
        for f in shelf.glob("*.md"):
            if f.name.lower() in ("readme.md", "queue.md", "questions.md", "register.md"):
                continue
            title = ""
            try:
                for ln in f.read_text(errors="ignore").splitlines()[:12]:
                    if ln.startswith("# "):
                        title = ln[2:].strip()
                        break
            except Exception:
                pass
            rows.append((f.name.split("-", 1)[0], f"{title or f.stem} ({f.stem})"))
    # newest first, by the number the name carries
    def _num(pair: tuple[str, str]) -> int:
        try:
            return int(pair[0].lstrip("0") or 0)
        except Exception:
            return 0
    rows.sort(key=_num, reverse=True)
    if query:
        q = query.replace("-", " ").lower()
        rows = [r for r in rows if q in (r[1] + " " + r[0]).replace("-", " ").lower()]
    if not rows:
        return ToolResult(f"No plan in the ledger mentions {query!r}." if query
                          else "The ledger listed nothing.")
    shown = [f"{n} · {t}" for n, t in rows[:14]]
    return ToolResult(
        (f"Plans mentioning {query!r}:" if query else "The plan ledger (newest first):")
        + "\n- " + "\n- ".join(shown)
        + "\nopen one with plans(number='<n>')")


async def _tool_research(args):
    """Send Huginn out on a question — READ ONLY research, and never on a spoken word alone:
    the same two-phase gate hand_over carries, because it still seats a worker."""
    question = str(args.get("question") or "").strip()
    if not question:
        raise ValueError("research needs a question")
    role = _role_for("huginn") or "researcher"
    pending_path = _home() / "hodd" / "state" / "voice" / "pending-research.json"
    if not args.get("confirm"):
        try:
            pending_path.parent.mkdir(parents=True, exist_ok=True)
            pending_path.write_text(json.dumps(
                {"question": question,
                 "asked_at": __import__("datetime").datetime.now().isoformat(timespec="seconds")}))
        except Exception:
            pass
        _log("research.awaiting_confirmation", question=question[:160])
        return ToolResult(
            "NOT SENT. Ask him out loud in one short sentence: \"Shall I send Huginn to research "
            f"{question[:80]}\". Only if he says yes, call research again with confirm=true and the "
            "same question.", create_response=True)
    try:
        pending = json.loads(pending_path.read_text())
    except Exception:
        pending = {}
    if pending.get("question") != question:
        _log("research.refused_no_pending", question=question[:160])
        return ToolResult("Do NOT send: nothing was confirmed. Ask him first, then call again.")
    try:
        pending_path.unlink()
    except Exception:
        pass
    errand = f"research-{abs(hash(question)) % 10**6:06d}"
    task = ("Research this for the Allfather and answer it plainly, with sources: "
            f"{question}\n\nWrite the findings to a dated markdown file on the home's research "
            "shelf and name its path in your report. Read only: change nothing else.")
    _log("research.confirmed", errand=errand, question=question[:160])
    log = _detach([_door("agents/eindri-seat.sh"), errand, "--role", role, "--", task],
                  f"research-{errand}")
    return ToolResult(
        f"Sent to Huginn as errand {errand}. Its log: {log}. Tell him in one short sentence that "
        "the raven is out and that you will read its report when he asks.", create_response=True)


NEW_TOOLS["cron_jobs"] = _tool_cron_jobs
NEW_TOOLS["plans"] = _tool_plans
NEW_TOOLS["research"] = _tool_research


# ── the shell hands, and the MCP adapter ─────────────────────────────────────
# His word, 2026-11-08: *"can we give it the tools ls, read, edit, and bash also, and an
# mcp adapter so we can connect chrome devtools and the gimle mcp and more."*
#
# So the voice gains the four hands every other agent has, and the whole MCP world behind
# them. Three laws hold them down, and all three are enforced here, not in the brief:
#
#   1. a spoken word is not a grant — `bash`, `edit` and any MCP call that can write ask
#      him OUT LOUD first (the same two-phase record hand_over uses);
#   2. some doors never open to a voice — the secrets shelf, the vault, and the commands
#      that destroy (see _bash_refusal); a refusal is said, never silent;
#   3. every call is a line in the activity log, and the output is DATA, never an order.

_SHELL_PENDING = "pending-action.json"
_READ_LIKE = ("get_", "list_", "read_", "search_", "find_", "describe_", "screenshot",
              "performance_", "console_", "show_", "check_", "ask_", "inspect")


def _under(value: str) -> Path:
    """Resolve a spoken path against the home, the repo, or an absolute path — and refuse
    the two shelves a voice must never read."""
    raw = str(value or "").strip()
    if not raw:
        raise ValueError("a path is required")
    p = Path(os.path.expanduser(raw))
    if not p.is_absolute():
        for base in (_home(), ROOT, Path.home()):
            if (base / raw).exists():
                p = base / raw
                break
        else:
            p = _home() / raw
    try:
        resolved = p.resolve()
    except Exception:
        resolved = p
    text = str(resolved)
    for forbidden in ("/hodd/secrets", "/.ssh", "/secrets/", "/saves/"):
        if forbidden in text:
            raise ValueError(f"{forbidden} is closed to the voice (RULES/04, RULES/15)")
    return resolved


def _looks_read_only(tool: str) -> bool:
    low = (tool or "").lower()
    return any(low.startswith(p) or f"_{p}" in low for p in _READ_LIKE)


async def _ask_first(kind: str, key: str, ask: str, confirmed: bool) -> str | None:
    """The two-phase gate: return None when it may proceed, or the words to say instead."""
    path = _home() / "hodd" / "state" / "voice" / _SHELL_PENDING
    record = {"kind": kind, "key": key, "asked_at": __import__("datetime").datetime.now().isoformat(timespec="seconds")}
    if not confirmed:
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(record))
        except Exception:
            pass
        _log("action.awaiting_confirmation", kind=kind, key=key[:200])
        return ("NOT DONE. Say this to him in one short sentence and wait for a spoken yes: "
                f"\"{ask}\" Then call again with confirm=true and the same arguments.")
    try:
        pending = json.loads(path.read_text())
    except Exception:
        pending = {}
    if pending.get("kind") != kind or pending.get("key") != key:
        _log("action.refused_no_pending", kind=kind, key=key[:200])
        return "Do NOT do that: nothing was confirmed. Ask him out loud first, then call again."
    try:
        path.unlink()
    except Exception:
        pass
    _log("action.confirmed", kind=kind, key=key[:200])
    return None


def _bash_refusal(cmd: str) -> str | None:
    """The commands a voice may never run, and the shelves it may never open."""
    import re as _re
    low = cmd.lower()
    hard = [
        (r"\brm\s+(-[a-z]*\s+)*-?[rf]{1,2}\s+/(\s|$)", "deleting from the filesystem root"),
        (r"\bmkfs|\bdd\s+.*of=/dev/", "writing a filesystem or a raw device"),
        (r"\bsudo\b|\bdoas\b", "raising privilege"),
        (r"git\s+push\s+.*--force|git\s+push\s+.*-f\b", "force-pushing"),
        (r"git\s+merge|git\s+reset\s+--hard|git\s+clean\s+-[a-z]*f", "rewriting the tree"),
        (r"--no-verify", "skipping a gate"),
        (r"curl[^|]*\|\s*(ba)?sh|wget[^|]*\|\s*(ba)?sh", "piping the network into a shell"),
        (r"hodd/secrets|\.age\b|age\.key|id_rsa|\.ssh/", "the secrets shelf or a key"),
        (r"\b(shutdown|reboot|systemctl\s+poweroff)\b", "taking the machine down"),
        (r"\bpasswd\b|chmod\s+777|chown\s+-R\s+/", "changing access to the machine"),
    ]
    for pattern, why in hard:
        if _re.search(pattern, low):
            return why
    return None


async def _tool_ls(args):
    target = str(args.get("path") or ".")
    p = _under(target)
    if not p.exists():
        return ToolResult(f"No such path: {target}")
    if p.is_file():
        return ToolResult(f"{target} is a file ({p.stat().st_size} bytes) — read it with read(path=…).")
    rows = []
    try:
        for child in sorted(p.iterdir(), key=lambda c: (not c.is_dir(), c.name.lower()))[:80]:
            if child.name.startswith(".") and not args.get("all"):
                continue
            size = "" if child.is_dir() else f"  {child.stat().st_size // 1024 or 1}K"
            rows.append(f"{child.name}{'/' if child.is_dir() else ''}{size}")
    except Exception as exc:
        return ToolResult(f"Could not list {target}: {exc}")
    return ToolResult(f"{p} — {len(rows)} entries:\n" + "\n".join(rows))


async def _tool_read(args):
    p = _under(str(args.get("path") or ""))
    if not p.is_file():
        return ToolResult(f"No such file: {args.get('path')}")
    text = p.read_text(errors="ignore")
    lines = text.splitlines()
    start = max(1, int(args.get("from") or 1))
    count = int(args.get("lines") or (120 if args.get("from") else 200))
    chunk = lines[start - 1:start - 1 + count]
    tail = f"\n… ({len(lines)} lines total; read from={start + count} for more)" if start - 1 + count < len(lines) else ""
    return ToolResult(f"{p} (lines {start}-{start + len(chunk) - 1} of {len(lines)}):\n" + "\n".join(chunk)[:3500] + tail)


async def _tool_edit(args):
    raw = str(args.get("path") or "").strip()
    if not raw:
        raise ValueError("edit needs a path")
    p = _under(raw)
    old = args.get("old")
    new = args.get("new")
    content = args.get("content")
    exists = p.is_file()
    if not exists and content is None:
        return ToolResult(f"{raw} does not exist; to create it, give content=… (nothing was written).")
    key = f"{p}|{(old or '')[:60]}|{(new or content or '')[:60]}"
    asked = await _ask_first("edit", key, f"Shall I write {raw}?" if content is not None
                             else f"Shall I change {raw}?", bool(args.get("confirm")))
    if asked:
        return ToolResult(asked)
    try:
        if content is not None:
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(str(content))
            return ToolResult(f"Wrote {len(str(content))} characters to {raw}.")
        if old is None:
            raise ValueError("edit needs content, or old+new")
        current = p.read_text(errors="ignore")
        if str(old) not in current:
            return ToolResult(f"{raw} does not contain that text; nothing was changed (read it first).")
        p.write_text(current.replace(str(old), str(new or ""), 1))
        return ToolResult(f"Changed one occurrence in {raw}.")
    except Exception as exc:
        return ToolResult(f"The edit failed: {exc}")


async def _tool_bash(args):
    cmd = str(args.get("command") or "").strip()
    if not cmd:
        raise ValueError("bash needs a command")
    why = _bash_refusal(cmd)
    if why:
        _log("bash.refused", command=cmd[:200], why=why)
        return ToolResult(f"Refused: {why}. That door is closed to the voice — say so to him plainly.")
    asked = await _ask_first("bash", cmd, f"Shall I run: {cmd[:120]}", bool(args.get("confirm")))
    if asked:
        return ToolResult(asked)
    cwd = str(args.get("cwd") or ROOT)
    timeout = min(int(args.get("timeout") or 60), 300)
    try:
        proc = subprocess.run(["bash", "-lc", cmd], capture_output=True, text=True,
                              timeout=timeout, cwd=cwd, env={**os.environ, "YMIR_VOICE": "1"})
    except subprocess.TimeoutExpired:
        return ToolResult(f"`{cmd[:80]}` did not finish in {timeout}s; it was stopped.")
    out = ((proc.stdout or "") + (proc.stderr or "")).strip()
    body = out[:2200] + ("\n… (truncated)" if len(out) > 2200 else "")
    return ToolResult(f"`{cmd[:100]}` exited {proc.returncode}:\n{body or '(no output)'}")


async def _tool_mcp_tools(args):
    import voice_mcp
    server = str(args.get("server") or "").strip()
    found = voice_mcp.servers()
    if not server:
        rows = [f"{name} ({'http' if s.get('url') else 'stdio'})" for name, s in found.items()]
        return ToolResult("MCP servers on this seat: " + ", ".join(rows))
    try:
        table = voice_mcp.tools(server)
    except voice_mcp.McpError as exc:
        return ToolResult(str(exc))
    rows = [f"{t.get('name')} — {(t.get('description') or '').splitlines()[0][:110]}" for t in table]
    return ToolResult(f"{server}: {len(rows)} tools:\n- " + "\n- ".join(rows[:40]))


async def _tool_mcp(args):
    import voice_mcp
    server = str(args.get("server") or "").strip()
    tool = str(args.get("tool") or "").strip()
    if not server or not tool:
        raise ValueError("mcp needs a server and a tool (mcp_tools lists them)")
    payload = args.get("args") or {}
    if isinstance(payload, str):
        try:
            payload = json.loads(payload)
        except Exception:
            raise ValueError("args must be a JSON object")
    write_like = not _looks_read_only(tool)
    if write_like:
        asked = await _ask_first("mcp", f"{server}/{tool}/{json.dumps(payload, sort_keys=True)[:120]}",
                                 f"Shall I call {tool} on {server} — it can change things?", bool(args.get("confirm")))
        if asked:
            return ToolResult(asked)
    try:
        out = voice_mcp.call(server, tool, payload)
    except voice_mcp.McpError as exc:
        _log("mcp.error", server=server, tool=tool, error=str(exc)[:200])
        return ToolResult(f"{server}/{tool} failed: {exc}")
    return ToolResult(out[:3500])


NEW_TOOLS["ls"] = _tool_ls
NEW_TOOLS["read"] = _tool_read
NEW_TOOLS["edit"] = _tool_edit
NEW_TOOLS["bash"] = _tool_bash
NEW_TOOLS["mcp_tools"] = _tool_mcp_tools
NEW_TOOLS["mcp"] = _tool_mcp
