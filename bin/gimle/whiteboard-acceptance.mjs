#!/usr/bin/env node
/**
 * whiteboard-acceptance.mjs — the four points the whiteboard must pass, run against the LIVE doors.
 *
 * The whiteboard is three things that must all answer (the app, the collab room server, the AI
 * bridge), and one way out (the share door). "The page loads" is none of them. This script is the
 * proof, and it prints one PASS or UNPROVED line per point, with the bytes and the status it saw:
 *
 *   1. a room's scene survives a reload — a client stores a scene, leaves, and a fresh client
 *      joins the same room and receives the same bytes;
 *   2. two clients in one room see each other — a broadcast from one arrives at the other, and the
 *      roster names both;
 *   3. the bridge answers a prompt — `generate` returns a reply to the panel's own route;
 *   4. a scene is shared out through the share door, and an audit line lands for it.
 *
 * Usage (against the doors as they run):
 *
 *   node bin/gimle/whiteboard-acceptance.mjs
 *   node bin/gimle/whiteboard-acceptance.mjs --room proof-1 --store 'the store-only half'
 *   node bin/gimle/whiteboard-acceptance.mjs --room proof-1 --expect 'the store-only half'
 *   node bin/gimle/whiteboard-acceptance.mjs --collab http://127.0.0.1:7312 --bridge http://127.0.0.1:7313 \
 *        --share http://127.0.0.1:8488 --tokens ~/gimle/desk/etc/mcp-tokens --audit ~/gimle/desk/data/access.jsonl
 *
 * The split `--store` / `--expect` halves are what prove a scene comes back from DISK: store, restart
 * the room server, expect. Nothing here is mocked; every point speaks to the running service.
 *
 * `socket.io-client` is a dev dependency of the room server, so a machine may not have it on the
 * default path. Pass `--socket-io <dir of the module>` or set SOCKET_IO_CLIENT when it is elsewhere.
 */

import { existsSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const argv = process.argv.slice(2);
const arg = (name, fallback = null) => {
  const index = argv.indexOf(`--${name}`);
  return index === -1 ? fallback : argv[index + 1];
};
const flag = (name) => argv.includes(`--${name}`);

const expand = (path) => (path && path.startsWith("~") ? join(homedir(), path.slice(1)) : path);

const collab = arg("collab", "http://127.0.0.1:7312");
const bridge = arg("bridge", "http://127.0.0.1:7313");
const share = arg("share", "http://127.0.0.1:8488");
const tokensPath = expand(arg("tokens", "~/gimle/desk/etc/mcp-tokens"));
const auditPath = expand(arg("audit", "~/gimle/desk/data/access.jsonl"));
const socketIoDir = arg("socket-io", process.env.SOCKET_IO_CLIENT ?? null);

const stamp = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);
const room = arg("room", `acc-${stamp}`);
const payloadText = arg("store", null) ?? arg("expect", null) ?? `scene-${room}`;

let failures = 0;
const pass = (point, detail) => console.log(`PASS     ${point} — ${detail}`);
const unproved = (point, why) => {
  failures += 1;
  console.log(`UNPROVED ${point} — ${why}`);
};

const loadSocketIo = async () => {
  if (socketIoDir) {
    const entry = resolve(expand(socketIoDir), "build/esm/index.js");
    return await import(pathToFileURL(entry).href);
  }
  try {
    return await import("socket.io-client");
  } catch {
    throw new Error(
      "socket.io-client is not resolvable here — pass --socket-io <dir containing socket.io-client>",
    );
  }
};

const bytesOf = (text) => new TextEncoder().encode(text);

const health = async (base, path = "/healthz") => {
  const response = await fetch(`${base}${path}`, { signal: AbortSignal.timeout(8000) });
  return { status: response.status, body: await response.text() };
};

/** Joins a room and resolves with what the server said, then closes. */
const joinRoom = (io, roomId, { send = null, waitMs = 6000 } = {}) =>
  new Promise((accept, reject) => {
    const socket = io(collab, { transports: ["websocket"], timeout: 8000 });
    const seen = { roster: [], broadcasts: [], firstInRoom: false, init: false, maxRoster: 0, id: null };
    const done = (error) => {
      clearTimeout(timer);
      const socketId = socket.id;
      socket.close();
      error ? reject(error) : accept({ seen, socketId });
    };
    const timer = setTimeout(() => done(null), waitMs);
    socket.on("connect", () => {
      seen.id = socket.id;
    });
    socket.on("init-room", () => {
      seen.init = true;
      socket.emit("join-room", roomId);
      if (send) {
        setTimeout(() => socket.emit("server-broadcast", roomId, send, new Uint8Array([0, 0, 0, 0])), 150);
      }
    });
    socket.on("first-in-room", () => {
      seen.firstInRoom = true;
    });
    socket.on("room-user-change", (members) => {
      seen.roster.push([...members]);
      seen.maxRoster = Math.max(seen.maxRoster, members.length);
    });
    socket.on("client-broadcast", (data, iv) => {
      seen.broadcasts.push({
        bytes: Buffer.from(data).toString("utf8"),
        iv: Buffer.from(iv ?? []).toString("hex"),
      });
    });
  });

