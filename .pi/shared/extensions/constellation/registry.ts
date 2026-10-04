/**
 * constellation-registry.ts — discovery of a Ymir mesh, and the refusal that
 * guards it.
 *
 * The constellation is not a directory of phones: it is a REGISTRY REPO holding one
 * agent card per install. This module reads it, validates every card against the
 * shared contract (`constellation-contract.ts`), and reports. It is deliberately
 * READ-ONLY — it discovers and reports, and it never writes to a peer.
 *
 * Three laws live here, each one paid for:
 *
 *  1. **A card is metadata.** Its contents are read and printed; nothing is written
 *     anywhere but the registry cache, and a card that carries an obvious secret is
 *     REFUSED with the field named — a stranger's card is not assumed well-behaved.
 *  2. **Unknown is not empty.** No registry configured is a loud SKIP carrying the
 *     reason, never "0 peers found". An unconfigured mesh and an empty mesh look
 *     identical downstream, and that is how a silent fleet passes for a whole one.
 *  3. **No call without a grant.** The grant vocabulary is `skills[]` plus a
 *     short-lived, skill-scoped JWT, and phase 61.2 (Forgejo identity + the minting
 *     door) has not landed. So `constellationAsk` refuses, names the missing grant,
 *     and points at the skill the card declares. Refusing correctly IS the work; a
 *     fake transport would be a lie with a 200 on it.
 *
 * Configuration (Rule 07 — nothing here is a hardcoded path):
 *   CONSTELLATION_REGISTRY  a git URL or a local path of the registry repo
 *   CONSTELLATION_CACHE     optional local cache dir for a pulled copy
 * The cache NEVER lands in the code tree, and the home comes from the one resolver
 * (`ymir_home_root` in `bin/vault/hoard-lib.sh`), never from a literal `$HOME/...`.
 */
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync } from "node:fs";
import { isAbsolute, join, relative, resolve } from "node:path";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

import {
  A2A_PROTOCOL,
  AgentCardContractError,
  assertAgentCard,
  type AgentCard,
  type AgentInterface,
} from "./contract.ts";

/** The registry's schema file lives beside the cards and is not itself a card. */
export const REGISTRY_SCHEMA_FILE = "agent-card.schema.json";

/** Why there is no grant today. Named so the refusal can cite it exactly. */
export const MISSING_GRANT =
  "skills[] — a Forgejo identity plus a short-lived, skill-scoped JWT (phase 61.2, not yet landed)";

/** A card that survived the secret scan and the contract. */
export interface PeerCard {
  source: string;
  card: AgentCard;
  endpoint: string;
  protocol: string;
  streaming: boolean;
  skillIds: string[];
}

/** A card that did not. The failing field is named, never dropped silently. */
export interface PeerRejection {
  source: string;
  field: string;
  why: string;
}

/** Every card in the registry, sound or not. */
export interface RegistryScan {
  peers: PeerCard[];
  rejected: PeerRejection[];
}

/** Where the registry came from, and whether it was there at all. */
export type RegistryResolution =
  | { status: "ok"; dir: string; source: string; note: string }
  | { status: "skip"; reason: string };

/** The refusal a call must earn before it is attempted. */
export interface AskRefusal {
  refused: true;
  text: string;
}

// ── card inspection ──────────────────────────────────────────────────────────

/** A URL with any userinfo redacted — an endpoint is printed, never a credential. */
export function redactEndpoint(url: string): string {
  return String(url ?? "").replace(/(\b[a-z][a-z0-9+.-]*:\/\/)[^/\s:@]+:[^/\s@]+@/gi, "$1<redacted>@");
}

const SECRET_KEY = /(pass(wo?rd)?|secret|token|credential|private[_-]?key|api[_-]?key|bearer)/i;
const SECRET_VALUE = [
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
  /\b(?:sk|rk|ghp|gho|ghu|ghs|glpat|xox[baprs]|AKIA|ASIA)[-_A-Za-z0-9]{8,}/,
  /\bBearer\s+[A-Za-z0-9._~+/-]{8,}/i,
  /\b[a-z][a-z0-9+.-]*:\/\/[^/\s:@]+:[^/\s@]+@/i,
];

/**
 * Find the obvious secrets a card should never carry, naming the field. A bare
 * `security: [{ apiKey: [] }]` is a REFERENCE to a scheme, not a credential, so
 * only a non-empty string (or a string nested under the key) is a finding.
 */
