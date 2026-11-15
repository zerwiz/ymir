#!/usr/bin/env node
/**
 * Collaboration server — a self-hosted room server for this fork.
 *
 *   node server/collab/index.mjs
 *
 * Speaks the protocol the client already speaks (the events in
 * `excalidraw-app/app_constants.ts`), so no client change is needed:
 *
 *   client → server   join-room · server-broadcast · server-volatile-broadcast · user-follow
 *   server → client   init-room · first-in-room · new-user · room-user-change
 *                     client-broadcast · user-follow-room-change
 *
 * It relays **opaque encrypted bytes**. The room key lives in the URL fragment
 * and never reaches the server, so the server cannot read a whiteboard.
 *
 * Binds localhost by default.
 */

import { createServer } from "node:http";

import { Server } from "socket.io";

import { watch } from "node:fs";

import {
  authorize,
  findMemberByHandle,
  isRoomProtected,
  loadRegistry,
  logMembership,
  readConfig as readAccessConfig,
} from "./access.mjs";
import {
  readBlob,
  readConfig as readFilesConfig,
  safePath,
  saveBlob,
} from "./files.mjs";
import {
  RoomStore,
  isPlausiblePayload,
  isPlausibleRoomId,
  readConfig,
} from "./rooms.mjs";
import { identityFrom, readConfig as readIdentityConfig } from "./identity.mjs";
import { carveRune, readConfig as readRunesConfig } from "./runes.mjs";
import { listSaves, readConfig as readSavesConfig, readSave, writeSave } from "./saves.mjs";
import {
  SnapshotWriter,
  latestSnapshot,
  listSnapshots,
  readConfig as readSnapshotsConfig,
} from "./snapshots.mjs";

/** A small root page, so a shared link to THIS hostname previews properly. */
const landingPage = ({
  title,
  description,
  points,
  host,
  appUrl,
  card,
}) => `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8" />
<title>${title}</title>
<meta name="description" content="${description}" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<meta name="theme-color" content="#171410" />
${
  appUrl
    ? `<link rel="canonical" href="https://${host}/" />
<meta property="og:type" content="website" />
<meta property="og:site_name" content="${title}" />
<meta property="og:url" content="https://${host}/" />
<meta property="og:title" content="${title}" />
<meta property="og:description" content="${description}" />
<meta property="og:image" content="${appUrl}/${card}" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="${title}" />
<meta name="twitter:description" content="${description}" />
<meta name="twitter:image" content="${appUrl}/${card}" />`
    : ""
}
<style>
  :root { color-scheme: dark }
  body { margin:0; min-height:100vh; display:grid; place-items:center;
         background:linear-gradient(135deg,#171410,#221d14); color:#fff;
         font:16px/1.6 system-ui, -apple-system, Segoe UI, Roboto, sans-serif }
  main { max-width:38rem; padding:2rem }
  h1 { margin:0 0 .25rem; font-size:1.6rem }
  p.sub { margin:0 0 1.5rem; color:#cbbfa3 }
  li { margin:.5rem 0; color:#f0e6cd }
  a { color:#f0e6cd }
  code { background:#2b241a; padding:.1rem .35rem; border-radius:.25rem }
</style>
</head><body><main>
<h1>${title}</h1>
<p class="sub">${description}</p>
<ul>${points.map((point) => `<li>${point}</li>`).join("")}</ul>
${
  appUrl
    ? `<p>The whiteboard itself is at <a href="${appUrl}">${appUrl}</a>.</p>`
    : ""
}
<p><code>${host}</code></p>
</main></body></html>`;

const config = readConfig();
const access = readAccessConfig();
const files = readFilesConfig();
const store = new RoomStore();
const snapshots = readSnapshotsConfig();
const saves = readSavesConfig();
const identity = readIdentityConfig();
const runes = readRunesConfig();

/**
 * The house's word for a snapshot store that is not configured: a clean skip with
 * its reason, never a silent empty room (RULES/25).
 */
const snapshotsNote = snapshots.dir
  ? null
  : "COLLAB_SNAPSHOT_DIR is unset — a room's scene is held in memory only and is lost when the last hand leaves";
const savesNote = saves.dir
  ? null
  : "the board shelf is unset (YMIR_HOME or COLLAB_SAVES_DIR) — /saves refuses rather than writing a board somewhere arbitrary";

