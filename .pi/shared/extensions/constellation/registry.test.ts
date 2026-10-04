// constellation-registry.test.ts — the mesh's four promises, proved.
//
//   1. a sound card parses, and a card missing `skills` is reported INVALID with
//      the field named;
//   2. `constellationAsk` REFUSES, naming the missing grant;
//   3. no registry configured ⇒ a loud SKIP, never an empty peer list;
//   4. a card carrying an obvious secret is refused with the field named.
//
// Run: node --test .pi/extensions/lib/constellation-registry.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { pathToFileURL } from "node:url";

import {
  constellationAsk,
  redactEndpoint,
  renderRegistry,
  resolveRegistry,
  scanCardSecrets,
  scanRegistryDir,
} from "./registry.ts";
import { repoRootFromHere } from "./registry.ts";

const root = repoRootFromHere();

function fixtureRegistry(): string {
  const dir = mkdtempSync(join(tmpdir(), "constellation-"));
  writeFileSync(
    join(dir, "heart.json"),
    JSON.stringify({
      name: "heart-zerwizserver",
      description: "the record heart",
      url: "http://peer.example:8301/",
      version: "1.0.0",
      capabilities: { streaming: true },
      skills: [{ id: "well-recall", name: "well-recall" }],
      defaultInputModes: ["text"],
      defaultOutputModes: ["text"],
      protocols: ["a2a/1.0"],
    }),
  );
  // The refusal case: a card that left the contract, by way of its skills.
  writeFileSync(
    join(dir, "broken.json"),
    JSON.stringify({
      name: "broken-node",
      description: "a card that left the contract",
      url: "http://broken.example:8301/",
      version: "1.0.0",
      capabilities: {},
      defaultInputModes: ["text"],
      defaultOutputModes: ["text"],
    }),
  );
  // The law: a card is metadata and holds no credential.
  writeFileSync(
    join(dir, "leaky.json"),
    JSON.stringify({
      name: "leaky-node",
      description: "a card carrying something that looks like a secret",
      url: "http://leaky.example:8301/",
      version: "1.0.0",
      capabilities: {},
      skills: [],
      defaultInputModes: ["text"],
      defaultOutputModes: ["text"],
      security: [{ apiKey: "sk-live-0123456789abcdef" }],
    }),
  );
  writeFileSync(join(dir, "agent-card.schema.json"), JSON.stringify({ $schema: "x" }));
  return dir;
}

test("a sound card parses; a card missing skills is invalid with the field named", () => {
  const dir = fixtureRegistry();
  const scan = scanRegistryDir(dir);

  assert.equal(scan.peers.length, 1);
  const heart = scan.peers[0];
  assert.equal(heart.card.name, "heart-zerwizserver");
  assert.equal(heart.endpoint, "http://peer.example:8301/");
  assert.equal(heart.protocol, "a2a/1.0");
  assert.equal(heart.streaming, true);
  assert.deepEqual(heart.skillIds, ["well-recall"]);

  // The schema file is not a card, and a bad card is never dropped.
  const broken = scan.rejected.find((bad) => bad.source === "broken.json");
  assert.ok(broken, "the card that left the contract must be reported, not dropped");
  assert.equal(broken!.field, "skills");
  assert.match(broken!.why, /skills/);

  // A card carrying a credential is refused, and the field is named.
  const leaky = scan.rejected.find((bad) => bad.source === "leaky.json");
  assert.ok(leaky, "a card carrying a secret must be refused");
  assert.match(leaky!.field, /security\[0\]\.apiKey/);

  const rendered = renderRegistry(
    { status: "ok", dir, source: `local path ${dir}`, note: "read directly" },
    scan,
  );
  assert.equal(rendered.peerCount, 1);
  assert.equal(rendered.invalidCount, 2);
  assert.match(rendered.text, /constellation-invalid\[3\]\{card,field,why\}/);
});

