/**
 * stack — the council's roster: 2–5 slots, each a model with a role lens.
 *
 * A stack is deliberately a SMALL, STRICT YAML subset rather than a general YAML
 * document: a typo in a model id must fail loudly, not be silently ignored, and an
 * extension that cannot load is worse than one that refuses. Unknown keys are an
 * error for that reason.
 *
 * Shape (see config/logretta-stack.example.yaml):
 *
 *   name: council-default
 *   arbiter: architect
 *   rounds: 2
 *   timeout_seconds: 180
 *   max_total_chars: 60000
 *   slots:
 *     - name: architect
 *       model: llama-swap/qwen3.6-35b-a3b@iq3_s
 *       lens: architect
 *       rail: local
 */

export type Rail = "local" | "fleet" | "hosted";

export interface Slot {
  name: string;
  model: string;
  lens: string;
  rail: Rail;
}

export interface Stack {
  name: string;
  arbiter: string;
  rounds: number;
  timeoutSeconds: number;
  maxTotalChars: number;
  slots: Slot[];
}

const TOP_KEYS = new Set(["name", "arbiter", "rounds", "timeout_seconds", "max_total_chars", "slots"]);
const SLOT_KEYS = new Set(["name", "model", "lens", "rail"]);
const RAILS: Rail[] = ["local", "fleet", "hosted"];
const MIN_SLOTS = 2;
const MAX_SLOTS = 5;

export class StackError extends Error {}

function scalar(raw: string): string {
  let v = raw.trim();
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
    v = v.slice(1, -1);
  }
  return v;
}

/** Strip a trailing `# comment` that is not inside quotes. */
function stripComment(line: string): string {
  let quote: string | null = null;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quote) {
      if (c === quote) quote = null;
    } else if (c === '"' || c === "'") {
      quote = c;
    } else if (c === "#" && (i === 0 || /\s/.test(line[i - 1]))) {
      return line.slice(0, i);
    }
  }
  return line;
}

export function parseStack(text: string): Stack {
  const top: Record<string, string> = {};
  const slots: Slot[] = [];
  let current: Record<string, string> | null = null;
  let inSlots = false;

  text.split("\n").forEach((rawLine, idx) => {
    const line = stripComment(rawLine).replace(/\s+$/, "");
    if (!line.trim()) return;
    const at = `line ${idx + 1}`;

    if (/^\s*-\s+/.test(line)) {
      if (!inSlots) throw new StackError(`${at}: a slot list item before 'slots:'`);
      const body = line.replace(/^\s*-\s+/, "");
      const m = /^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$/.exec(body);
      if (!m) throw new StackError(`${at}: expected '- key: value' in a slot`);
      if (!SLOT_KEYS.has(m[1])) throw new StackError(`${at}: unknown slot key '${m[1]}' (known: ${[...SLOT_KEYS].join(", ")})`);
      current = { [m[1]]: scalar(m[2]) };
      slots.push(current as unknown as Slot);
      return;
    }

    const m = /^(\s*)([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$/.exec(line);
    if (!m) throw new StackError(`${at}: expected 'key: value'`);
    const [, indent, key, value] = m;

    if (indent.length === 0) {
      if (!TOP_KEYS.has(key)) throw new StackError(`${at}: unknown key '${key}' (known: ${[...TOP_KEYS].join(", ")})`);
      inSlots = key === "slots";
      if (inSlots) return;
      if (value.trim() === "") throw new StackError(`${at}: '${key}' needs a value`);
      top[key] = scalar(value);
      current = null;
      return;
    }

    if (!inSlots || !current) throw new StackError(`${at}: indented value outside a slot`);
    if (!SLOT_KEYS.has(key)) throw new StackError(`${at}: unknown slot key '${key}'`);
    current[key] = scalar(value);
  });

  if (slots.length < MIN_SLOTS) throw new StackError(`a council needs ${MIN_SLOTS}–${MAX_SLOTS} slots; this stack has ${slots.length}`);
  if (slots.length > MAX_SLOTS) throw new StackError(`a council takes at most ${MAX_SLOTS} slots; this stack has ${slots.length}`);

  const seen = new Set<string>();
  for (const s of slots) {
    for (const k of SLOT_KEYS) {
      if (!s[k as keyof Slot]) throw new StackError(`slot '${s.name ?? "?"}' is missing '${k}'`);
    }
    if (seen.has(s.name)) throw new StackError(`duplicate slot name '${s.name}'`);
    seen.add(s.name);
    if (!RAILS.includes(s.rail)) throw new StackError(`slot '${s.name}': rail must be ${RAILS.join("|")}, got '${s.rail}'`);
    if (!/^[A-Za-z0-9_.-]+\/[^\s]+$/.test(s.model)) {
      throw new StackError(`slot '${s.name}': model must be a fully-qualified 'provider/id', got '${s.model}'`);
    }
  }

  const arbiter = top.arbiter ?? slots[0].name;
  if (!seen.has(arbiter)) throw new StackError(`arbiter '${arbiter}' is not one of the slots`);

  const rounds = top.rounds === undefined ? 2 : Number(top.rounds);
  if (!Number.isInteger(rounds) || rounds < 1 || rounds > 3) throw new StackError(`rounds must be 1–3 (opinion, debate, verdict stages), got '${top.rounds}'`);

  const timeoutSeconds = top.timeout_seconds === undefined ? 180 : Number(top.timeout_seconds);
  if (!Number.isFinite(timeoutSeconds) || timeoutSeconds < 10 || timeoutSeconds > 1800) throw new StackError(`timeout_seconds must be 10–1800, got '${top.timeout_seconds}'`);

  const maxTotalChars = top.max_total_chars === undefined ? 60000 : Number(top.max_total_chars);
  if (!Number.isFinite(maxTotalChars) || maxTotalChars < 2000) throw new StackError(`max_total_chars must be at least 2000, got '${top.max_total_chars}'`);

  return {
    name: top.name ?? "council",
    arbiter,
    rounds,
    timeoutSeconds,
    maxTotalChars,
    slots: slots as unknown as Slot[],
  };
}

/** The honest queue: local voices cannot speak at once on a one-model rail. */
export function queueLine(stack: Stack): string {
  const local = stack.slots.filter((s) => s.rail === "local").map((s) => s.name);
  const parallel = stack.slots.filter((s) => s.rail !== "local").map((s) => s.name);
  const parts: string[] = [];
  if (local.length) parts.push(`${local.length} LOCAL (${local.join(", ")}) — one resident model, so these speak IN TURN`);
  if (parallel.length) parts.push(`${parallel.length} remote (${parallel.join(", ")}) — in parallel`);
  return parts.join(" · ") || "no slots";
}

export function stackToon(stack: Stack): string {
  const rows = stack.slots.map((s) => `  "${s.name}","${s.model}","${s.lens}","${s.rail}"`);
  return [
    `logretta-stack[1]{name,arbiter,rounds,timeout_s,max_chars}:`,
    `  "${stack.name}","${stack.arbiter}",${stack.rounds},${stack.timeoutSeconds},${stack.maxTotalChars}`,
    `slots[${stack.slots.length}]{name,model,lens,rail}:`,
    ...rows,
    `queue: ${queueLine(stack)}`,
  ].join("\n");
}
