/**
 * herdr — where the work actually is, in EITHER backend.
 *
 * The Allfather, 2026-10-01: *"for herdr find all were using for that now"* and *"could we also
 * support tmux maybe in this extension"*. Both answered here.
 *
 * What already exists (surveyed 2026-10-01, so this door DUPLICATES NONE of it):
 *   bin/seat/herdr-agents.py      the seat/agent inventory
 *   bin/seat/herdr-ensure.sh      guarantee the terminal backend Ymir needs
 *   bin/seat/herdr-run.sh         raise an Eindri, by the grain the errand fits
 *   bin/eindri-{control,seat,send}.sh   the errand's own seat + steering
 *   .pi/shared/extensions/herdr-agent-state.ts   reports agent state into the pane
 *
 * So this door registers ONLY what is distinctLY its own:
 *   ymir_seats       every seat and errand, in whichever backend is live, and DEAD ones named
 *   ymir_close_dead  close a shell whose owner is gone; REFUSE a live one
 *
 * **tmux support is not a nicety.** The house law is herdr-first with tmux as the fallback
 * (`einherjar-spawn.sh`), so a seats door that only spoke herdr would be blind precisely when
 * herdr is down — the moment you most need to see what is stranded.
 *
 * OpenRig was read as the reference and is deliberately NOT copied: it is a rival rig with its own
 * kernel, TUI and queue on cmux. The one lesson worth taking is its death-check — a seat whose
 * owning process is gone is a fact, not a pane.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";


// ── resolution: this file must run on ANY seat, so it may not know a machine ──
// (Rule 07. 2026-10-03: this extension carried a hardcoded `/home/heimdall/ymir`.)
// This is the JS mirror of `ymir_root_verified` in bin/seat/valknut-load.sh — same contract,
// same order: $YMIR_ROOT, then the recorded roots, first one that really holds the house.
// One reader in the shell, one here; they must agree, or a worktree seat reads a dead path.
function resolveRoot(): string {
  const fromEnv = process.env.YMIR_ROOT?.trim();
  if (fromEnv) return fromEnv;
  const pointer = join(homedir(), ".pi", "agent", "extensions", ".ymir-root");
  if (existsSync(pointer)) {
    for (const line of readFileSync(pointer, "utf8").split("\n")) {
      const root = line.trim();
      if (!root) continue;
      if (existsSync(join(root, "bin"))) return root;
    }
  }
  throw new Error(
    "YMIR_ROOT is not set and ~/.pi/agent/extensions/.ymir-root holds no usable root. " +
    "Run `bin/seat/valknut-load.sh --all --global` from your Ymir checkout — install records " +
    "the root, and every extension reads it from there.",
  );
}

const ROOT = resolveRoot();

function run(cmd: string, args: string[], quiet = false): string {
  try {
    return execFileSync(cmd, args, { encoding: "utf8", stdio: quiet ? ["ignore", "pipe", "ignore"] : "pipe" }).trim();
  } catch {
    return "";
  }
}
function alive(pid: string): boolean {
  if (!/^[0-9]+$/.test(pid)) return false;
  try { process.kill(Number(pid), 0); return true; } catch { return false; }
}

/** herdr's own inventory, in its own JSON — not parsed out of prose. */
function herdrSeats(): Array<{ id: string; agent: string; status: string; cwd: string }> {
  const raw = run("hdr", ["pane", "list"], true);
  if (!raw) return [];
  try {
    const panes = (JSON.parse(raw).result?.panes ?? []) as any[];
    return panes.map((p) => ({
      id: p.pane_id ?? "?",
      agent: p.agent ?? "—",
      status: p.agent_status ?? "unknown",
      cwd: p.cwd ?? "",
    }));
  } catch { return []; }
}

/** tmux is the fallback, so it is read natively — not shimmed through herdr. */
function tmuxSeats(): Array<{ id: string; agent: string; status: string; cwd: string }> {
  const raw = run("tmux", ["list-panes", "-a", "-F",
    "#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_pid}"], true);
  if (!raw) return [];
  return raw.split("\n").filter(Boolean).map((l) => {
    const [id, cmd, cwd, pid] = l.split("\t");
    const live = alive((pid ?? "").trim());
    return { id, agent: cmd || "shell", status: live ? "running" : "DEAD", cwd };
  });
}