export function scanCardSecrets(value: unknown, path = "<card>", hits: string[] = []): string[] {
  if (hits.length >= 5) return hits;
  if (Array.isArray(value)) {
    value.forEach((item, i) => scanCardSecrets(item, `${path}[${i}]`, hits));
    return hits;
  }
  if (typeof value === "object" && value !== null) {
    for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
      scanCardSecrets(child, `${path}.${key}`, hits);
    }
    return hits;
  }
  if (typeof value !== "string") return hits;
  const secretish = SECRET_VALUE.some((pattern) => pattern.test(value));
  const keyish = SECRET_KEY.test(path.split(".").pop() ?? "") && value.trim() !== "";
  if (secretish || keyish) hits.push(path);
  return hits;
}

function peerEndpoint(card: AgentCard): string {
  const iface = (card as unknown as { interface?: AgentInterface }).interface;
  if (iface && typeof iface.endpoint === "string" && iface.endpoint.trim()) return iface.endpoint.trim();
  return card.url;
}

function peerProtocol(card: AgentCard): string {
  if (Array.isArray(card.protocols) && card.protocols.length > 0) return String(card.protocols[0]);
  if (card.protocolVersion) return card.protocolVersion;
  return A2A_PROTOCOL;
}

/**
 * Read one registry file into a sound card, or into a rejection that NAMES the
 * field that failed. A card that left the contract is never dropped: the whole
 * point of discovery is to see the hole.
 */
export function readCardFile(path: string, source: string): PeerCard | PeerRejection {
  let raw: string;
  try {
    raw = readFileSync(path, "utf8");
  } catch (error) {
    return { source, field: "<file>", why: `could not be read: ${(error as Error).message}` };
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    return { source, field: "<file>", why: `is not valid JSON: ${(error as Error).message}` };
  }
  const secrets = scanCardSecrets(parsed);
  if (secrets.length > 0) {
    return {
      source,
      field: secrets[0],
      why: `carries what looks like a secret — refused; a card is metadata and holds no credential${
        secrets.length > 1 ? ` (also: ${secrets.slice(1).join(", ")})` : ""
      }`,
    };
  }
  try {
    assertAgentCard(parsed);
  } catch (error) {
    if (error instanceof AgentCardContractError) {
      return { source, field: error.path, why: String(error.message) };
    }
    return { source, field: "<card>", why: `failed the contract: ${(error as Error).message}` };
  }
  const card = parsed as AgentCard;
  return {
    source,
    card,
    endpoint: redactEndpoint(peerEndpoint(card)),
    protocol: peerProtocol(card),
    streaming: card.capabilities?.streaming === true,
    skillIds: card.skills.map((skill) => skill.id),
  };
}

/** Every card in a registry directory, sound and refused alike. */
export function scanRegistryDir(dir: string): RegistryScan {
  const peers: PeerCard[] = [];
  const rejected: PeerRejection[] = [];
  let entries: string[] = [];
  try {
    entries = readdirSync(dir).sort();
  } catch (error) {
    return { peers, rejected: [{ source: dir, field: "<registry>", why: `could not be read: ${(error as Error).message}` }] };
  }
  for (const entry of entries) {
    if (!entry.endsWith(".json")) continue;
    if (entry === REGISTRY_SCHEMA_FILE) continue;
    if (entry.startsWith(".")) continue;
    const outcome = readCardFile(join(dir, entry), entry);
    if ("card" in outcome) peers.push(outcome);
    else rejected.push(outcome);
  }
  peers.sort((a, b) => a.card.name.localeCompare(b.card.name));
  return { peers, rejected };
}

// ── where the registry comes from ────────────────────────────────────────────

/** The operator's home, through the ONE resolver. Never a literal `$HOME/...`. */
export function resolveYmirHome(root: string): string {
  const result = spawnSync(
    "bash",
    ["-c", '. "$1/bin/vault/hoard-lib.sh"; ymir_home_root home; printf %s "$home"', "_", root],
    { encoding: "utf8" },
  );
  const home = (result.stdout || "").trim();
  return result.status === 0 ? home : "";
}

function looksLocal(spec: string): boolean {
  if (spec.startsWith(".") || spec.startsWith("~") || isAbsolute(spec)) return true;
  if (/^[A-Za-z]:[\\/]/.test(spec)) return true;
  return existsSync(spec);
}

