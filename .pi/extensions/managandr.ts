/**
 * managandr — the Allfather's read-calendar. ONE tool, one door.
 *
 * Why this file exists (audit §5, 2026-10-03): the calendar tool used to live in
 * `ymirhome`, because that door already knew how to reach the vault. **The calendar is not a
 * home concern** — it is Mánagandr, with its own reader (`tools/calendar/reader.mjs`), its
 * own cache, and its own route in Hlidskjalf (`/api/calendar`). It reached `ymirhome` by
 * accident of wiring, and a 17-tool door is the wrong home for a sixteenth concern.
 *
 * It was also BROKEN there: it passed the literal string
 * `"${YMIR_HOME:-$HOME/Documents/ymirhome}/bin/time/snotra/calendar-ask.sh"` to bash as an argv entry,
 * and bash does not expand a variable inside an argument it was handed. So the tool had
 * never once reached the calendar on any seat — and nothing had noticed, because a broken
 * tool and an absent tool look identical from the outside.
 *
 * THIN by construction: it calls the door, so a human and a cron row get the same answer.
 *   what  → bin/time/snotra/calendar-ask.sh               the next 7 days (or `at`)
 *   free  → bin/time/snotra/calendar-ask.sh free <minutes> when a meeting fits
 *   probe → bin/time/snotra/calendar-ask.sh probe         is the consent still good?
 */

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Install records the root; the extension reads it. Never a machine path in source (Rule 07).
function resolveRoot(): string {
  const fromEnv = process.env.YMIR_ROOT?.trim();
  if (fromEnv) return fromEnv;
  const pointer = join(homedir(), ".pi", "agent", "extensions", ".ymir-root");
  if (existsSync(pointer)) {
    for (const line of readFileSync(pointer, "utf8").split("\n")) {
      const root = line.trim();
      if (root && existsSync(join(root, "bin"))) return root;
    }
  }
  throw new Error(
    "YMIR_ROOT is not set and ~/.pi/agent/extensions/.ymir-root holds no usable root. " +
    "Run `bin/seat/valknut-load.sh --all --global` from your Ymir checkout.",
  );
}

function ask(args: string[]): string {
  return execFileSync("bash", [join(resolveRoot(), "bin", "calendar-ask.sh"), ...args], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  }).trim();
}


// Pi 1.0 tool contract. The model-facing text is `content`; THROWING is how a tool reports
// failure. Named `piOut`, not `out`, because several handlers declare a LOCAL `const out` —
// and a module helper with a one-word name gets shadowed by them (0.1.100: "out is not a
// function" in seven tools, all the same cause).
const piOut = (text: unknown): { content: { type: "text"; text: string }[]; details: undefined } => ({
  content: [{ type: "text", text: String(text) }],
  details: undefined,
});

export default function managandr(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ymir_calendar",
    label: "Calendar",
    description:
      "Read the Allfather's calendar through Mánagandr: what is coming (default the next 7 " +
      "days, or `at` for an ISO date), when a meeting of N minutes fits (`free`), or whether " +
      "the Google consent is still good (`probe`). Thin: it calls bin/time/snotra/calendar-ask.sh, so a " +
      "human and a cron row read the same calendar.",
    parameters: {
      type: "object",
      properties: {
        action: {
          type: "string",
          enum: ["what", "free", "probe"],
          description: "what is coming · when a meeting fits · is the consent still good",
        },
        at: { type: "string", description: "ISO date or datetime; only for `what`" },
        minutes: { type: "number", description: "length of the meeting; only for `free`" },
      },
      required: [],
    },
    execute: async (_toolCallId: string, args: any) => {
      const action = String(args?.action ?? "what");
      const argv = [action];
      if (action === "what" && args?.at) argv.push("at", String(args.at));
      if (action === "free" && args?.minutes) argv.push("free", String(args.minutes));
      try {
        const out = ask(argv);
        if (!out) {
          return piOut("the calendar answers nothing yet — state is probably `not granted`, or unknown. " +
              "It is never silently empty: ask `probe` to see which.");
        }
        return piOut(out);
      } catch (e: any) {
        const msg = String(e?.stderr || e?.message || e).trim().split("\n")[0];
        return piOut(`Mánagandr is not answering: ${msg}\n  check: bin/time/snotra/calendar-ask.sh probe`);
      }
    },
  });
}
