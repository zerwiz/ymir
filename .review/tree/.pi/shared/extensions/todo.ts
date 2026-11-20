/**
 * Todo — opencode-style task tracker for pi.
 *
 * Session-scoped todo list with 4 statuses and 3 priorities.
 * State stored in session entries (survives branching).
 */

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { matchesKey, Text, truncateToWidth } from "@earendil-works/pi-tui";
import { Type } from "typebox";

interface Todo {
  content: string;
  status: "pending" | "in_progress" | "completed" | "cancelled";
  priority: "high" | "medium" | "low";
}

interface TodoDetails {
  action: string;
  todos: Todo[];
  error?: string;
}

const StatusEnum = Type.Unsafe({ type: "string", enum: ["pending", "in_progress", "completed", "cancelled"] });
const PriorityEnum = Type.Unsafe({ type: "string", enum: ["high", "medium", "low"] });

const TodoParams = Type.Object({
  action: Type.Unsafe({ type: "string", enum: ["list", "add", "update", "remove", "clear", "replace"], description: "Action: list, add, update, remove, clear, replace" }),
  content: Type.Optional(Type.String({ description: "Task description (for add/update)" })),
  priority: Type.Optional(PriorityEnum),
  index: Type.Optional(Type.Number({ description: "Todo index 0-based (for update/remove)" })),
  status: Type.Optional(StatusEnum),
  todos: Type.Optional(Type.Array(Type.Object({ content: Type.String(), status: StatusEnum, priority: PriorityEnum }), { description: "Full todo list (for replace)" })),
});

let todos: Todo[] = [];

function reconstructState(ctx: ExtensionContext) {
  todos = [];
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message") continue;
    const msg = entry.message;
    if (msg.role !== "toolResult" || msg.toolName !== "todo") continue;
    const details = msg.details as TodoDetails | undefined;
    if (details?.todos) todos = [...details.todos];
  }
}

const STATUS_ICONS: Record<string, string> = { pending: "○", in_progress: "►", completed: "✓", cancelled: "✗" };
const PRIORITY_LABELS: Record<string, string> = { high: "HIGH", medium: "med", low: "low" };

function formatTodoList(t: Todo[], theme: Theme, expanded: boolean): string {
  if (t.length === 0) return theme.fg("dim", "No todos.");
  const active = t.filter(x => x.status !== "completed" && x.status !== "cancelled");
  const done = t.filter(x => x.status === "completed");
  let out = theme.fg("muted", `${active.length} active, ${done.length} done`);
  const display = expanded ? t : t.slice(0, 10);
  for (let i = 0; i < display.length; i++) {
    const todo = display[i];
    const icon = STATUS_ICONS[todo.status] ?? "?";
    const iconColor = todo.status === "completed" ? "success" : todo.status === "cancelled" ? "dim" : todo.status === "in_progress" ? "accent" : "muted";
    const pri = PRIORITY_LABELS[todo.priority] ?? "";
    const priColor = todo.priority === "high" ? "error" : todo.priority === "medium" ? "warning" : "dim";
    let line = ` ${theme.fg(iconColor, icon)} ${theme.fg("accent", String(i))}`;
    if (pri) line += ` ${theme.fg(priColor, pri.padEnd(4))}`;
    line += ` ${todo.status === "completed" || todo.status === "cancelled" ? theme.fg("dim", todo.content) : theme.fg("text", todo.content)}`;
    out += "\n" + truncateToWidth(line, 80);
  }
  if (!expanded && t.length > 10) out += `\n ${theme.fg("dim", `... ${t.length - 10} more`)}`;
  return out;
}

class TodoUI {
  private todoList: Todo[];
  private theme: Theme;
  private onClose: () => void;
  constructor(todoList: Todo[], theme: Theme, onClose: () => void) { this.todoList = todoList; this.theme = theme; this.onClose = onClose; }
  handleInput(data: string): void { if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) this.onClose(); }
  render(width: number): string[] {
    const lines: string[] = []; const th = this.theme;
    lines.push(""); const title = th.fg("accent", " Todos ");
    lines.push(truncateToWidth(th.fg("borderMuted", "─".repeat(3)) + title + th.fg("borderMuted", "─".repeat(Math.max(0, width - 10))), width));
    lines.push(""); lines.push(formatTodoList(this.todoList, th, true));
    lines.push(""); lines.push(truncateToWidth(`  ${th.fg("dim", "Escape to close")}`, width)); lines.push("");
    return lines;
  }
}