function isInside(child: string, parent: string): boolean {
  const rel = relative(resolve(parent), resolve(child));
  return rel !== "" && !rel.startsWith("..") && !isAbsolute(rel);
}

function git(args: string[], cwd?: string): { ok: boolean; detail: string } {
  const result = spawnSync("git", args, { cwd, encoding: "utf8" });
  if (result.status === 0) return { ok: true, detail: "" };
  const detail = `${result.stderr || ""}`.trim().split(/\r?\n/).slice(0, 4).join("; ");
  return { ok: false, detail: detail || `git exited ${result.status}` };
}

/**
 * Resolve the registry to a directory of cards.
 *
 * Order: an explicit local path, else a shallow `git clone --depth 1` into the
 * cache (never into the code tree), else a SKIP carrying the reason. Unknown is
 * never empty.
 */
export function resolveRegistry(env: NodeJS.ProcessEnv, root: string): RegistryResolution {
  const spec = (env.CONSTELLATION_REGISTRY || "").trim();
  if (!spec) {
    return {
      status: "skip",
      reason:
        "no registry configured — set CONSTELLATION_REGISTRY (a git URL or a local path). " +
        "An unconfigured registry is UNKNOWN, not empty: no peer list is reported.",
    };
  }
  if (looksLocal(spec)) {
    const dir = spec.startsWith("~") ? join(process.env.USERPROFILE || "", spec.slice(1)) : resolve(spec);
    if (!existsSync(dir) || !statSync(dir).isDirectory()) {
      return { status: "skip", reason: `registry path is not a directory: ${dir}` };
    }
    return { status: "ok", dir, source: `local path ${dir}`, note: "read directly, never copied" };
  }

  const home = resolveYmirHome(root);
  const cache = (env.CONSTELLATION_CACHE || "").trim() || (home ? join(home, "state", "constellation", "registry") : "");
  if (!cache) {
    return {
      status: "skip",
      reason:
        `registry ${spec} is a git URL and no cache dir is available: CONSTELLATION_CACHE is unset and ` +
        `ymir_home_root resolved no home (run bin/vault/hoard-lib.sh's ymir_home_root to check the record).`,
    };
  }
  if (isInside(cache, root)) {
    return {
      status: "skip",
      reason: `cache dir ${cache} is inside the code tree ${root} — a pulled registry is private state and never lands in the repo`,
    };
  }

  try {
    mkdirSync(dirname(cache), { recursive: true });
  } catch (error) {
    return { status: "skip", reason: `cache dir could not be created (${cache}): ${(error as Error).message}` };
  }

  if (existsSync(join(cache, ".git"))) {
    const fetched = git(["-C", cache, "fetch", "--depth", "1", "origin"]);
    if (!fetched.ok) {
      const scan = scanRegistryDir(cache);
      if (scan.peers.length > 0 || scan.rejected.length > 0) {
        return {
          status: "ok",
          dir: cache,
          source: `git ${spec}`,
          note: `STALE — refresh failed, serving the cache as it stands (${fetched.detail})`,
        };
      }
      return { status: "skip", reason: `git fetch failed for ${spec} (${fetched.detail})` };
    }
    const reset = git(["-C", cache, "reset", "--hard", "FETCH_HEAD"]);
    return {
      status: "ok",
      dir: cache,
      source: `git ${spec}`,
      note: reset.ok ? "shallow refresh of the cache" : `refresh incomplete, serving the cache (${reset.detail})`,
    };
  }

  const cloned = git(["clone", "--depth", "1", spec, cache]);
  if (!cloned.ok) return { status: "skip", reason: `git clone --depth 1 failed for ${spec} (${cloned.detail})` };
  return { status: "ok", dir: cache, source: `git ${spec}`, note: "shallow clone into the cache" };
}

// ── rendering ────────────────────────────────────────────────────────────────

const cell = (value: string): string => `"${String(value).replace(/"/g, "'")}"`;

export interface RenderedRegistry {
  text: string;
  peerCount: number;
  invalidCount: number;
}