test("constellation_ask refuses and names the missing grant", () => {
  const dir = fixtureRegistry();
  const { peers, rejected } = scanRegistryDir(dir);

  const refusal = constellationAsk("heart-zerwizserver", "well-recall", peers, rejected);
  assert.equal(refusal.refused, true);
  assert.match(refusal.text, /REFUSED — no grant/);
  assert.match(refusal.text, /missing grant: skills\[\]/);
  assert.match(refusal.text, /phase 61\.2/);
  assert.match(refusal.text, /no request was sent to the peer/);

  // The card DOES declare the skill: the call is addressed, not permitted.
  assert.match(refusal.text, /well-recall/);

  // An undeclared skill is refused for its own, named reason.
  const undeclared = constellationAsk("heart-zerwizserver", "not-a-skill", peers, rejected);
  assert.match(undeclared.text, /declares no skill/);
  assert.match(undeclared.text, /the card declares: well-recall/);

  // An unknown peer is refused too — never invented.
  const unknown = constellationAsk("ghost", "well-recall", peers, rejected);
  assert.match(unknown.text, /no peer named/);
});

test("no registry configured is a loud SKIP, not an empty peer list", () => {
  const resolution = resolveRegistry({}, root);
  assert.equal(resolution.status, "skip");
  const reason = resolution.status === "skip" ? resolution.reason : "";
  assert.match(reason, /no registry configured/);
  assert.match(reason, /CONSTELLATION_REGISTRY/);

  const rendered = renderRegistry(resolution, null);
  assert.match(rendered.text, /constellation-skip\[1\]\{reason\}/);
  assert.match(rendered.text, /UNKNOWN is not EMPTY/);
  // A SKIP never prints the peer table as though it were the mesh.
  assert.equal(rendered.peerCount, 0);
  assert.match(rendered.text, /constellation-peers\[0\]/);
});

test("a registry path that is not a directory is a SKIP with the reason", () => {
  const resolution = resolveRegistry({ CONSTELLATION_REGISTRY: join(tmpdir(), "no-such-registry-xyz") }, root);
  assert.equal(resolution.status, "skip");
  assert.match(resolution.status === "skip" ? resolution.reason : "", /not a directory/);
});

test("a pulled registry is never cached inside the code tree", () => {
  const inside = join(root, "state", "constellation", "registry");
  const resolution = resolveRegistry(
    { CONSTELLATION_REGISTRY: "https://forgejo.example/ymir/registry.git", CONSTELLATION_CACHE: inside },
    root,
  );
  assert.equal(resolution.status, "skip");
  assert.match(resolution.status === "skip" ? resolution.reason : "", /inside the code tree/);
});

test("an explicit local path is read directly and never copied", () => {
  const dir = fixtureRegistry();
  const resolution = resolveRegistry({ CONSTELLATION_REGISTRY: dir }, root);
  assert.equal(resolution.status, "ok");
  assert.equal(resolution.status === "ok" ? resolution.dir : "", resolve(dir));
});

test("a shallow clone lands in the cache, outside the tree", () => {
  const cacheHome = mkdtempSync(join(tmpdir(), "constellation-cache-"));
  const cache = join(cacheHome, "registry");
  const origin = mkdtempSync(join(tmpdir(), "constellation-origin-"));
  writeFileSync(join(origin, "node.json"), "{}");

  const init = spawnSync("git", ["init", "-q", "-b", "main", origin], { encoding: "utf8" });
  if (init.status !== 0) return; // no git on this box: the clone path is covered elsewhere
  spawnSync("git", ["-C", origin, "add", "."], { encoding: "utf8" });
  spawnSync("git", ["-C", origin, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "cards"], {
    encoding: "utf8",
  });

  // A REMOTE, not a local path: the clone branch is only reached for a URL.
  const resolution = resolveRegistry(
    { CONSTELLATION_REGISTRY: pathToFileURL(origin).href, CONSTELLATION_CACHE: cache },
    root,
  );
  assert.equal(resolution.status, "ok");
  assert.equal(resolution.status === "ok" ? resolution.dir : "", cache);
  mkdirSync(cacheHome, { recursive: true });
});

test("an endpoint with credentials is redacted, never printed", () => {
  assert.equal(redactEndpoint("https://user:hunter2@peer.example:8301/"), "https://<redacted>@peer.example:8301/");
  assert.equal(redactEndpoint("http://peer.example:8301/"), "http://peer.example:8301/");
  assert.deepEqual(scanCardSecrets({ security: [{ apiKey: [] }] }), []);
});
