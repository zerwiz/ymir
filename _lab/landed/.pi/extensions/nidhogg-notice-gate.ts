/**
 * Níðhöggr — the gnawer at the root. Here it gnaws at the *noise*, not a worker:
 * it names the repeat and stops it before the repeat eats the hall.
 *
 * Why this file exists (the Allfather, 2026-10-21: "we need to handle this errors
 * better, they are breaking the ui in pi. both on phone and computers").
 *
 * An extension that writes to `console.warn`/`console.error` writes straight at the
 * terminal the TUI has taken over. A one-line warning is survivable; a multi-line
 * native load failure ("Require stack:", `dlopen failed: library … not found`)
 * printed once per message_end is not — it floods the bottom of the screen and paints
 * over the editor. Pi's own channel for this is `ctx.ui.notify()` and
 * `ctx.ui.setStatus()`, which redraw cleanly; a foreign package uses neither.
 *
 * So the house gates the console itself:
 *
 *   one line    a multi-line message is reported by its first line plus the count of
 *               the rest, never as a stack filling the screen
 *   one time    the same message is shown once per session; repeats are counted, not
 *               reprinted (Níðhöggr's whole trade: name the endless loop)
 *   the whole   the untouched text goes to <state>/pi-notices.log, so the detail is
 *   record      kept where a hand can read it — suppressed is not lost
 *   no UI, no   print/JSON/RPC have no TUI to protect, so there the collapsed line is
 *   gate        passed through the original writer, once
 *
 * It is a ward, not a tool: nothing calls it, it is installed when the extension
 * loads, and it must never throw into a turn.
 */

import { appendFileSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { resolveYmirRoot } from "./lib/ymir-home.ts";

type Level = "warning" | "error";

const GATE_FLAG = Symbol.for("ymir.pi.notice-gate");

interface GateState {
  seen: Map<string, number>;
  ctx: ExtensionContext | null;
}

/** One gate per process, however many times the extension tree is loaded. */
type GlobalWithGate = typeof globalThis & { [GATE_FLAG]?: GateState };
const globalGate = globalThis as GlobalWithGate;

const extensionDir = dirname(fileURLToPath(import.meta.url));

function logPath(): string {
  const state =
    process.env.BROKK_STATE_OVERRIDE?.trim() ||
    join(resolveYmirRoot(extensionDir), "state");
  return join(state, "pi-notices.log");
}

function textOf(args: unknown[]): string {
  return args
    .map((value) => {
      if (typeof value === "string") return value;
      if (value instanceof Error) return `${value.name}: ${value.message}`;
      try {
        return JSON.stringify(value);
      } catch {
        return String(value);
      }
    })
    .join(" ");
}

/** The first line that carries words, and how many further lines were dropped. */
function collapse(text: string): { line: string; extra: number } {
  const lines = text.split(/\r?\n/);
  const firstIndex = lines.findIndex((line) => line.trim() !== "");
  if (firstIndex === -1) return { line: "", extra: 0 };
  const line = lines[firstIndex].trim();
  const extra = lines.slice(firstIndex + 1).filter((l) => l.trim() !== "").length;
  return { line, extra };
}

function shorten(line: string): string {
  const home = homedir();
  let out = home && line.includes(home) ? line.split(home).join("~") : line;
  if (out.length > 240) out = `${out.slice(0, 237)}…`;
  return out;
}

function record(level: Level, line: string, extra: number, times: number, full: string): void {
  try {
    const path = logPath();
    mkdirSync(dirname(path), { recursive: true });
    const stamp = new Date().toISOString();
    const note = extra > 0 ? ` (${extra} more lines)` : "";
    const repeat = times > 1 ? ` (seen ${times}x)` : "";
    appendFileSync(path, `[${stamp}] ${level}: ${line}${note}${repeat}\n${full.trim()}\n`);
  } catch {
    // A gate that throws is a second fault, not a ward.
  }
}

function gate(level: Level, original: (...args: unknown[]) => void, args: unknown[]): void {
  const state = globalGate[GATE_FLAG];
  if (!state) {
    original(...args);
    return;
  }

  const full = textOf(args);
  const { line, extra } = collapse(full);
  if (!line) return;

  const key = `${level}:${line}`;
  const times = (state.seen.get(key) ?? 0) + 1;
  state.seen.set(key, times);

  record(level, shorten(line), extra, times, full);
  if (times > 1) return;

  const shown = shorten(line) + (extra > 0 ? ` (+${extra} lines — see state/pi-notices.log)` : "");
  const ctx = state.ctx;
  if (ctx?.hasUI) {
    try {
      ctx.ui.notify(shown, level);
      return;
    } catch {
      // fall through to the original writer
    }
  }
  original(shown);
}

function install(): GateState {
  const existing = globalGate[GATE_FLAG];
  if (existing) return existing;

  const state: GateState = { seen: new Map(), ctx: null };
  globalGate[GATE_FLAG] = state;

  const originalWarn = console.warn.bind(console);
  const originalError = console.error.bind(console);

  console.warn = (...args: unknown[]) => gate("warning", originalWarn, args);
  console.error = (...args: unknown[]) => gate("error", originalError, args);

  return state;
}

export default function (pi: ExtensionAPI) {
  const state = install();

  pi.on("session_start", (_event, ctx) => {
    state.seen.clear();
    state.ctx = ctx;
  });

  pi.on("session_shutdown", () => {
    state.ctx = null;
  });
}