/** The peer table: name, endpoint, protocol, streaming, skills. */
export function renderRegistry(
  resolution: RegistryResolution,
  scan: RegistryScan | null,
): RenderedRegistry {
  if (resolution.status === "skip") {
    return {
      text:
        `constellation-skip[1]{reason}:\n  ${cell(resolution.reason)}\n` +
        `constellation-peers[0]{peer,endpoint,protocol,streaming,skills}:\n` +
        `constellation[1]{note}:\n  ${cell("UNKNOWN is not EMPTY — no peer list is reported")}`,
      peerCount: 0,
      invalidCount: 0,
    };
  }
  const rows = scan?.peers ?? [];
  const rejected = scan?.rejected ?? [];
  const plural = (n: number, word: string): string => `${n} ${word}${n === 1 ? "" : "s"}`;
  const lines: string[] = [];
  lines.push(`constellation[3]{source,note,counts}:`);
  lines.push(
    `  ${cell(resolution.source)},${cell(resolution.note)},${cell(`${plural(rows.length, "peer")}, ${plural(rejected.length, "invalid card")}`)}`,
  );
  lines.push(`constellation-peers[5]{peer,endpoint,protocol,streaming,skills}:`);
  if (rows.length === 0) lines.push(`  ${cell("<none>")},,,,`);
  for (const peer of rows) {
    lines.push(
      `  ${cell(peer.card.name)},${cell(peer.endpoint)},${cell(peer.protocol)},${cell(String(peer.streaming))},${cell(peer.skillIds.join(", ") || "<no skills>")}`,
    );
  }
  if (rejected.length > 0) {
    lines.push(`constellation-invalid[3]{card,field,why}:`);
    for (const bad of rejected) {
      lines.push(`  ${cell(bad.source)},${cell(bad.field)},${cell(bad.why)}`);
    }
  }
  return { text: lines.join("\n"), peerCount: rows.length, invalidCount: rejected.length };
}

/** One peer's card, printed — never written anywhere. */
export function renderCard(peer: PeerCard): string {
  return JSON.stringify(peer.card, null, 2);
}

// ── the refusal ──────────────────────────────────────────────────────────────

/**
 * The honest answer to `constellation_ask`. It refuses, names the missing grant,
 * and points at the skill the card declares. It attempts NOTHING: a fake transport
 * that returned success would be a lie with a status code on it.
 */
export function constellationAsk(
  peerName: string,
  skill: string,
  peers: PeerCard[],
  rejected: PeerRejection[],
): AskRefusal {
  const known = peers.find((peer) => peer.card.name === peerName);
  if (!known) {
    const alsoRejected = rejected.find((bad) => bad.source === peerName || bad.source === `${peerName}.json`);
    if (alsoRejected) {
      return {
        refused: true,
        text:
          `constellation_ask REFUSED — ${cell(peerName)} has no usable card.\n` +
          `card field that failed: ${alsoRejected.field} — ${alsoRejected.why}\n` +
          `no call was attempted.`,
      };
    }
    const declared = peers.map((peer) => peer.card.name);
    return {
      refused: true,
      text:
        `constellation_ask REFUSED — no peer named ${cell(peerName)} in the registry.\n` +
        `declared peers: ${declared.length ? declared.join(", ") : "<none>"}\n` +
        `no call was attempted.`,
    };
  }
  const declared = known.skillIds;
  if (!declared.includes(skill)) {
    return {
      refused: true,
      text:
        `constellation_ask REFUSED — ${cell(known.card.name)} declares no skill ${cell(skill)}.\n` +
        `the card declares: ${declared.join(", ") || "<no skills>"}\n` +
        `no call was attempted.`,
    };
  }
  return {
    refused: true,
    text:
      `constellation_ask REFUSED — no grant.\n` +
      `peer: ${known.card.name} (${known.endpoint})\n` +
      `skill: ${skill}\n` +
      `missing grant: ${MISSING_GRANT}\n` +
      `the card declares the skill, so the call is ADDRESSED and not PERMITTED.\n` +
      `no request was sent to the peer: the extension is read-only and this seat holds no grant to call with.`,
  };
}

/** Locate one peer by name or by its registry file name. */
export function findPeer(
  name: string,
  peers: PeerCard[],
  rejected: PeerRejection[],
): PeerCard | PeerRejection | null {
  return (
    peers.find((peer) => peer.card.name === name || peer.source === name || peer.source === `${name}.json`) ??
    rejected.find((bad) => bad.source === name || bad.source === `${name}.json`) ??
    null
  );
}

/** The tree that owns `bin/`, found from this module's own location. */
export function repoRootFromHere(): string {
  const here = dirname(fileURLToPath(import.meta.url));
  const candidates = [resolve(here, "../../.."), resolve(here, "..", "..", "..")];
  return candidates.find((candidate) => existsSync(join(candidate, "bin", "hoard-lib.sh"))) ?? candidates[0];
}