/** Small JSON body reader: a board is bounded, so an unbounded upload is refused. */
const readJsonBody = (req, maxBytes) =>
  new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > maxBytes) {
        reject(new Error(`the body exceeds ${maxBytes} bytes`));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      const text = Buffer.concat(chunks).toString("utf8");
      try {
        resolve(JSON.parse(text));
      } catch {
        reject(new Error("the body is not JSON"));
      }
    });
    req.on("error", reject);
  });

export const createCollabServer = ({
  origins = config.allowedOrigins,
  accessConfig = access,
} = {}) => {
  const httpServer = createServer(async (req, res) => {
    // File blobs. Collaboration uploads them ALREADY ENCRYPTED with the room key,
    // so these are opaque bytes the server cannot read — the same property as the
    // scene relay. The id is unguessable (the client generates it), which is the
    // capability: the same model the hosted storage used.
    const url = new URL(req.url ?? "/", "http://localhost");

    // A preflight is answered first, or a cross-origin POST never happens.
    if (req.method === "OPTIONS") {
      res.writeHead(204, corsFor(req));
      res.end();
      return;
    }

    if (url.pathname.startsWith("/files/")) {
      const key = decodeURIComponent(url.pathname.replace(/^\/+/, ""));
      if (!safePath(files.dir, key)) {
        res.writeHead(400, { "content-type": "application/json" });
        res.end(JSON.stringify({ error: "invalid key" }));
        return;
      }

      if (req.method === "POST" || req.method === "PUT") {
        const chunks = [];
        let size = 0;
        let refused = false;
        for await (const chunk of req) {
          size += chunk.length;
          if (size > files.maxBytes) {
            refused = true;
            break;
          }
          chunks.push(chunk);
        }
        if (refused) {
          res.writeHead(413, { "content-type": "application/json" });
          res.end(JSON.stringify({ error: "blob too large" }));
          return;
        }
        const result = await saveBlob(files.dir, key, Buffer.concat(chunks), {
          maxBytes: files.maxBytes,
        });
        res.writeHead(result.ok ? 200 : 400, {
          "content-type": "application/json",
          ...corsFor(req),
        });
        res.end(JSON.stringify(result));
        return;
      }

      if (req.method === "GET") {
        const blob = await readBlob(files.dir, key);
        if (!blob) {
          res.writeHead(404, {
            "content-type": "application/json",
            ...corsFor(req),
          });
          res.end(JSON.stringify({ error: "no such blob" }));
          return;
        }
        res.writeHead(200, {
          "content-type": "application/octet-stream",
          "content-length": blob.length,
          "cache-control": "public, max-age=31536000, immutable",
          ...corsFor(req),
        });
        res.end(blob);
        return;
      }

      res.writeHead(405, {
        "content-type": "application/json",
        ...corsFor(req),
      });
      res.end(JSON.stringify({ error: "method not allowed" }));
      return;
    }

    if (
      req.method === "GET" &&
      (url.pathname === "/" || url.pathname === "/index.html")
    ) {
      const host = (req.headers.host ?? "").toString();
      const html = landingPage({
        title: "Whiteboard Rooms",
        description: "Collaborate, end to end encrypted.",
        points: [
          "The room key never leaves the browser — this server relays ciphertext and can read nothing.",
          "Members, invites, and rooms only a granted member may enter.",
          "Rooms are joined over the socket protocol; <code>/healthz</code> reports the roster.",
        ],
        host,
        appUrl: process.env.COLLAB_APP_URL || "",
        card: "og-collab.png",
      });
      res.writeHead(200, {
        "content-type": "text/html; charset=utf-8",
        ...corsFor(req),
      });
      res.end(html);
      return;
    }

    if (url.pathname === "/healthz") {
      const payload = JSON.stringify({
        ok: true,
        ...store.stats(),
        snapshots: { enabled: Boolean(snapshots.dir), ...snapshotWriter.stats() },
        saves: { enabled: Boolean(saves.dir) },
        identity: { header: identity.header, trustProxy: identity.trustProxy },
        runes: { enabled: Boolean(runes.door) },
        ...(snapshotsNote ? { snapshotsNote } : {}),
        ...(savesNote ? { savesNote } : {}),
      });
      res.writeHead(200, {
        "content-type": "application/json",
        "content-length": Buffer.byteLength(payload),
      });
      return res.end(payload);
    }

    // ── The save doors (feature-0036) ────────────────────────────────────────
    //
    // The owner is the identity the GATE asserted — the proxy's header, never a
    // body field. An anonymous request is refused before anything is read, so a
    // board cannot be stored without a person to own it.
    if (url.pathname === "/saves" || url.pathname.startsWith("/saves/")) {
      const who = identityFrom(req.headers, identity);
      const headers = { "content-type": "application/json", ...corsFor(req) };

      if (!who.ok) {
        const payload = JSON.stringify({ error: who.reason, reason: "anonymous" });
        res.writeHead(401, headers);
        return res.end(payload);
      }

      if (url.pathname === "/saves" && req.method === "POST") {
        let body;
        try {
          body = await readJsonBody(req, saves.maxBytes ?? 16 * 1024 * 1024);
        } catch (error) {
          const payload = JSON.stringify({ error: error.message });
          res.writeHead(400, headers);
          return res.end(payload);
        }
        const result = writeSave(saves.dir, {
          identity: who.identity,
          roomId: body?.room ?? url.searchParams.get("room"),
          scene: body?.scene,
        });
        if (!result.ok) {
          res.writeHead(result.status ?? 400, headers);
          return res.end(JSON.stringify({ error: result.error }));
        }
        carveRune(runes.door, {
          actor: who.identity,
          event: "board-save",
          message: `saved board ${result.id} · room ${result.room} · ${result.bytes} bytes`,
        });
        res.writeHead(201, headers);
        return res.end(
          JSON.stringify({
            id: result.id,
            room: result.room,
            stamp: result.stamp,
            bytes: result.bytes,
          }),
        );
      }

      if (url.pathname === "/saves" && req.method === "GET") {
        const saves_ = listSaves(saves.dir, who.identity);
        carveRune(runes.door, {
          actor: who.identity,
          event: "board-list",
          message: `listed ${saves_.length} of their own boards`,
        });
        res.writeHead(200, headers);
        return res.end(JSON.stringify({ saves: saves_ }));
      }

      if (url.pathname.startsWith("/saves/") && req.method === "GET") {
        const id = decodeURIComponent(url.pathname.replace(/^\/saves\//, ""));
        const result = readSave(saves.dir, { identity: who.identity, id });
        if (!result.ok) {
          carveRune(runes.door, {
            actor: who.identity,
            event: result.reason === "not-yours" ? "board-open-refused" : "board-open-failed",
            message: `asked for board ${id} · ${result.error}`,
          });
          res.writeHead(result.status ?? 400, headers);
          return res.end(JSON.stringify({ error: result.error, reason: result.reason }));
        }
        carveRune(runes.door, {
          actor: who.identity,
          event: "board-open",
          message: `opened board ${id}`,
        });
        res.writeHead(200, headers);
        return res.end(JSON.stringify({ id: result.id, scene: result.scene }));
      }

      res.writeHead(405, headers);
      return res.end(JSON.stringify({ error: "method not allowed" }));
    }

    // A room's snapshots, so the app can list them beside the board. Read-only:
    // a snapshot is a record and is never rewritten or removed through HTTP.
    const snapshotsMatch = url.pathname.match(/^\/rooms\/([A-Za-z0-9_-]{6,64})\/snapshots$/);
    if (snapshotsMatch && req.method === "GET") {
      const headers = { "content-type": "application/json", ...corsFor(req) };
      if (!snapshots.dir) {
        res.writeHead(503, headers);
        return res.end(JSON.stringify({ error: snapshotsNote }));
      }
      const list = listSnapshots(snapshots.dir, snapshotsMatch[1]).map((entry) => ({
        stamp: entry.stamp,
        bytes: entry.bytes,
        path: undefined,
      }));
      res.writeHead(200, headers);
      return res.end(JSON.stringify({ room: snapshotsMatch[1], snapshots: list }));
    }

    res.writeHead(404, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: "not found" }));
  });

  /**
   * The REST side answers the page, which lives on another origin — until now only
   * socket.io had CORS, so a plain fetch to /healthz failed and looked like the
   * server being down. This is the fix for that class of confusion.
   */
  const corsFor = (req) => {
    const origin = req.headers.origin;
    return origin && origins.includes(origin)
      ? {
          "access-control-allow-origin": origin,
          "access-control-allow-methods": "GET, POST, PUT, OPTIONS",
          "access-control-allow-headers": "content-type",
          vary: "origin",
        }
      : {};
  };

  /**
   * The snapshot writer. It holds only the newest scene per room until it is
   * written, so a busy minute is one file rather than sixty, and it writes on the
   * last hand leaving so a room closed this evening is openable tomorrow.
   */
  const snapshotWriter = new SnapshotWriter({ root: snapshots.dir, everyMs: snapshots.everyMs });
  snapshotWriter.start();

  const io = new Server(httpServer, {
    cors: { origin: origins, methods: ["GET", "POST"] },
    // The scene payload is encrypted bytes; a room is not a database, so a
    // generous but bounded frame is enough.
    maxHttpBufferSize: 16 * 1024 * 1024,
  });

  io.on("connection", (socket) => {
    // The client waits for this before sending join-room.
    socket.emit("init-room");

    /** rooms this socket is in — a socket should only be in one, but the
     *  protocol does not forbid more, so track them and clean up honestly. */
    const joined = new Set();

    socket.on("join-room", (roomId, credentials) => {
      if (!isPlausibleRoomId(roomId)) {
        return;
      }

      // AUTHORIZATION IS SERVER-SIDE. A room is public unless the registry marks
      // it protected; then a member token or a room-scoped invite is required.
      // The client cannot opt out — a refusal here ends the attempt.
      if (accessConfig.enforcement) {
        const registry = loadRegistry(accessConfig.registryPath);
        const decision = authorize(registry, {
          roomId,
          token: credentials?.token,
          invite: credentials?.invite,
        });
        if (!decision.ok) {
          logMembership(accessConfig.logPath, {
            event: "refused",
            roomId,
            socketId: socket.id,
            reason: decision.reason,
            // never the token, never an invite code's value
            hadToken: Boolean(credentials?.token),
            hadInvite: Boolean(credentials?.invite),
          });
          socket.emit("access-denied", { roomId, reason: decision.reason });
          return;
        }
        if (decision.via !== "public") {
          // Remember the member on the SOCKET: a revocation has to be able to
          // find a live session, and the socket is where a live session lives.
          if (decision.member?.handle) {
            socket.data.member = decision.member.handle;
          }
          logMembership(accessConfig.logPath, {
            event: "joined",
            roomId,
            socketId: socket.id,
            via: decision.via,
            member: decision.member?.handle ?? null,
          });
        }
      }

      joined.add(roomId);
      socket.join(roomId);

      let { isFirst, members, scene } = store.join(roomId, socket.id);

      // A room handed to us by a restart has no scene in memory, but its last
      // snapshot is on disk. Restoring it INTO THE STORE is what makes the joiner
      // be served from disk exactly as it would be served from memory — and the
      // read is a `getScene`, never a second `join`. A second join would make this
      // socket not-first, so the server would ask a peer for the scene and there
      // would be no peer: the file would sit there and nobody would receive it.
      if (!scene && snapshots.dir) {
        const fromDisk = latestSnapshot(snapshots.dir, roomId);
        if (fromDisk) {
          store.rememberScene(roomId, fromDisk.data, fromDisk.iv);
          scene = store.getScene(roomId);
        }
      }

      // Everyone needs the roster.
      io.to(roomId).emit("room-user-change", members);

      if (isFirst) {
        // The joiner owns initialization; the client fetches or seeds the scene.
        socket.emit("first-in-room");
        // If we hold the last encrypted scene, hand it over: the client has the
        // room key from the URL fragment, so it can read what we cannot.
        if (scene) {
          socket.emit("client-broadcast", scene.data, scene.iv);
        }
        return;
      }

      // Tell the others to send their scene to the newcomer.
      socket.to(roomId).emit("new-user", socket.id);
    });

    const relay = (volatile, roomId, data, iv) => {
      if (!isPlausibleRoomId(roomId) || !joined.has(roomId)) {
        return;
      }
      // Normalize whatever arrived into bytes without interpreting it.
      const payload =
        data instanceof ArrayBuffer
          ? new Uint8Array(data)
          : data instanceof Uint8Array
          ? data
          : null;
      if (!payload || !isPlausiblePayload(payload)) {
        return;
      }
      const normalizedIv =
        iv instanceof Uint8Array ? iv : new Uint8Array(iv ?? []);

      if (!volatile) {
        // Persist the last non-volatile payload so a reconnecting client gets
        // the scene back. Volatile payloads (cursors) are never stored.
        store.rememberScene(roomId, payload, normalizedIv);
        // ...and note it for the disk, which is what survives this process.
        snapshotWriter.note(roomId, payload, normalizedIv);
      }

      socket.to(roomId).emit("client-broadcast", payload, normalizedIv);
    };

    socket.on("server-broadcast", (roomId, data, iv) => {
      relay(false, roomId, data, iv);
    });

    socket.on("server-volatile-broadcast", (roomId, data, iv) => {
      relay(true, roomId, data, iv);
    });

    socket.on("user-follow", (roomId, followedBy) => {
      if (!isPlausibleRoomId(roomId) || !joined.has(roomId)) {
        return;
      }
      socket.to(roomId).emit("user-follow-room-change", followedBy);
    });

    const cleanup = () => {
      for (const roomId of joined) {
        const members = store.leave(roomId, socket.id);
        if (members) {
          io.to(roomId).emit("room-user-change", members);
          // The last hand leaving is a boundary, not an event: write the scene
          // down before the room goes quiet.
          if (members.length === 0) {
            snapshotWriter.flush(roomId);
          }
        }
      }
      joined.clear();
    };

    socket.on("disconnect", cleanup);
  });

  /**
   * Ends the live sessions of members who are no longer in the registry.
   *
   * Revoking a member used to take effect on their **next** join, which is a
   * surprising answer when the person is on the canvas now. The registry file IS
   * the trigger: when it changes, every socket that joined as a member is checked,
   * and one whose member has gone is disconnected from its protected room with the
   * rest told the new roster.
   *
   * Revoking an INVITE deliberately does not disconnect anyone: an invite is a
   * door, not a leash, and this only ever looks at members.
   */
  const revokeVanishedMembers = () => {
    let registry;
    try {
      registry = loadRegistry(accessConfig.registryPath);
    } catch {
      return 0;
    }
    let revoked = 0;
    for (const socket of io.sockets.sockets.values()) {
      const handle = socket.data?.member;
      if (!handle || findMemberByHandle(registry, handle)) {
        continue;
      }
      for (const roomId of socket.rooms) {
        if (roomId === socket.id || !isRoomProtected(registry, roomId)) {
          continue;
        }
        socket.leave(roomId);
        // The ROSTER comes from the store, not from socket.io's room — leaving
        // the socket.io room alone would leave the name on the list.
        store.leave(roomId, socket.id);
        socket.emit("access-revoked", {
          roomId,
          reason: "membership was revoked",
        });
        io.to(roomId).emit("room-user-change", store.memberIds(roomId));
        logMembership(accessConfig.logPath, {
          event: "revoked",
          roomId,
          socketId: socket.id,
          member: handle,
        });
        revoked += 1;
      }
      delete socket.data.member;
    }
    return revoked;
  };

  // Watch the registry so a revocation is immediate. `unref` matters: without it
  // the watcher holds the event loop open and a test suite never exits.
  let watcher = null;
  if (accessConfig.enforcement && accessConfig.registryPath) {
    try {
      watcher = watch(accessConfig.registryPath, { persistent: false }, () => {
        // The write may still be in flight when the event fires.
        setTimeout(revokeVanishedMembers, 60);
      });
      watcher.unref?.();
    } catch {
      watcher = null; // no file yet, or not watchable: revocation degrades to next-join
    }
  }

  return {
    io,
    httpServer,
    store,
    snapshotWriter,
    revokeVanishedMembers,
    stopWatching: () => {
      snapshotWriter.stop();
      watcher?.close();
    },
  };
};

