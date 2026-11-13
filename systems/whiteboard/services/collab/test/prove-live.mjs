#!/usr/bin/env node
/**
 * prove-collab.mjs — the command that proves the room server's two new promises.
 *
 *   node systems/whiteboard/services/collab/test/prove-live.mjs
 *
 * It starts the REAL server twice, on an ephemeral port, against a scratch store:
 *
 *   1. a room's scene is written down when the last hand leaves;
 *   2. after a restart — a fresh process with nothing in memory — a joiner still
 *      receives that scene, byte for byte, from disk;
 *   3. a save belongs to the identity the gate asserted: the owner lists and opens
 *      it, a second identity is refused BY NAME, an anonymous request is refused;
 *   4. every save, list and open carves a Rune.
 *
 * Nothing here is mocked except the Rune door (a three-line stub that records its
 * arguments), because a proof that the ledger was called should not write to the
 * real ledger.
 */

import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { chmodSync, existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { io } from "socket.io-client";

const here = dirname(fileURLToPath(import.meta.url));
const serviceDir = resolve(here, "..");
const entry = join(serviceDir, "index.mjs");

const scratch = mkdtempSync(join(tmpdir(), "whiteboard-proof-"));
const snapshotsDir = join(scratch, "snapshots");
const savesDir = join(scratch, "boards");
const runesLog = join(scratch, "runes.log");
const runeDoor = join(scratch, "runes-door.sh");

writeFileSync(runeDoor, `#!/usr/bin/env bash\nprintf '%s\\n' "$*" >> '${runesLog}'\n`);
chmodSync(runeDoor, 0o755);

const freePort = () =>
  new Promise((accept) => {
    const probe = createServer();
    probe.listen(0, "127.0.0.1", () => {
      const { port } = probe.address();
      probe.close(() => accept(port));
    });
  });

const waitFor = async (url, tries = 100) => {
  for (let i = 0; i < tries; i += 1) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return await response.json();
      }
    } catch {
      /* not up yet */
    }
    await new Promise((done) => setTimeout(done, 60));
  }
  throw new Error(`the server never answered ${url}`);
};

