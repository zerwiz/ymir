/**
 * constellation — make this Ymir install a NODE of THE MESH.
 *
 * The mesh is a REGISTRY: a repo holding one agent card per install. This extension
 * reads it, validates every card against the shared contract
 * (`packages/contracts/src/agent-card.ts` — imported, never copied), and reports.
 * It refuses to CALL a peer, because there is no grant to call with: the grant
 * vocabulary is `skills[]` plus a short-lived skill-scoped JWT, and phase 61.2
 * (Forgejo identity + the minting door) has not landed. The refusal is the feature —
 * a tool that could call anyone would be a door with no key in it.
 *
 * Read-only, by construction: nothing here writes to a peer, opens a socket to one,
 * or invents a transport. A card is METADATA — read, validated, printed, never
 * written back, and a card carrying an obvious secret is refused with the field
 * named.
 *
 * Configuration (Rule 07, nothing hardcoded):
 *   CONSTELLATION_REGISTRY  git URL or local path of the registry repo
 *   CONSTELLATION_CACHE     optional local cache dir for a pulled copy
 * With neither set the tools SKIP LOUDLY — "no registry configured", never an empty
 * peer list, because UNKNOWN and EMPTY look the same downstream and only one of
 * them is the truth.
 *
 * Placement: this file belongs to the SHARED source, which `bin/seat/valknut-load.sh`
 * deploys to the one global pi extension home. `.pi/extensions/constellation.ts` is
 * the no-op shim that keeps a worktree-local session from registering it twice.
 */
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { resolveYmirRoot } from "../lib/ymir-home.ts";
import {
  constellationAsk,
  findPeer,
  redactEndpoint,
  renderCard,
  renderRegistry,
  resolveRegistry,
  resolveYmirHome,
  scanRegistryDir,
  type PeerCard,
  type PeerRejection,
  type RegistryResolution,
} from "./registry.ts";

const extensionFile = fileURLToPath(import.meta.url);
const root = resolveYmirRoot(dirname(extensionFile));
const extensionVersion = `sha256:${createHash("sha256").update(readFileSync(extensionFile)).digest("hex")}`;

/** Runtime state lives in the OPERATOR'S home (Rule 04), resolved the one way. */
function stateDir(): string {
  const override = process.env.BROKK_STATE_OVERRIDE;
  if (override) return override;
  const home = resolveYmirHome(root);
  return home ? join(home, "state") : "";
}

/** Proof, in the same shape Gná writes its own: the file says this extension loaded. */
function markLoaded(): void {
  const state = stateDir();
  if (!state) return;
  try {
    mkdirSync(state, { recursive: true });
    writeFileSync(join(state, ".pi-constellation-loaded"), `${extensionVersion}\n${process.pid}\n`);
  } catch {
    // a read-only home must not stop the extension from registering its tools
  }
}

interface Loaded {
  resolution: RegistryResolution;
  peers: PeerCard[];
  rejected: PeerRejection[];
}

function load(): Loaded {
  const resolution = resolveRegistry(process.env, root);
  if (resolution.status === "skip") return { resolution, peers: [], rejected: [] };
  const scan = scanRegistryDir(resolution.dir);
  return { resolution, peers: scan.peers, rejected: scan.rejected };
}

const registryIsVisible = () => existsSync(join(stateDir() || "/nonexistent", ".pi-constellation-loaded"));

