/**
 * reply-back — a turn started by a stamped message answers its sender.
 *
 * THIN by construction: it collects the messages that entered the run (the opening prompt and any line steered
 * into it) and the final answer, and hands them to bin/agents/reply.sh --turn-end, which decides who is owed,
 * once, and never answers a reply.
 */

import { spawn } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

function resolveRoot(): string {
  const pointer = join(homedir(), ".pi", "agent", "extensions", ".ymir-root");
  const recorded = existsSync(pointer) ? readFileSync(pointer, "utf8").split("\n") : [];
  for (const root of [process.env.YMIR_ROOT, ...recorded]) {
    if (root?.trim() && existsSync(join(root.trim(), "bin", "agents", "reply.sh"))) return root.trim();
  }
  return "";
}

function textOf(message: any): string {
  const content = message?.content;
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content.filter((part: any) => part?.type === "text").map((part: any) => String(part.text)).join("\n");
}

export default function replyBack(pi: any) {
  const session = `pi-${process.pid}-${Date.now()}`;

  pi.on("agent_end", async (event: any) => {
    const messages: { id: string; text: string; since: number }[] = [];
    let answer = "";
    let answered_at = 0;
    for (const message of event?.messages ?? []) {
      if (message?.role === "user") {
        const stamp = Number(message.timestamp) || 0;
        messages.push({ id: String(stamp || messages.length), text: textOf(message), since: stamp / 1000 });
      } else if (message?.role === "assistant") {
        // an aborted or failed turn has no answer to send
        const said = textOf(message);
        if (["aborted", "error"].includes(message.stopReason)) answer = "";
        else if (said) [answer, answered_at] = [said, Date.now() / 1000];
      }
    }
    const root = resolveRoot();
    if (!root || !answer) return;
    await new Promise<void>((done) => {
      const child = spawn("bash", [join(root, "bin", "agents", "reply.sh"), "--turn-end"], {
        stdio: ["pipe", "ignore", "ignore"],
        timeout: 140_000,
      });
      child.on("error", () => done());
      child.on("close", () => done());
      child.stdin.on("error", () => {});
      child.stdin.end(JSON.stringify({ session, answer, answered_at, messages }));
    });
  });
}
