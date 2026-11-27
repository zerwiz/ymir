import { spawn } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Plugin } from "@opencode/plugin";

// A turn started by a stamped message answers its sender. Thin: it hands the turn's messages and final answer to
// bin/agents/reply.sh --turn-end, which decides who is owed, once, and never answers a reply.

function resolveRoot() {
  const pointer = join(homedir(), ".pi", "agent", "extensions", ".ymir-root");
  const recorded = existsSync(pointer) ? readFileSync(pointer, "utf8").split("\n") : [];
  for (const root of [process.env.YMIR_ROOT, ...recorded, join(homedir(), "ymir-runtime")]) {
    if (root?.trim() && existsSync(join(root.trim(), "bin", "agents", "reply.sh"))) return root.trim();
  }
  return "";
}

// The last turn: the user messages that arrived after the previous finished answer, and the newest answer.
export function lastTurn(history) {
  let messages = [];
  let answer = "";
  let closed = false;
  for (const entry of history) {
    if (entry.type === "user" || entry.type === "synthetic") {
      if (closed) {
        messages = [];
        answer = "";
        closed = false;
      }
      messages.push({
        id: entry.id,
        text: entry.text,
        since: (entry.time?.created ?? 0) / 1000,
        synthetic: entry.type === "synthetic",
      });
    } else if (entry.type === "assistant") {
      const text = (entry.content ?? []).filter((p) => p.type === "text").map((p) => p.text).join("\n");
      if (text) answer = text;
      if (entry.finish === "stop") closed = true;
    }
  }
  return { messages, answer: closed ? answer : "" };
}

export default Plugin.define({
  id: "ymir.reply-back",
  async setup(ctx) {
    const controller = new AbortController();
    void (async () => {
      for await (const event of ctx.event.subscribe({ types: ["session.idle"], signal: controller.signal })) {
        const sessionID = event.data?.sessionID;
        const root = resolveRoot();
        if (!sessionID || !root) continue;
        try {
          const turn = lastTurn(await ctx.session.context({ sessionID }));
          if (!turn.answer) continue;
          const child = spawn("bash", [join(root, "bin", "agents", "reply.sh"), "--turn-end"], {
            stdio: ["pipe", "ignore", "ignore"],
            timeout: 140_000,
          });
          child.on("error", () => {});
          child.stdin.on("error", () => {});
          child.stdin.end(JSON.stringify({ session: sessionID, answered_at: Date.now() / 1000, ...turn }));
        } catch {
          // a history that cannot be read answers nobody; it never breaks the session
        }
      }
    })().catch(() => {});
    return () => controller.abort();
  },
});