export default function todoExtension(pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => reconstructState(ctx));
  pi.on("session_tree", async (_event, ctx) => reconstructState(ctx));

  pi.registerTool({
    name: "todo", label: "Todo",
    description: "Manage a task list. Actions: list, add, update, remove, clear, replace",
    promptSnippet: "Track multi-step work with todo list",
    promptGuidelines: ["Use todo when work has 3+ steps or user provides multiple tasks.", "Mark exactly ONE todo as in_progress at a time.", "Mark tasks completed only after verification."],
    parameters: TodoParams,
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const action = params.action as string;
      switch (action) {
        case "list": return { content: [{ type: "text", text: todos.length ? todos.map((t, i) => `${i}: [${t.status}] [${t.priority}] ${t.content}`).join("\n") : "No todos." }], details: { action: "list", todos: [...todos] } as TodoDetails };
        case "add": { if (!params.content) throw new Error("content required for add"); const priority = (params.priority as any) ?? "medium"; const newTodo: Todo = { content: params.content, status: "pending", priority }; todos.push(newTodo); return { content: [{ type: "text", text: `Added #${todos.length - 1}: ${newTodo.content}` }], details: { action: "add", todos: [...todos] } as TodoDetails }; }
        case "update": { if (params.index === undefined) throw new Error("index required for update"); const idx = params.index; if (idx < 0 || idx >= todos.length) throw new Error(`Index ${idx} out of range`); const todo = todos[idx]; if (params.status) { if (params.status === "in_progress") { const existing = todos.find(t => t.status === "in_progress"); if (existing && existing !== todo) existing.status = "pending"; } todo.status = params.status as any; } if (params.priority) todo.priority = params.priority as any; if (params.content) todo.content = params.content; return { content: [{ type: "text", text: `Updated #${idx}: [${todo.status}] [${todo.priority}] ${todo.content}` }], details: { action: "update", todos: [...todos] } as TodoDetails }; }
        case "remove": { if (params.index === undefined) throw new Error("index required for remove"); const idx = params.index; if (idx < 0 || idx >= todos.length) throw new Error(`Index ${idx} out of range`); const removed = todos.splice(idx, 1)[0]; return { content: [{ type: "text", text: `Removed #${idx}: ${removed.content}` }], details: { action: "remove", todos: [...todos] } as TodoDetails }; }
        case "clear": { const count = todos.length; todos = []; return { content: [{ type: "text", text: `Cleared ${count} todos.` }], details: { action: "clear", todos: [] } as TodoDetails }; }
        case "replace": { if (!params.todos) throw new Error("todos array required for replace"); todos = params.todos.map((t: any) => ({ content: t.content, status: t.status, priority: t.priority })); return { content: [{ type: "text", text: `Replaced with ${todos.length} todos.` }], details: { action: "replace", todos: [...todos] } as TodoDetails }; }
        default: throw new Error(`Unknown action: ${action}`);
      }
    },
    renderCall(args, theme) {
      let text = theme.fg("toolTitle", theme.bold("todo ")) + theme.fg("muted", args.action);
      if (args.content) text += ` ${theme.fg("dim", `"${args.content}"`)}`;
      if (args.index !== undefined) text += ` ${theme.fg("accent", `#${args.index}`)}`;
      if (args.todos) text += ` ${theme.fg("muted", `(${args.todos.length} items)`)}`;
      return new Text(text, 0, 0);
    },
    renderResult(result, { expanded }, theme) {
      const details = result.details as TodoDetails | undefined;
      if (!details) { const c = result.content[0]; return new Text(c?.type === "text" ? c.text : "", 0, 0); }
      if (details.error) return new Text(theme.fg("error", `Error: ${details.error}`), 0, 0);
      return new Text(formatTodoList(details.todos, theme, expanded), 0, 0);
    },
  });

  pi.registerCommand("todos", {
    description: "Show the current todo list",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") { ctx.ui.notify("/todos requires interactive mode", "error"); return; }
      await ctx.ui.custom<void>((_tui, theme, _kb, done) => { return new TodoUI(todos, theme, () => done()); });
    },
  });
}
