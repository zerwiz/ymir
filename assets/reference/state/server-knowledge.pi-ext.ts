// Firstmate semantic busy-state events + turn-end notification; written by
// fm-spawn under the contract owned by bin/fm-busy-lib.sh.
// Semantic state: "agent_start" -> busy when a low-level agent run begins;
// "agent_settled" -> idle only when ctx.isIdle() confirms Pi will not
// continue automatically - auto-retries, auto-compaction retries, tool
// loops, and queued continuations all keep the run un-settled, and a settle
// that raced another extension's fresh run keeps state busy via isIdle().
// "turn_end" fires at every inner turn boundary (one LLM response plus its
// tool calls) and stays a wake NOTIFICATION touch for the watcher, never
// current-state truth.
import { execFile } from "node:child_process";
const busyEvent = (state: string, event: string) =>
  new Promise<void>((resolve) => {
    execFile("/home/zerwiz/firstmate/bin/fm-busy-event.sh", [
      "apply", "/home/zerwiz/firstmate/state", "server-knowledge", state,
      "--gen", "g1788541722.1083906.12288", "--source", "pi-ext", "--event", event,
    ], () => resolve());
  });
export default function (pi: any) {
  pi.on("agent_start", () => busyEvent("busy", "agent-start"));
  pi.on("agent_settled", (_event: any, ctx: any) => {
    if (ctx && typeof ctx.isIdle === "function" && !ctx.isIdle()) return;
    return busyEvent("idle", "agent-settled");
  });
  pi.on("turn_end", () => execFile("touch", ["/home/zerwiz/firstmate/state/server-knowledge.turn-ended"]));
}
