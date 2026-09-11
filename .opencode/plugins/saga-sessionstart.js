import { spawn } from "node:child_process";
import { realpathSync } from "node:fs";
import { resolve } from "node:path";
import { encodeRoddOperationalInput } from "./lib/rodd-operational-input.js";

// Sága — Brokk primary session-start nudge for OpenCode.
//
// Sága ("the seeress who sees all that happens") delivers the session-start
// digest into model context. OpenCode is a nudge-tier surface: the plugin runs
// the run wrapper once per session id and injects its output through a native
// session prompt. Ported from the upstream agent-distro reference and
// retargeted to the Brokk runtime (docs/plans/29-brokk-distro-runtime.md).

const handledSessions = new Set();

function runProcess(command, args) {
  return new Promise((resolveResult) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "ignore"] });
    let stdout = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.on("error", () => resolveResult({ code: 0, stdout: "" }));
    child.on("close", (code) => resolveResult({ code: code ?? 0, stdout }));
  });
}

function resolvePath(anchor) {
  try {
    return realpathSync(anchor);
  } catch {
    return resolve(anchor);
  }
}

async function resolveRoot(anchor) {
  if (!anchor) return "";
  const result = await runProcess("git", ["-C", anchor, "rev-parse", "--show-toplevel"]);
  const root = result.stdout.trim();
  if (result.code === 0 && root) return root;
  return resolvePath(anchor);
}

export const SagaSessionstart = async ({ client, directory, worktree }) => {
  const root = worktree ? resolvePath(worktree) : await resolveRoot(directory);

  return {
    event: async ({ event }) => {
      if (event.type !== "session.created") return;
      const sessionID = event.properties?.info?.id ?? event.properties?.sessionID;
      if (!sessionID || handledSessions.has(sessionID) || !root) return;
      handledSessions.add(sessionID);

      const result = await runProcess(`${root}/bin/saga-sessionstart-run.sh`, []);
      if (result.code !== 0) return;
      const digest = result.stdout.trim();
      if (!digest) return;

      let text = digest;
      try {
        text = await encodeRoddOperationalInput(root, "session-start", digest);
      } catch {
        text = digest;
      }

      try {
        await client.session.promptAsync({
          path: { id: sessionID },
          body: {
            parts: [{ type: "text", text }],
          },
        });
      } catch {
      }
    },
  };
};