export default function constellation(pi: any) {
  markLoaded();

  pi.registerTool({
    name: "constellation_list",
    label: "Constellation peers",
    description:
      "List the Ymir mesh: every peer found in the agent-card registry, with its endpoint, protocol, " +
      "streaming flag and skills. Cards that fail validation are reported as invalid with the field that " +
      "failed, never dropped. If no registry is configured this SKIPS loudly — it is never an empty list.",
    promptSnippet:
      "Discover the Ymir mesh from its agent-card registry; invalid cards are reported with the failing field.",
    parameters: { type: "object", properties: {} },
    async execute() {
      const { resolution } = load();
      if (resolution.status === "skip") {
        return {
          content: [{ type: "text", text: `constellation-skip[1]{reason}:\n  "${resolution.reason.replace(/"/g, "'")}"` }],
          isError: true,
        };
      }
      const scan = scanRegistryDir(resolution.dir);
      const rendered = renderRegistry(resolution, scan);
      return { content: [{ type: "text", text: rendered.text }], details: rendered };
    },
  });

  pi.registerTool({
    name: "constellation_ask",
    label: "Constellation ask",
    description:
      "Attempt to call a peer's skill over the mesh. It REFUSES unless a grant exists, and names the grant " +
      "that is missing: the grant vocabulary is skills[] plus a short-lived skill-scoped JWT, and phase 61.2 " +
      "has not landed, so no call is ever sent. Use it to check whether a peer declares a skill and to learn " +
      "what a grant would require.",
    promptSnippet:
      "Check a peer's declared skill; the call is refused without a grant and names the missing grant.",
    parameters: {
      type: "object",
      properties: {
        peer: { type: "string", description: "the peer's card name (as listed by constellation_list)" },
        skill: { type: "string", description: "the skill id to call, e.g. well-recall" },
      },
      required: ["peer", "skill"],
    },
    async execute(_id: string, params: { peer: string; skill: string }) {
      const peer = String(params?.peer ?? "").trim();
      const skill = String(params?.skill ?? "").trim();
      if (!peer || !skill) {
        return {
          content: [{ type: "text", text: "constellation_ask REFUSED — both peer and skill are required" }],
          isError: true,
        };
      }
      const { resolution, peers, rejected } = load();
      if (resolution.status === "skip") {
        return {
          content: [{ type: "text", text: `constellation-skip[1]{reason}:\n  "${resolution.reason.replace(/"/g, "'")}"` }],
          isError: true,
        };
      }
      const refusal = constellationAsk(peer, skill, peers, rejected);
      return {
        content: [{ type: "text", text: refusal.text }],
        details: { refused: true, peer: redactEndpoint(peer), skill },
        isError: true,
      };
    },
  });

  pi.registerTool({
    name: "constellation_card",
    label: "Constellation card",
    description:
      "Print one peer's agent card exactly as the registry holds it. Read-only: a card is metadata and is " +
      "never written anywhere. A card that fails the shared contract, or that carries something that looks " +
      "like a secret, is reported as invalid with the field that failed.",
    promptSnippet: "Print one peer's agent card from the registry.",
    parameters: {
      type: "object",
      properties: {
        peer: { type: "string", description: "the peer's card name, or its registry file name" },
      },
      required: ["peer"],
    },
    async execute(_id: string, params: { peer: string }) {
      const peer = String(params?.peer ?? "").trim();
      if (!peer) {
        return { content: [{ type: "text", text: "constellation_card REFUSED — peer is required" }], isError: true };
      }
      const { resolution, peers, rejected } = load();
      if (resolution.status === "skip") {
        return {
          content: [{ type: "text", text: `constellation-skip[1]{reason}:\n  "${resolution.reason.replace(/"/g, "'")}"` }],
          isError: true,
        };
      }
      const found = findPeer(peer, peers, rejected);
      if (!found) {
        const declared = peers.map((entry) => entry.card.name).join(", ") || "<none>";
        return {
          content: [{ type: "text", text: `constellation_card REFUSED — no peer named "${peer}".\ndeclared peers: ${declared}` }],
          isError: true,
        };
      }
      if ("card" in found) {
        return {
          content: [{ type: "text", text: renderCard(found) }],
          details: { peer: found.card.name, endpoint: found.endpoint },
        };
      }
      return {
        content: [
          {
            type: "text",
            text: `constellation-invalid[3]{card,field,why}:\n  "${found.source}","${found.field}","${found.why.replace(/"/g, "'")}"`,
          },
        ],
        isError: true,
      };
    },
  });

  // Say once, at session start, what this seat can and cannot do — the honest
  // shape of the mesh is part of its bearings, not a surprise at the first call.
  pi.on?.("session_start", async () => {
    const resolution = resolveRegistry(process.env, root);
    if (resolution.status === "skip") {
      console.error(`[constellation] SKIP — ${resolution.reason}`);
      return;
    }
    const scan = scanRegistryDir(resolution.dir);
    console.error(
      `[constellation] ${scan.peers.length} peers from ${resolution.source} (${resolution.note}); ` +
        `${scan.rejected.length} invalid; calls refused — no grant (phase 61.2).`,
    );
  });

  return { loaded: registryIsVisible() };
}