const main = async () => {
  const ioModule = await loadSocketIo();
  const io = ioModule.io;

  // ── 1 · a room's scene survives a reload ────────────────────────────────────
  if (arg("store", null) !== null) {
    const { seen } = await joinRoom(io, room, { send: bytesOf(payloadText), waitMs: 2500 });
    console.log(`stored   room "${room}" with ${payloadText.length} bytes (roster ${JSON.stringify(seen.roster.at(-1) ?? [])})`);
    console.log("next: restart the room server, then run with --expect to prove it came back from disk");
    return;
  }

  if (arg("expect", null) !== null) {
    const { seen } = await joinRoom(io, room, { waitMs: 6000 });
    const got = seen.broadcasts.find((entry) => entry.bytes === payloadText);
    got
      ? pass("1 scene survives a reload", `room "${room}" handed back ${got.bytes.length} identical bytes (iv ${got.iv})`)
      : unproved("1 scene survives a reload", `room "${room}" handed back ${JSON.stringify(seen.broadcasts)}`);
    return report();
  }

  // store, leave, and come back as a stranger: that IS a reload
  await joinRoom(io, room, { send: bytesOf(payloadText), waitMs: 2500 });
  const afterReload = await joinRoom(io, room, { waitMs: 6000 });
  const back = afterReload.seen.broadcasts.find((entry) => entry.bytes === payloadText);
  back
    ? pass("1 scene survives a reload", `the room handed ${back.bytes.length} identical bytes back to a fresh client`)
    : unproved("1 scene survives a reload", `a fresh client got ${JSON.stringify(afterReload.seen.broadcasts)}`);

  // ── 2 · two clients in one room see each other ──────────────────────────────
  const watcher = joinRoom(io, room, { waitMs: 6000 });
  await new Promise((done) => setTimeout(done, 400));
  const talker = await joinRoom(io, room, { send: bytesOf(`hello-from-the-other-hand-${stamp}`), waitMs: 3000 });
  const watched = await watcher;
  const heard = watched.seen.broadcasts.find((entry) => entry.bytes.startsWith("hello-from-the-other-hand"));
  heard && watched.seen.maxRoster >= 2
    ? pass(
        "2 two clients see each other",
        `the room listed ${watched.seen.maxRoster} members at once · the second hand received ${heard.bytes.length} bytes (roster events ${JSON.stringify(watched.seen.roster)})`,
      )
    : unproved(
        "2 two clients see each other",
        `max roster ${watched.seen.maxRoster} · broadcasts ${JSON.stringify(watched.seen.broadcasts)} (talker ${talker.socketId ?? talker.seen.id})`,
      );

  // ── 3 · the bridge answers a prompt ─────────────────────────────────────────
  try {
    const response = await fetch(`${bridge}/v1/ai/text-to-diagram/chat-streaming`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        messages: [{ role: "user", content: "Draw a flowchart with two boxes: ein errand, one proof." }],
      }),
      signal: AbortSignal.timeout(120000),
    });
    const body = await response.text();
    const meaningful = body.split("\n").filter((line) => line.startsWith("data:") && line.trim() !== "data:").length;
    response.ok && meaningful > 0
      ? pass("3 the bridge answers a prompt", `http=${response.status} · ${meaningful} frames · ${body.slice(0, 120).replace(/\n/g, " ")}`)
      : unproved("3 the bridge answers a prompt", `http=${response.status} · ${body.slice(0, 300)}`);
  } catch (error) {
    unproved("3 the bridge answers a prompt", `${error.message}`);
  }

  // ── 4 · a scene is shared out through the door, and audited ─────────────────
  try {
    const before = existsSync(auditPath) ? readFileSync(auditPath, "utf8").split("\n").filter(Boolean).length : 0;
    const token = readFileSync(tokensPath, "utf8").split("\n").filter(Boolean).map((line) => line.split(/\s+/)).find(Boolean);
    const scene = `acceptance-${stamp}`;
    const response = await fetch(`${share}/share`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${token[0]}` },
      body: JSON.stringify({ scene, elements: [{ type: "text", id: "acceptance", text: payloadText }], appState: {} }),
      signal: AbortSignal.timeout(15000),
    });
    const body = await response.json().catch(() => ({}));
    const after = existsSync(auditPath) ? readFileSync(auditPath, "utf8").split("\n").filter(Boolean).length : 0;
    const written = body.path && existsSync(body.path);
    const audited = after > before;
    response.ok && written && audited
      ? pass(
          "4 a scene is shared out and audited",
          `http=${response.status} subject=${body.owner} audit lines ${before}→${after} at ${body.path} (${statSync(body.path).size} bytes)`,
        )
      : unproved(
          "4 a scene is shared out and audited",
          `http=${response.status} ${JSON.stringify(body)} written=${Boolean(written)} audit ${before}→${after}`,
        );
  } catch (error) {
    unproved("4 a scene is shared out and audited", `${error.message}`);
  }

  return report();
};

const report = () => {
  console.log(failures === 0 ? "ACCEPTANCE green — every point answered" : `ACCEPTANCE red — ${failures} point(s) unproved`);
  process.exit(failures === 0 ? 0 : 1);
};

main().catch((error) => {
  console.error(`FAILED — ${error.message}`);
  process.exit(2);
});
