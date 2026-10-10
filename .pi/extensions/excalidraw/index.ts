/**
 * excalidraw — the door into the team's whiteboard fork.
 *
 * What the fork can do, as tools an agent can actually use:
 *
 *   · read the tickets — the behaviour contracts, straight from the files
 *   · probe / raise / lower the fork's three services
 *   · open and close the desktop app
 *
 * It reads the FILES, not the HTTP board: the board server is a convenience for
 * a browser, and an agent should not need a server running to read a ticket.
 *
 * Placement (Rule 13): a multi-file extension is a directory with an index.ts,
 * its own internals live inside its own directory, and the ONE home is
 * `.pi/extensions/`. Nothing here is deployed anywhere else, and nothing starts
 * in the factory — a session that loads this extension starts no process.
 */

import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

import { SERVICES, excalidrawRoot, isServiceName } from "./paths.ts";
import { contractSections, isColumn, listTickets, readTicket } from "./tickets.ts";
import { start, status, stop } from "./servers.ts";

import type { Column } from "./tickets.ts";

const ok = (text: string) => ({ content: [{ type: "text" as const, text }] });
const bad = (text: string) => ({
  content: [{ type: "text" as const, text }],
  isError: true,
});

export default function excalidraw(pi: any) {
  const root = () => excalidrawRoot();

  /** One place that says whether the fork is even where we think it is. */
  const rootExists = () =>
    existsSync(join(root(), "tickets")) && existsSync(join(root(), "AGENTS.md"));

  pi.registerTool({
    name: "excalidraw_tickets",
    description:
      "Read the Excalidraw fork's tickets — the behaviour contracts that live in " +
      "`tickets/`. action=board lists them by column (open · in-progress · review · " +
      "done); action=read returns one ticket, either whole or as its contract " +
      "sections. Use this before touching the fork: nothing starts without a " +
      "ticket, and a ticket with no owner is not filed.",
    parameters: {
      type: "object",
      properties: {
        action: {
          type: "string",
          enum: ["board", "read"],
          description: "board (default) lists tickets; read returns one",
        },
        column: {
          type: "string",
          enum: ["open", "in-progress", "review", "done"],
          description: "limit the board to one column, or name the ticket's column for read",
        },
        filename: {
          type: "string",
          description: "for action=read: the ticket's filename, e.g. feature-0003-uw-….md",
        },
        query: {
          type: "string",
          description: "for action=board: only tickets whose text contains this",
        },
        sections: {
          type: "boolean",
          description:
            "for action=read: return only the contract sections (Problem, Impact, " +
            "Requirements, Non-goals, Test cases, Constraints) rather than the whole file",
        },
      },
    },
    async execute(_id: string, params: any) {
      if (!rootExists()) {
        return bad(
          `no Excalidraw fork at ${root()} — set EXCALIDRAW_ROOT to the checkout.`,
        );
      }

      if (params?.action === "read") {
        if (!params?.filename) {
          return bad("action=read needs a filename.");
        }
        const column = (params?.column ?? "open") as Column;
        const ticket = await readTicket(String(column), String(params.filename), root());
        if ("error" in ticket) {
          return bad(ticket.error);
        }
        if (params?.sections) {
          const sections = contractSections(ticket.markdown);
          const text = Object.entries(sections)
            .map(([name, body]) => `## ${name}\n${body}`)
            .join("\n\n");
          return ok(text || "(no contract sections found in that ticket)");
        }
        return ok(ticket.markdown);
      }

      const column = isColumn(params?.column) ? (params.column as Column) : undefined;
      const tickets = await listTickets(root(), {
        ...(column ? { column } : {}),
        ...(params?.query ? { query: String(params.query) } : {}),
      });

      if (!tickets.length) {
        return ok("no tickets match.");
      }

      const lines: string[] = [];
      for (const name of ["open", "in-progress", "review", "done"]) {
        const inColumn = tickets.filter((ticket) => ticket.column === name);
        if (!inColumn.length) {
          continue;
        }
        lines.push(`${name.toUpperCase()} (${inColumn.length})`);
        for (const ticket of inColumn) {
          const meta = [ticket.type, ticket.risk && `risk: ${ticket.risk}`, ticket.owner]
            .filter(Boolean)
            .join(" · ");
          lines.push(`  ${ticket.filename}`);
          lines.push(`    ${ticket.title}`);
          if (meta) {
            lines.push(`    ${meta}`);
          }
          for (const problem of ticket.problems) {
            lines.push(`    ⚠ ${problem}`);
          }
        }
        lines.push("");
      }
      lines.push(`${tickets.length} ticket${tickets.length === 1 ? "" : "s"}.`);
      return ok(lines.join("\n"));
    },
  });

  pi.registerTool({
    name: "excalidraw_servers",
    description:
      "The Excalidraw fork's three services, as status / start / stop. " +
      "board (:4174) reads tickets over HTTP; bridge (:4173) answers the AI panel " +
      "and needs TTD_MODEL_BASE_URL; collab (:3002) is the room server. Actions are " +
      "probes and spawns, never a blanket pkill — stop kills only the pid holding " +
      "the port. Use status first; start only what you need.",
    parameters: {
      type: "object",
      properties: {
        action: {
          type: "string",
          enum: ["status", "start", "stop"],
          description: "status (default), start, or stop",
        },
        service: {
          type: "string",
          enum: ["board", "bridge", "collab"],
          description: "which service; omit to act on all three",
        },
        modelBaseURL: {
          type: "string",
          description:
            "for action=start on the bridge: the OpenAI-compatible base, e.g. " +
            "http://127.0.0.1:8080/v1. The bridge refuses to start without one.",
        },
        model: {
          type: "string",
          description: "for action=start on the bridge: a default model id",
        },
      },
    },
    async execute(_id: string, params: any) {
      if (!rootExists()) {
        return bad(
          `no Excalidraw fork at ${root()} — set EXCALIDRAW_ROOT to the checkout.`,
        );
      }
      const action = params?.action ?? "status";
      const wanted = params?.service;

      if (wanted && !isServiceName(wanted)) {
        return bad(`'${wanted}' is not a service. Use board, bridge or collab.`);
      }

      if (action === "status") {
        const rows = await status(wanted);
        return ok(
          rows
            .map(
              (row) =>
                `${row.running ? "● up  " : "○ down"} ${row.name.padEnd(7)} :${row.port}  ${row.purpose}\n` +
                `         health: ${JSON.stringify(row.health)}`,
            )
            .join("\n"),
        );
      }

      if (action === "start") {
        const names = wanted ? [wanted] : (Object.keys(SERVICES) as any[]);
        const results: string[] = [];
        for (const name of names) {
          const env: Record<string, string | undefined> = {};
          if (name === "bridge") {
            env.TTD_MODEL_BASE_URL =
              params?.modelBaseURL ?? process.env.TTD_MODEL_BASE_URL ?? "";
            if (params?.model) {
              env.TTD_MODEL = String(params.model);
            }
          }
          const result = await start(name, env);
          results.push(`${result.ok ? "✔" : "✖"} ${result.detail}`);
        }
        return ok(results.join("\n"));
      }

      if (action === "stop") {
        const names = wanted ? [wanted] : (Object.keys(SERVICES) as any[]);
        const results: string[] = [];
        for (const name of names) {
          const result = await stop(name);
          results.push(`${result.ok ? "✔" : "✖"} ${result.detail}`);
        }
        return ok(results.join("\n"));
      }

      return bad(`unknown action '${action}'`);
    },
  });

  pi.registerTool({
    name: "excalidraw_app",
    description:
      "The Excalidraw desktop app (an Electron window over the local dev server on " +
      ":4172). action=start raises it, action=stop lowers it, action=status reports. " +
      "This is what the operator opens as `Excalidraw` from the launcher.",
    parameters: {
      type: "object",
      properties: {
        action: {
          type: "string",
          enum: ["status", "start", "stop"],
          description: "status (default), start, or stop",
        },
      },
    },
    async execute(_id: string, params: any) {
      if (!rootExists()) {
        return bad(
          `no Excalidraw fork at ${root()} — set EXCALIDRAW_ROOT to the checkout.`,
        );
      }
      const script = join(root(), "scripts", params?.action === "stop" ? "stop.sh" : "start.sh");
      if (!existsSync(script)) {
        return bad(`missing ${script} — the fork's start/stop scripts are not there.`);
      }

      if ((params?.action ?? "status") === "status") {
        try {
          const response = await fetch("http://127.0.0.1:4172/", {
            signal: AbortSignal.timeout(1200),
          });
          return ok(`the app's dev server answers on :4172 (${response.status}).`);
        } catch (error) {
          return ok(
            `the app is not up on :4172 (${(error as Error)?.message ?? error}).`,
          );
        }
      }

      const action = params.action === "stop" ? "stop.sh" : "start.sh";
      const child = spawn(join(root(), "scripts", action), [], {
        cwd: root(),
        detached: true,
        stdio: "ignore",
      });
      child.unref();
      return ok(
        `${action} launched (detached). The window raises itself; check with action=status in a few seconds.`,
      );
    },
  });

  // Nothing is started here. This only says — once, plainly — whether the fork
  // is where the extension expects, because every tool above is useless if not.
  pi.on("session_start", async () => {
    if (!rootExists()) {
      console.error(
        `[excalidraw] no fork at ${root()} — set EXCALIDRAW_ROOT to the checkout.`,
      );
      return;
    }
    const rows = await status();
    const up = rows.filter((row) => row.running).map((row) => `${row.name}:${row.port}`);
    console.error(
      `[excalidraw] fork at ${root()} — services up: ${up.length ? up.join(", ") : "none"}`,
    );
  });
}
