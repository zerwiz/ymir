// Rödd operational-input bridge.
//
// Rödd ("voice") is the structured message wire between the Brokk primary and
// Ymir's workers. This is the TypeScript half of the protocol; the shell CLI
// (bin/rodd-operational-input.sh) is the single owner of construction/parsing.
// Ported from the upstream agent-distro reference.
import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const operationalInputScript =
  process.env.RODD_OPERATIONAL_INPUT_SCRIPT ||
  resolve(dirname(fileURLToPath(import.meta.url)), "../../../bin/rodd-operational-input.sh");

export const RODD_CURRENT_OPERATIONAL_KINDS = [
  "session-start",
  "watcher",
  "turn-end-guard",
  "away-supervisor",
  "from-brokk",
  "launch-brief",
  "branch-outcome",
] as const;

export type RoddCurrentOperationalKind =
  (typeof RODD_CURRENT_OPERATIONAL_KINDS)[number];

function runOperationalInputCommand(
  command: "encode" | "classify" | "kind",
  content: string,
  kind?: RoddCurrentOperationalKind,
): string | undefined {
  const args = command === "encode" ? [command, kind ?? ""] : [command];
  const result = spawnSync(operationalInputScript, args, {
    encoding: "utf8",
    input: content,
    maxBuffer: 1024 * 1024,
  });
  if (result.status !== 0) return undefined;
  return command === "classify" ? result.stdout.replace(/\n$/, "") : result.stdout;
}

export function encodeRoddOperationalInput(
  kind: RoddCurrentOperationalKind,
  content: string,
): string {
  const encoded = runOperationalInputCommand("encode", content, kind);
  if (encoded === undefined) {
    throw new Error(`could not encode Rödd operational input kind ${kind}`);
  }
  return encoded;
}

export function classifyRoddOperationalText(content: string): string | undefined {
  return runOperationalInputCommand("classify", content);
}

export function classifyRoddCurrentOperationalText(
  content: string,
): string | undefined {
  return runOperationalInputCommand("kind", content);
}
