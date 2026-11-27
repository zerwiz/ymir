/**
 * gna-telegram-follow — a pi session that holds the arm connects the machine's Telegram bot by itself.
 *
 * bin/notify/telegram-reader.sh moves the bot's token into pi's config when the arm moves here. pi-telegram
 * connects only at a session start or on /telegram-connect, so this runs that command for a session already
 * running. The door decides (`wants pi`): the home opted in, THIS session holds the arm, the token is in
 * place and nothing reads yet, so the command never meets a takeover question.
 */

import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

const BEAT_MS = Number(process.env.YMIR_TELEGRAM_FOLLOW_MS || 10000);
const RETRY_MS = 60000;
const COMMAND = "telegram-connect";

function resolveRoot(): string {
  const candidates = [process.env.YMIR_ROOT?.trim() ?? ""];
  const pointer = join(homedir(), ".pi", "agent", "extensions", ".ymir-root");
  if (existsSync(pointer)) candidates.push(...readFileSync(pointer, "utf8").split("\n").map((l) => l.trim()));
  return candidates.find((root) => root && existsSync(join(root, "bin", "notify", "telegram-reader.sh"))) ?? "";
}

// The cheap test first: only the machine's primary lock owner ever starts the door.
function holdsTheArm(): boolean {
  const primary = join(process.env.XDG_STATE_HOME || join(homedir(), ".local", "state"), "ymir");
  const dir = process.env.BROKK_MACHINE_STATE_DIR || primary;
  if (resolve(dir) !== resolve(primary)) return false;
  try {
    return readFileSync(join(dir, "brokk.lock"), "utf8").trim() === String(process.pid);
  } catch {
    return false;
  }
}

export default function gnaTelegramFollow(pi: any) {
  let timer: ReturnType<typeof setInterval> | undefined;
  let busy = false;
  let lastTry = 0;

  const stop = () => {
    if (timer) clearInterval(timer);
    timer = undefined;
  };

  pi.on("session_start", async (_event: unknown, ctx: any) => {
    stop();
    const root = resolveRoot();
    if (!root) return;
    timer = setInterval(() => {
      if (busy || Date.now() - lastTry < RETRY_MS || !holdsTheArm()) return;
      // Without the command the text would reach the model as a prompt: never send it then.
      if (!pi.getCommands().some((c: any) => c.name === COMMAND) || !ctx.isIdle()) return;
      busy = true;
      execFile("bash", [join(root, "bin", "notify", "telegram-reader.sh"), "wants", "pi"], { timeout: 30000 }, (error) => {
        busy = false;
        if (error || !timer || !ctx.isIdle()) return;
        lastTry = Date.now();
        pi.sendUserMessage(`/${COMMAND}`, { expandPromptTemplates: true });
      });
    }, BEAT_MS);
    timer.unref?.();
  });

  pi.on("session_shutdown", async () => stop());
}
