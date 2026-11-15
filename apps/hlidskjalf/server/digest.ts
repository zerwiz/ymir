/**
 * Sága's digest, read as a PERSON reads it (plan 275 item 25, RULES/52).
 *
 * `bin/time/saga-session-start.sh` writes a machine's context: TOON tables, 163
 * liveness rows of which ~155 are errands finished days ago, the raw marker
 * lines. Printed on a page it is unreadable, so the Runtime gate showed a wall of
 * text to the one person who must be able to answer "is the house whole?" in a
 * glance.
 *
 * This module reads that same text and hands back the facts a person needs:
 * who holds the helm, what needs him, the errands that are ALIVE, and a count of
 * the ones that are finished. The raw text is kept whole, behind a fold.
 *
 * Parsing is deliberately tolerant: the digest is prose written by a bash script
 * that changes (plan 275 item 28 rewrites its head), so every field is optional
 * and an unrecognised shape degrades to `parsed: false` with the raw text intact —
 * never to a crash, and never to an invented number.
 */

export interface DigestErrand {
  id: string;
  state: string;
  pane: string;
  detail: string;
}

export interface DigestTodo {
  area: string;
  text: string;
  id: string;
  due?: string;
  high?: boolean;
}

export interface DigestHelm {
  seat: string;
  machine: string;
  role: string;
  pin: string;
  behind: string;
  pid: string;
  heartbeat: string;
  /** true when this session holds the lock, false when it says it is read-only. */
  holder: boolean;
}

export interface DigestView {
  helm: DigestHelm | null;
  next: string;
  decisions: number;
  wakes: number;
  errands: DigestErrand[];
  unreadable: DigestErrand[];
  finished: number;
  finishedIds: string[];
  todos: DigestTodo[];
  todosOpen: number;
  sections: string[];
  parsed: boolean;
}

/** Split one TOON row (`  "a","b",0,"c with, a comma"`) into its fields. */
function rowFields(line: string): string[] {
  const out: string[] = [];
  let cur = '';
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quoted) {
      if (c === '\\' && i + 1 < line.length) {
        cur += line[++i];
        continue;
      }
      if (c === '"') {
        quoted = false;
        continue;
      }
      cur += c;
      continue;
    }
    if (c === '"') {
      quoted = true;
      continue;
    }
    if (c === ',') {
      out.push(cur);
      cur = '';
      continue;
    }
    cur += c;
  }
  out.push(cur);
  return out.map((s) => s.trim());
}

const TABLE_HEADER = /^\s*([A-Za-z][\w-]*)\[(\d+)\]\{([^}]*)\}:\s*$/;

/** Every `name[N]{cols}:` block in the text, as [name, columns, rows]. */
function toonTables(text: string): Array<{ name: string; cols: string[]; rows: string[][] }> {
  const tables: Array<{ name: string; cols: string[]; rows: string[][] }> = [];
  let cur: { name: string; cols: string[]; rows: string[][] } | null = null;
  for (const line of text.split('\n')) {
    const head = TABLE_HEADER.exec(line);
    if (head) {
      if (cur) tables.push(cur);
      cur = { name: head[1], cols: head[3].split(',').map((c) => c.trim()), rows: [] };
      continue;
    }
    if (!cur) continue;
    const t = line.trim();
    if (!t) {
      // a blank line ends a table only when the next non-blank line is prose;
      // TOON never separates its own rows, so the table ends here
      cur = null;
      continue;
    }
    if (t.startsWith('"')) {
      cur.rows.push(rowFields(t));
      continue;
    }
    // any other line closes the block (a new section, a sentence, a brace)
    cur = null;
  }
  if (cur) tables.push(cur);
  return tables;
}

/** The `== NAME ==` sections, in order — so the page can show what the digest carries. */
function sections(text: string): string[] {
  return text
    .split('\n')
    .map((l) => /^==\s*(.+?)\s*==\s*$/.exec(l))
    .filter((m): m is RegExpExecArray => !!m)
    .map((m) => m[1]);
}

function block(text: string, name: string): string {
  const out: string[] = [];
  let inside = false;
  for (const line of text.split('\n')) {
    const m = /^==\s*(.+?)\s*==\s*$/.exec(line);
    if (m) {
      inside = m[1].toLowerCase() === name.toLowerCase();
      continue;
    }
    if (inside) out.push(line);
  }
  return out.join('\n');
}