function errandRecords(): Array<{ id: string; backend: string; status: string; launched: string }> {
  const dir = `${ROOT}/state`;
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((f) => f.endsWith(".meta"))
    .map((f) => {
      const t = readFileSync(`${dir}/${f}`, "utf8");
      const get = (k: string) => (new RegExp(`^${k}=(.*)$`, "m").exec(t)?.[1] ?? "");
      return { id: f.replace(/\.meta$/, ""), backend: get("backend"), status: get("worktree") ? "seated" : "?", launched: get("launch_iso") };
    });
}

function render(): string {
  const h = herdrSeats();
  const t = tmuxSeats();
  const recs = errandRecords();
  const out: string[] = [];
  out.push(`seats[2]{herdr,tmux}:`);
  out.push(`  "${h.length}","${t.length}"`);
  const live = h.length ? "herdr" : t.length ? "tmux" : "none";
  out.push(`backend in use: ${live}${h.length && t.length ? "  (both are up — the house law is herdr-first, tmux fallback)" : ""}`);
  out.push("");
  if (h.length) {
    out.push("herdr panes:");
    for (const p of h) out.push(`  ${p.id.padEnd(9)} ${String(p.agent).padEnd(12)} ${p.status.padEnd(9)} ${p.cwd}`);
  }
  if (t.length) {
    out.push("tmux panes:");
    for (const p of t) out.push(`  ${p.id.padEnd(9)} ${String(p.agent).padEnd(12)} ${p.status.padEnd(9)} ${p.cwd}`);
  }
  const dead = t.filter((p) => p.status === "DEAD");
  out.push("");
  out.push(`dead shells: ${dead.length}${dead.length ? "  → " + dead.map((d) => d.id).join(", ") : ""}`);
  if (recs.length) {
    out.push("");
    out.push(`errands[${recs.length}]{id,backend,launched}:`);
    for (const r of recs.slice(0, 20)) out.push(`  ${r.id.padEnd(24)} ${(r.backend || "?").padEnd(8)} ${r.launched}`);
  }
  out.push("");
  out.push("a shell whose owner is gone is DEAD: it outlived its errand and cannot answer. Close it with ymir_close_dead.");
  return out.join("\n");
}


// Pi 1.0's tool contract: the model-facing text is `content`, and THROWING is how a tool
// reports failure — returning an object does not mark it as an error. `output:` reached the
// model as an empty success while the harness called a key that did not exist.
const piOut = (text: unknown): { content: { type: "text"; text: string }[]; details: undefined } => ({
  content: [{ type: "text", text: String(text) }],
  details: undefined,
});

export default function herdr(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ymir_seats",
    description:
      "Where the work actually is: every pane and errand in EITHER backend (herdr first, tmux " +
      "fallback), with DEAD shells named — a shell whose owning process is gone cannot answer, and " +
      "three outlived their errands during the failed launches. Thin: it reads herdr's own JSON and " +
      "tmux natively; it does not re-implement bin/herdr-*.sh.",
    parameters: { type: "object", properties: { backend: { type: "string", description: "herdr | tmux — omit for both" } } },
    execute: async (_toolCallId: string) => piOut(render()),
  });

  pi.registerTool({
    name: "ymir_close_dead",
    description:
      "Close a shell whose owner is GONE. Refuses a live seat — this closes stranded shells, not " +
      "running work. Reports what it closed and what it refused.",
    parameters: {
      type: "object",
      properties: { target: { type: "string", description: "session:window.pane (tmux) or pane id (herdr)" } },
      required: ["target"],
    },
    execute: async (_toolCallId: string, args: any) => {
      const target = String(args.target);
      const out: string[] = [];
      // tmux: re-read liveness immediately before closing — never close on a stale reading
      const row = tmuxSeats().find((p) => p.id === target);
      if (row) {
        if (row.status !== "DEAD") {
          out.push(`refused: ${target} is LIVE (${row.agent}, ${row.cwd}) — this closes stranded shells, not running work.`);
          return piOut(out.join("\n"));
        }
        run("tmux", ["kill-pane", "-t", target], true);
        out.push(`closed dead tmux pane ${target}`);
        return piOut(out.join("\n"));
      }
      const hp = herdrSeats().find((p) => p.id === target);
      if (hp) {
        out.push(`refused: ${target} is a LIVE herdr pane (${hp.agent}, ${hp.status}) — closing a live pane needs a human.`);
        return piOut(out.join("\n"));
      }
      out.push(`refused: no seat named ${target} in either backend. ymir_seats lists them.`);
      return piOut(out.join("\n"));
    },
  });
}