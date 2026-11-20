// Vörðr — session-start digest supervisor.
//
// Vörðr ("warden/guardian") is the thin process supervisor that runs the Sága
// session-start digest as a detached child so Pi can stream and cap its output
// without blocking the session open. Ported from the upstream agent-distro reference.
import { spawn } from "node:child_process";

const [runner, ...args] = process.argv.slice(2);
let runnerCode;
let outputBytes = 0;
let pendingWrites = 0;
let resultSent = false;

const sendResult = () => {
  if (resultSent || runnerCode === undefined || pendingWrites !== 0) return;
  resultSent = true;
  process.send?.({ type: "result", code: runnerCode, bytes: outputBytes });
};

process.on("SIGTERM", () => {});
process.on("disconnect", () => {
  try {
    process.kill(-process.pid, "SIGKILL");
  } catch {
    process.exit(1);
  }
});

const child = spawn(runner, args, {
  env: { ...process.env, VORDR_SESSIONSTART_SUPERVISOR_PID: String(process.pid) },
  stdio: ["ignore", "pipe", "ignore"],
});
child.stdout.on("data", (chunk) => {
  outputBytes += chunk.length;
  pendingWrites += 1;
  process.stdout.write(chunk, () => {
    pendingWrites -= 1;
    sendResult();
  });
});
child.on("error", () => {
  runnerCode = null;
  sendResult();
});
child.on("close", (code) => {
  runnerCode = code;
  sendResult();
});
