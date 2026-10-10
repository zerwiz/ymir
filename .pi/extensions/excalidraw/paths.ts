/**
 * Where the Excalidraw fork lives, and where its services listen.
 *
 * Rule 07: a path resolves from env with ONE documented default — never a
 * hardcoded absolute path buried in the logic.
 */

import { homedir } from "node:os";
import { join } from "node:path";

/** The fork's checkout. Override with `EXCALIDRAW_ROOT`. */
export const excalidrawRoot = (): string =>
  process.env.EXCALIDRAW_ROOT || join(homedir(), "CodeP", "excalidraw");

export type ServiceName = "board" | "bridge" | "collab";

export type Service = {
  name: ServiceName;
  /**
   * The door to prefer when raising it. A service that has a `start.sh` gets it,
   * because that script sources the service's own `.env` — which is how each
   * install carries its own model, port and origins without anything hardcoded.
   */
  startScript?: string;
  /** what it is for, in one line — the agent reads this */
  purpose: string;
  script: string;
  port: number;
  /** the ticket that raised it */
  ticket: string;
};

export const SERVICES: Record<ServiceName, Service> = {
  board: {
    name: "board",
    purpose:
      "Read-only HTTP view of tickets/ — open · in-progress · review · done.",
    script: "server/tickets/index.mjs",
    port: Number(process.env.TICKETS_PORT) || 4174,
    ticket: "feature-0006",
  },
  bridge: {
    name: "bridge",
    purpose:
      "Text-to-diagram backend: forwards the AI panel's prompt to an OpenAI-compatible model.",
    script: "server/ttd-bridge/index.mjs",
    startScript: "server/ttd-bridge/start.sh",
    port: Number(process.env.TTD_BRIDGE_PORT) || 4173,
    ticket: "feature-0005",
  },
  collab: {
    name: "collab",
    purpose:
      "Room server. Relays encrypted bytes only — it cannot read a room (the key is in the URL fragment).",
    script: "server/collab/index.mjs",
    port: Number(process.env.COLLAB_PORT) || 3002,
    ticket: "feature-0003",
  },
};

/**
 * This install's model, from the environment. Documented defaults only: a base
 * URL of "" means "not configured", never a hosted host.
 */
export const modelDefaults = () => ({
  baseURL: process.env.TTD_MODEL_BASE_URL ?? process.env.EXCALIDRAW_MODEL_BASE_URL ?? "",
  model: process.env.TTD_MODEL ?? process.env.EXCALIDRAW_MODEL ?? "",
});

export const serviceList = (): Service[] =>
  Object.values(SERVICES).sort((a, b) => a.port - b.port);

export const isServiceName = (value: unknown): value is ServiceName =>
  value === "board" || value === "bridge" || value === "collab";