// Only listen when run directly, so tests can start it on an ephemeral port.
if (import.meta.url === `file://${process.argv[1]}`) {
  const { httpServer, snapshotWriter } = createCollabServer();
  httpServer.listen(config.port, config.host, () => {
    console.log(
      `Collab server on ws://${config.host}:${config.port} (protocol-compatible; relays encrypted bytes only)`,
    );
    // What is on, and what is deliberately off. An operator reading the journal
    // should not have to guess whether a board survives the night.
    console.log(
      JSON.stringify({
        event: "seat",
        snapshots: snapshots.dir ? `on (${snapshots.dir}, every ${snapshots.everyMs}ms)` : snapshotsNote,
        saves: saves.dir ? `on (${saves.dir})` : savesNote,
        identity: `${identity.header}${identity.trustProxy ? " (trusted)" : " (proxy only)"}`,
        runes: runes.door || "off (no runes door)",
      }),
    );
  });

  const sweeper = setInterval(() => {
    const dropped = store.sweep();
    if (dropped > 0) {
      console.log(
        JSON.stringify({ event: "sweep", dropped, ...store.stats() }),
      );
    }
  }, 60_000);
  sweeper.unref?.();

  // A stop is a boundary too: write what was drawn before the process goes.
  const lower = (signal) => {
    const written = snapshotWriter.stop();
    if (written.length) {
      console.log(
        JSON.stringify({ event: "snapshots-on-stop", signal, written: written.length }),
      );
    }
    httpServer.close(() => process.exit(0));
    // A hung socket must not keep a restarted service down.
    setTimeout(() => process.exit(0), 3000).unref?.();
  };
  process.on("SIGTERM", () => lower("SIGTERM"));
  process.on("SIGINT", () => lower("SIGINT"));
}
