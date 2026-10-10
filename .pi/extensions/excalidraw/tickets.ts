/**
 * The tickets, read from the FILES.
 *
 * The board server (feature-0006) is a convenience for the browser; an agent
 * does not need it. The files are the source of truth, so this reads them
 * directly and works even when nothing is running.
 */

import { readFile, readdir, stat } from "node:fs/promises";
import { join } from "node:path";

import { excalidrawRoot } from "./paths.ts";

export const COLUMNS = ["open", "in-progress", "review", "done"] as const;
export type Column = (typeof COLUMNS)[number];

export const isColumn = (value: unknown): value is Column =>
  COLUMNS.includes(value as Column);

const NAME_RE = /^(bug|feature|chore|spike)-(\d{4})-([a-z]{2,4})-(.+)\.md$/;

export type Ticket = {
  column: Column;
  filename: string;
  title: string;
  type: string | null;
  risk: string | null;
  owner: string | null;
  opened: string | null;
  /** what the naming guard would also complain about */
  problems: string[];
};

const parseHeader = (markdown: string) => {
  const line = markdown.split("\n").find((l) => l.startsWith("**Type**"));
  if (!line) {
    return {} as Record<string, string | undefined>;
  }
  const field = (name: string) => {
    const match = new RegExp(`\\*\\*${name}\\*\\*\\s*([^·|\\n]+)`).exec(line);
    return match ? match[1].trim() : undefined;
  };
  return {
    type: field("Type"),
    risk: field("Risk"),
    opened: field("Opened"),
    owner: field("Owner"),
  };
};

const parseTitle = (markdown: string, fallback: string) => {
  const line = markdown.split("\n").find((l) => l.startsWith("# "));
  return line ? line.slice(2).trim() : fallback;
};

/** Reads the DEVIDS table so an owner mismatch is caught against the repo's own list. */
export const readDevIds = async (root = excalidrawRoot()): Promise<Record<string, string>> => {
  try {
    const contents = await readFile(join(root, "tickets", "DEVIDS"), "utf8");
    return contents
      .split("\n")
      .filter((line) => !line.trim().startsWith("#") && line.trim() !== "")
      .reduce<Record<string, string>>((acc, line) => {
        const [id, handle] = line.trim().split(/\s+/);
        if (id && handle) {
          acc[id] = handle.replace(/^@/, "");
        }
        return acc;
      }, {});
  } catch {
    return {};
  }
};

export const listTickets = async (
  root = excalidrawRoot(),
  filter?: { column?: Column; query?: string },
): Promise<Ticket[]> => {
  const devIds = await readDevIds(root);
  const tickets: Ticket[] = [];

  for (const column of COLUMNS) {
    if (filter?.column && filter.column !== column) {
      continue;
    }
    let files: string[];
    try {
      files = await readdir(join(root, "tickets", column));
    } catch {
      continue; // a missing column is empty, not an error
    }
    for (const filename of files.sort()) {
      if (!filename.endsWith(".md")) {
        continue;
      }
      const full = join(root, "tickets", column, filename);
      const stats = await stat(full).catch(() => null);
      if (!stats?.isFile()) {
        continue;
      }
      const markdown = await readFile(full, "utf8").catch(() => "");
      const header = parseHeader(markdown);
      const parsed = NAME_RE.exec(filename);
      const problems: string[] = [];

      if (!parsed) {
        problems.push("filename does not match <type>-<NNNN>-<devid>-<slug>.md");
      }
      if (!header.owner) {
        problems.push("no Owner in the header");
      }
      if (parsed && header.owner) {
        const expected = devIds[parsed[3]];
        const owner = header.owner.replace(/^@/, "");
        if (expected && owner !== expected) {
          problems.push(`filename id '${parsed[3]}' but owner @${owner}`);
        }
      }

      const ticket: Ticket = {
        column,
        filename,
        title: parseTitle(markdown, parsed?.[4] ?? filename),
        type: header.type ?? parsed?.[1] ?? null,
        risk: header.risk ?? null,
        owner: header.owner ?? null,
        opened: header.opened ?? null,
        problems,
      };

      if (filter?.query) {
        const needle = filter.query.toLowerCase();
        const haystack = `${ticket.title} ${ticket.filename} ${markdown}`.toLowerCase();
        if (!haystack.includes(needle)) {
          continue;
        }
      }

      tickets.push(ticket);
    }
  }

  return tickets;
};

export type TicketBody = { column: Column; filename: string; markdown: string };

export const readTicket = async (
  column: string,
  filename: string,
  root = excalidrawRoot(),
): Promise<TicketBody | { error: string }> => {
  // Belt and braces: the name is checked before it is joined, so a caller
  // cannot walk out of tickets/ with `../`.
  if (!isColumn(column)) {
    return { error: `'${column}' is not a ticket column` };
  }
  if (!/^[A-Za-z0-9._-]+\.md$/.test(filename)) {
    return { error: `'${filename}' is not a ticket filename` };
  }
  try {
    const markdown = await readFile(
      join(root, "tickets", column, filename),
      "utf8",
    );
    return { column, filename, markdown };
  } catch {
    return { error: `no such ticket: ${column}/${filename}` };
  }
};

/** The five contract sections, pulled out so an agent gets the shape, not the prose. */
export const contractSections = (markdown: string): Record<string, string> => {
  const sections: Record<string, string> = {};
  const wanted = [
    "Problem",
    "Impact",
    "Architecture intent",
    "Requirements",
    "Constraints",
    "Non-goals",
    "Test cases",
    "Operations",
    "Resolution",
  ];
  const lines = markdown.split("\n");
  for (let index = 0; index < lines.length; index += 1) {
    const match = /^##\s+(.+?)\s*$/.exec(lines[index]);
    if (!match || !wanted.includes(match[1])) {
      continue;
    }
    const body: string[] = [];
    for (let scan = index + 1; scan < lines.length; scan += 1) {
      if (/^##\s/.test(lines[scan])) {
        break;
      }
      body.push(lines[scan]);
    }
    sections[match[1]] = body.join("\n").trim();
  }
  return sections;
};