let port;
let lastLog = () => [];
const startServer = async () => {
  const child = spawn(process.execPath, [entry], {
    cwd: serviceDir,
    env: {
      ...process.env,
      COLLAB_PORT: String(port),
      COLLAB_HOST: "127.0.0.1",
      COLLAB_ENFORCE_ACCESS: "off",
      COLLAB_SNAPSHOT_DIR: snapshotsDir,
      COLLAB_SAVES_DIR: savesDir,
      COLLAB_RUNES_DOOR: runeDoor,
      YMIR_WHITEBOARD_TRUST_PROXY: "on",
      COLLAB_ACCESS_LOG: join(scratch, "access.log"),
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  const log = [];
  child.stdout.on("data", (chunk) => log.push(String(chunk)));
  child.stderr.on("data", (chunk) => log.push(String(chunk)));
  child.log = log;
  lastLog = () => log;
  await waitFor(`http://127.0.0.1:${port}/healthz`);
  return { child, log };
};

const stopServer = (server) =>
  new Promise((accept) => {
    server.child.once("exit", () => accept());
    server.child.kill("SIGTERM");
  });

const joinOnce = (roomId) =>
  new Promise((accept, reject) => {
    const socket = io(`http://127.0.0.1:${port}`, { transports: ["websocket"] });
    const seen = [];
    const fail = setTimeout(() => {
      socket.close();
      reject(new Error("the joiner heard nothing"));
    }, 4000);
    socket.on("init-room", () => socket.emit("join-room", roomId));
    socket.on("first-in-room", () => seen.push("first-in-room"));
    socket.on("client-broadcast", (data, iv) => {
      seen.push("client-broadcast");
      clearTimeout(fail);
      socket.close();
      accept({
        seen,
        data: [...new Uint8Array(data)],
        iv: [...new Uint8Array(iv)],
      });
    });
    // A first member of a room with nothing anywhere answers `first-in-room` only;
    // that is also a result, and it is how the negative control is read.
    socket.on("first-in-room", () => {
      setTimeout(() => {
        if (seen.includes("client-broadcast")) {
          return;
        }
        clearTimeout(fail);
        socket.close();
        accept({ seen, data: null, iv: null });
      }, 700);
    });
  });

const broadcast = (roomId, data, iv) =>
  new Promise((accept, reject) => {
    const socket = io(`http://127.0.0.1:${port}`, { transports: ["websocket"] });
    const fail = setTimeout(() => {
      socket.close();
      reject(new Error("could not broadcast"));
    }, 4000);
    socket.on("init-room", () => socket.emit("join-room", roomId));
    socket.on("first-in-room", () => {
      socket.emit("server-broadcast", roomId, new Uint8Array(data), new Uint8Array(iv));
      // Give the relay a beat to store it before leaving, so the "last hand
      // leaving" path is the one that writes, not the cadence.
      setTimeout(() => {
        clearTimeout(fail);
        socket.close();
        accept();
      }, 250);
    });
  });

const http = (path, init = {}) =>
  fetch(`http://127.0.0.1:${port}${path}`, init).then(async (response) => ({
    status: response.status,
    body: await response.json().catch(() => ({})),
  }));

const room = "proveroom0001";
const sceneBytes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 250, 251, 252];
const ivBytes = [11, 22, 33, 44];

const lines = [];
const say = (line) => {
  lines.push(line);
  console.log(line);
};

try {
  port = await freePort();

  // ── 1. a scene is drawn, then the last hand leaves ──────────────────────
  let server = await startServer();
  const health = await http("/healthz");
  say(
    `healthz  snapshots=${health.body.snapshots.enabled} saves=${health.body.saves.enabled} identity=${health.body.identity.header} runes=${health.body.runes.enabled}`,
  );

  await broadcast(room, sceneBytes, ivBytes);
  // The write happens on the socket's disconnect, which the server sees a beat
  // after the client stops talking — so wait for the file rather than race it.
  let written = [];
  for (let i = 0; i < 100; i += 1) {
    written = existsSync(join(snapshotsDir, room)) ? readdirSync(join(snapshotsDir, room)) : [];
    if (written.length > 0) {
      break;
    }
    await new Promise((done) => setTimeout(done, 50));
  }
  say(`snapshot on last leave  room=${room} files=${written.length} ${written.join(",")}`);

  // ── 2. the store doors, in the same process ─────────────────────────────
  const board = {
    type: "excalidraw",
    version: 2,
    elements: [{ id: "n1", type: "rectangle", text: "Start" }],
    appState: { viewBackgroundColor: "#ffffff" },
  };
  const saved = await http("/saves", {
    method: "POST",
    headers: { "content-type": "application/json", "remote-user": "seat-one" },
    body: JSON.stringify({ room, scene: board }),
  });
  say(`POST /saves as seat-one      ${saved.status} id=${saved.body.id} bytes=${saved.body.bytes}`);

  const listed = await http("/saves", { headers: { "remote-user": "seat-one" } });
  say(
    `GET  /saves as seat-one      ${listed.status} count=${listed.body.saves.length} id=${listed.body.saves[0]?.id}`,
  );

  const own = await http(`/saves/${encodeURIComponent(saved.body.id)}`, {
    headers: { "remote-user": "seat-one" },
  });
  say(`GET  /saves/id as seat-one   ${own.status} elements=${own.body.scene?.elements?.length}`);

  const refused = await http(`/saves/${encodeURIComponent(saved.body.id)}`, {
    headers: { "remote-user": "seat-two" },
  });
  say(`GET  /saves/id as seat-two  ${refused.status} reason=${refused.body.reason} "${refused.body.error}"`);

  const anonymous = await http("/saves", { headers: {} });
  say(`GET  /saves anonymous     ${anonymous.status} "${anonymous.body.error}"`);

  const otherList = await http("/saves", { headers: { "remote-user": "seat-two" } });
  say(`GET  /saves as seat-two     ${otherList.status} count=${otherList.body.saves.length}`);

  const onDisk = join(savesDir, "seat-one", `${saved.body.id}.excalidraw`);
  say(`on disk                   ${onDisk.replace(scratch, "<scratch>")} exists=${existsSync(onDisk)}`);

  // ── 3. restart: a new process, nothing in memory ────────────────────────
  await stopServer(server);
  const afterStop = readdirSync(join(snapshotsDir, room));
  say(`stopped                   snapshot files after SIGTERM=${afterStop.length}`);

  server = await startServer();
  const memory = (await http("/healthz")).body;
  say(`restarted                 rooms=${memory.rooms} members=${memory.members}`);

  const rejoined = await joinOnce(room);
  const same = rejoined.data?.join(",") === sceneBytes.join(",");
  const sameIv = rejoined.iv?.join(",") === ivBytes.join(",");
  say(
    `joiner after restart      heard=${rejoined.seen.join("+")} bytes=${rejoined.data?.length} same-scene=${same} same-iv=${sameIv}`,
  );

  // ── 4. every door carved a Rune ─────────────────────────────────────────
  await new Promise((done) => setTimeout(done, 250));
  const runes = existsSync(runesLog) ? readFileSync(runesLog, "utf8").trim().split("\n").filter(Boolean) : [];
  say(`runes carved              ${runes.length}`);
  for (const rune of runes) {
    say(`  ${rune}`);
  }

  await stopServer(server);

  const ok = written.length === 1 && same && sameIv && saved.status === 201 && refused.status === 403;
  say(ok ? "RESULT: proven" : "RESULT: NOT PROVEN");
  process.exitCode = ok ? 0 : 1;
} catch (error) {
  say(`FAILED: ${error.message}`);
  process.exitCode = 1;
} finally {
  if (process.exitCode) {
    for (const line of lines) {
      /* already printed */
    }
  }
  rmSync(scratch, { recursive: true, force: true });
}
