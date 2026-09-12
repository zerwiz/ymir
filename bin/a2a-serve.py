#!/usr/bin/env python3
# a2a-serve.py — a real A2A 1.0 server (a2a-sdk) whose agent is a seated Eindri:
# it injects the task into the agent's chat via herdr and returns the reply.
#
#   a2a-serve.py <pane-or-agent> <name> <port>
#
# Replaces the hand-rolled server. Protocol/Agent Card/JSON-RPC are the SDK's;
# our only job is the executor below.
import asyncio
import os
import subprocess
import sys
import time

import uvicorn
from starlette.applications import Starlette

from a2a.helpers import (
    get_message_text,
    new_task_from_user_message,
    new_text_message,
    new_text_part,
)
from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.routes import create_agent_card_routes, create_jsonrpc_routes
from a2a.server.tasks import InMemoryTaskStore, TaskUpdater
from a2a.types import (
    AgentCapabilities,
    AgentCard,
    AgentInterface,
    AgentSkill,
    TaskState,
)

TARGET = sys.argv[1]
NAME = sys.argv[2]
PORT = int(sys.argv[3])
WAIT = float(os.environ.get("A2A_SERVE_WAIT", "30"))


def sh(*a: str) -> str:
    try:
        return subprocess.run(a, capture_output=True, text=True, timeout=90).stdout
    except Exception:
        return ""


def inject_and_read(text: str) -> str:
    """Deliver the task into the seated agent's chat, then read its reply."""
    sh("herdr", "agent", "prompt", TARGET, text)
    time.sleep(WAIT)
    out = sh("herdr", "agent", "read", TARGET).strip()
    return "\n".join(out.splitlines()[-8:]) or "(no output)"


class EindriExecutor(AgentExecutor):
    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        if context.current_task:
            task = context.current_task
        else:
            task = new_task_from_user_message(context.message)
            await event_queue.enqueue_event(task)
        up = TaskUpdater(event_queue=event_queue, task_id=task.id, context_id=task.context_id)
        await up.update_status(
            state=TaskState.TASK_STATE_WORKING,
            message=new_text_message("Delivering to the Eindri..."),
        )
        query = get_message_text(context.message) or ""
        result = await asyncio.to_thread(inject_and_read, query)
        await up.add_artifact(parts=[new_text_part(text=result, media_type="text/plain")])
        await up.update_status(
            state=TaskState.TASK_STATE_COMPLETED,
            message=new_text_message(result),
        )

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise NotImplementedError("Cancel is not supported.")


skill = AgentSkill(
    id="eindri", name=NAME, description=f"Ymir Eindri {NAME}",
    input_modes=["text/plain"], output_modes=["text/plain"], tags=["ymir", "eindri"],
)
card = AgentCard(
    name=NAME, description=f"Ymir Eindri {NAME}", version="1.0.0",
    default_input_modes=["text/plain"], default_output_modes=["text/plain"],
    capabilities=AgentCapabilities(streaming=False),
    supported_interfaces=[AgentInterface(
        protocol_binding="JSONRPC", url=f"http://127.0.0.1:{PORT}", protocol_version="1.0")],
    skills=[skill],
)
handler = DefaultRequestHandler(
    agent_executor=EindriExecutor(), task_store=InMemoryTaskStore(), agent_card=card,
)
routes: list = []
routes.extend(create_agent_card_routes(card))
routes.extend(create_jsonrpc_routes(handler, "/"))

if __name__ == "__main__":
    print(f"a2a-serve: {NAME} -> {TARGET} on http://127.0.0.1:{PORT}/", flush=True)
    uvicorn.run(Starlette(routes=routes), host="127.0.0.1", port=PORT, log_level="warning")
