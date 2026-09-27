// card.ts — the heart's A2A agent card, built through the shared contract.
//
// The address is resolved AT RUNTIME from the hoard's fleet registry (the seat's
// own row: LAN first, then tailnet), never baked in. Env wins when a seat wants
// to publish a different door:
//
//   A2A_AGENT_NAME   the card's name            (default "heart-whynot")
//   A2A_CARD_URL     the full public url        (wins over the registry lookup)
//   YMIR_FLEET_REGISTRY / YMIR_HOME   where the registry lives
//   YMIR_HOST        the registry row to read   (default: this hostname)
//   PORT             the A2A door               (default 8301)
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import { buildAgentCard, type AgentCard } from "../../contracts/src/index.ts";

const DEFAULT_PORT = 8301;

function recordedHome(): string {
  try {
    const cfg = process.env.XDG_CONFIG_HOME ?? path.join(os.homedir(), ".config");
    const line = fs
      .readFileSync(path.join(cfg, "ymir", "home"), "utf8")
      .trim()
      .split("\n")[0]
      .trim();
    return line;
  } catch {
    return "";
  }
}

function registryPath(): string {
  if (process.env.YMIR_FLEET_REGISTRY) return process.env.YMIR_FLEET_REGISTRY;
  const home = process.env.YMIR_HOME ?? recordedHome();
  return home ? path.join(home, "hodd", "data", "fleet.json") : "";
}

/** This seat's own reachable address: the registry's LAN host, else tailnet. */
export function seatAddress(): string {
  const registry = registryPath();
  if (!registry) return "127.0.0.1";
  try {
    const doc = JSON.parse(fs.readFileSync(registry, "utf8")) as {
      hosts?: Record<string, { lan?: string; tailnet?: string }>;
    };
    const me = process.env.YMIR_HOST ?? os.hostname().split(".")[0];
    const row = (doc.hosts ?? {})[me] ?? {};
    return row.lan ?? row.tailnet ?? "127.0.0.1";
  } catch {
    return "127.0.0.1";
  }
}

/** The url the card advertises. */
export function cardUrl(port = Number(process.env.PORT ?? DEFAULT_PORT)): string {
  const explicit = process.env.A2A_CARD_URL?.trim();
  if (explicit) return explicit.endsWith("/") ? explicit : `${explicit}/`;
  const host = process.env.A2A_CARD_HOST?.trim() || seatAddress();
  return `http://${host}:${port}/`;
}

/** The heart's card, validated at build time against the shared contract. */
export function heartCard(url = cardUrl()): AgentCard {
  return buildAgentCard({
    name: process.env.A2A_AGENT_NAME?.trim() || "heart-whynot",
    description:
      "The record heart + the forge: gate, well, mill, served-MCP. The A2A node of the federation.",
    url,
    version: "1.0.0",
    // Preserve the served card's existing wire values: a contract change must
    // never silently alter what a peer already reads off /.well-known.
    protocols: ["a2a"],
    securitySchemes: [],
    skills: [{ id: "well-recall", name: "well-recall", description: "Recall from the well" }],
  });
}