/** `helm: <seat> · <…> · <machine> · <role> · pin <sha> (<n> behind) · … · pid <n> · heartbeat <x>` */
function readHelm(text: string): DigestHelm | null {
  const line = text.split('\n').find((l) => /^\s*helm:\s*\S/.test(l));
  if (!line) return null;
  const body = line.replace(/^\s*helm:\s*/, '');
  const parts = body.split('·').map((p) => p.trim()).filter(Boolean);
  const pin = /pin\s+([0-9a-f]{6,40})\s*\((\d+)\s*behind\)/i.exec(body);
  const pid = /\bpid\s+(\d+)/i.exec(body);
  const hb = /heartbeat\s+(\S+)/i.exec(body);
  // machine and role sit together (`host-a · dev`); the seat is first. Prose
  // middle fields are free text, so they are reported, not interpreted.
  const roleAt = parts.findIndex((p) => /^(heart|forge|dev|hand)$/i.test(p));
  const machine = roleAt > 0 ? parts[roleAt - 1] : '';
  return {
    seat: parts[0] ?? '',
    machine,
    role: roleAt >= 0 ? parts[roleAt] : '',
    pin: pin?.[1] ?? '',
    behind: pin?.[2] ?? '',
    pid: pid?.[1] ?? '',
    heartbeat: hb?.[1] ?? '',
    holder: !/READ-ONLY/.test(text) && /session lock held/i.test(text),
  };
}

export function readDigest(raw: string): DigestView {
  const tables = toonTables(raw);
  const liveness = tables.find((t) => t.name === 'liveness');
  const errands: DigestErrand[] = [];
  const unreadable: DigestErrand[] = [];
  const finishedIds: string[] = [];
  for (const r of liveness?.rows ?? []) {
    const [id = '', verdict = '', pane = '', detail = ''] = r;
    const row = { id, state: verdict, pane, detail };
    if (/^ALIVE$/i.test(verdict)) errands.push(row);
    else if (/^SKIP$/i.test(verdict)) finishedIds.push(id);
    else unreadable.push(row);
  }

  const decisions = Number((/^open decisions:\s*(\d+)/m.exec(raw) ?? [])[1] ?? NaN);
  const wakes = Number((/^wake queue:\s*(\d+)\s+pending/m.exec(raw) ?? [])[1] ?? NaN);

  // THE ALLFATHER'S TODOS — `- [area] text  (id)` with optional `· due …`/`· high`
  const todos: DigestTodo[] = [];
  let todosOpen = NaN;
  const todoBlock = block(raw, "THE ALLFATHER'S TODOS") || raw;
  const openLine = /^open:\s*(\d+)/m.exec(todoBlock);
  if (openLine) todosOpen = Number(openLine[1]);
  for (const line of todoBlock.split('\n')) {
    const m = /^\s*-\s*\[([^\]]+)\]\s*(.+?)\s*\((t[0-9a-z]+)\)\s*$/i.exec(line);
    if (!m) continue;
    const body = m[2];
    const due = /·\s*due\s+(\d{4}-\d{2}-\d{2}(?:[ T][\d:]+)?)/i.exec(body)?.[1];
    todos.push({
      area: m[1],
      text: body
        .replace(/·\s*due\s+[^·]+/i, '')
        .replace(/·?\s*\b(?:high|low)\b/i, '')
        .replace(/\s{2,}/g, ' ')
        .replace(/\s+$/, '')
        .trim(),
      id: m[3],
      due,
      high: /·\s*high\b/i.test(body),
    });
  }

  const nextBlock = block(raw, 'NEXT STEP').trim();
  const next = nextBlock.split('\n').filter((l) => l.trim()).pop()?.trim() ?? '';

  const helm = readHelm(block(raw, 'LOCK') || raw);
  const parsed = !!(liveness || helm || todoBlock !== raw);

  return {
    helm,
    next,
    decisions: Number.isFinite(decisions) ? decisions : 0,
    wakes: Number.isFinite(wakes) ? wakes : 0,
    errands,
    unreadable,
    finished: finishedIds.length,
    finishedIds,
    todos,
    todosOpen: Number.isFinite(todosOpen) ? todosOpen : todos.length,
    sections: sections(raw),
    parsed,
  };
}
