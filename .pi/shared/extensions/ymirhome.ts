
// The vault, resolved by the house's own resolver — never `$HOME/Documents/ymirhome`,
// which is this seat's layout and not a rule (Rule 04; 0.1.53 lost a push to that guess,
// and the ward now scans .pi/ so a guess here fails the build).
function resolveHome(): string {
  const fromEnv = process.env.YMIR_HOME?.trim();
  if (fromEnv) return fromEnv;
  const v = execFileSync("bash", [join(resolveRoot(), "bin", "hodd.sh"), "path"], {
    encoding: "utf8", stdio: ["ignore", "pipe", "ignore"],
  }).trim();
  if (!v) throw new Error("the vault path is empty — run `bin/hodd.sh path` and read what it says");
  return v;
}

/**
 * ymirhome — the DOOR into ymirhome.
 *
 * The Allfather, 2026-10-02: *"we need to have some kind of door to come into Ymir Home … we need
 * to build an extension for ymir home now because we're creating bloat. to be creating great things
 * but in the wrong way."* and *"that extension maybe just could take care of the gate pushes for the
 * home."*
 *
 * So four tools, and they are THIN on purpose: each one names the door it calls and does the
 * classification the layout law already states. This is the surface, not the logic — logic lives
 * in bin/ (a door a human or a cron row can also run), so nothing here is a second implementation
 * that can drift from the first.
 *
 * The laws this enforces (register §7 / Rule 11 / plan 66):
 *   · ymir_place is the ONLY way a document enters the home. It classifies by the layout map and
 *     REFUSES what it cannot justify — because a document arriving unclassified is the input to
 *     bloat, and auditing the aftermath is the symptom.
 *   · a file is never DELETED; it MOVES, with why and what replaced it.
 *   · the vault is pushed by NAME (never `git add -A`): a scratch file written seconds earlier
 *     would otherwise be swept into a commit and pushed.
 */

import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { existsSync , readFileSync } from "node:fs";

const HOME = resolveHome();
// Ymir's TOOLS are the repo's; only its DATA is the home's. So the well's door is
// bin/mimir.sh beside this extension, and it resolves the home through the env.

// ── resolution: this file must run on ANY seat, so it may not know a machine ──
// (Rule 07. 2026-10-03: this extension carried a hardcoded `/home/heimdall/ymir`.)
// This is the JS mirror of `ymir_root_verified` in bin/valknut-load.sh — same contract,
// same order: $YMIR_ROOT, then the recorded roots, first one that really holds the house.
// One reader in the shell, one here; they must agree, or a worktree seat reads a dead path.
function resolveRoot(): string {
  const fromEnv = process.env.YMIR_ROOT?.trim();
  if (fromEnv) return fromEnv;
  const pointer = join(homedir(), ".pi", "agent", "extensions", ".ymir-root");
  if (existsSync(pointer)) {
    for (const line of readFileSync(pointer, "utf8").split("\n")) {
      const root = line.trim();
      if (!root) continue;
      if (existsSync(join(root, "bin", "syn-watch-arm.sh"))) return root;
    }
  }
  throw new Error(
    "YMIR_ROOT is not set and ~/.pi/agent/extensions/.ymir-root holds no usable root. " +
    "Run `bin/valknut-load.sh --all --global` from your Ymir checkout — install records " +
    "the root, and every extension reads it from there.",
  );
}

const ROOT_BIN = resolveRoot();

/** The layout law, in one place: what a path means decides where it may live. */
const SHELVES: { match: RegExp; where: string; why: string }[] = [
  { match: /^hodd\/docs\//, where: "private reference", why: "docs about the operator's own machine" },
  { match: /^hodd\/life\/marketing\//, where: "private reference", why: "marketing plans and records" },
  { match: /^hodd\/memory\/daily\//, where: "private reference", why: "a dated daily log" },
  { match: /^hodd\/secrets\//, where: "NEVER a document", why: "credentials belong here, never in a doc" },
  { match: /^hodd\/reference\//, where: "private reference", why: "a retired file kept to be learned from" },
  { match: /^svartalfaheim\/[^/]+\/projects\/[^/]+\/plans\//, where: "plan ledger", why: "a numbered plan for a project" },
  { match: /^svartalfaheim\/[^/]+\/projects\/[^/]+\//, where: "realm project shelf", why: "a project's own material" },
];

function run(cmd: string, args: string[], cwd?: string): string {
  return execFileSync(cmd, args, {
    cwd,
    encoding: "utf8",
    maxBuffer: 8 * 1024 * 1024,
    env: { ...process.env, YMIR_HOME: HOME },
  }).trim();
}

/** Classify one proposed home-relative path, or say why it cannot be placed. */
function classify(rel: string): { ok: boolean; shelf: string; why: string } {
  if (rel.startsWith("/")) return { ok: false, shelf: "", why: "absolute path — give it relative to the home" };
  if (rel.split("/").includes("..")) return { ok: false, shelf: "", why: "a path may not escape the home" };
  if (rel.endsWith(".env") || /secret|credential|token/i.test(rel)) {
    return { ok: false, shelf: "", why: "that looks like a credential; secrets live in hodd/secrets/, never in a document" };
  }
  for (const s of SHELVES) {
    if (s.match.test(rel)) return { ok: true, shelf: s.where, why: s.why };
  }
  return { ok: false, shelf: "", why: "no shelf claims it — name the shelf, or let ymir_find show where its neighbours live" };
}

// The house pattern: the deployed extensions take `pi` untyped, so the module
// parses under every loader Pi uses (a type-only import is the one thing that
// node --experimental-strip-types --check rejects).
export default function ymirhome(pi: any) {


  // The grade vocabulary is Norse because it names STATES, not figures — which is
  // how the naming law lets a word in when a figure would blur a role that is
  // already taken (Forseti judges PRs; Vörðr is the wards).
  const GRADES = [
    { g: "safn", mean: "archive",  why: "moved here on purpose; read, never edited" },
    { g: "forn",  mean: "old",      why: "superseded by a newer doc, or untouched a long time" },
    { g: "eldri", mean: "aging",    why: "still referenced, but not recently changed" },
    { g: "nýr",   mean: "fresh",    why: "changed recently, and nothing supersedes it" },
  ];


  // The header format every home document carries. Declared truth beats inference:
  // the grader reads THIS first, and only falls back to measuring when a doc has
  // not declared one. That is the difference between a record that says how it was
  // verified and one we guess at from grep.
  // The full set, each field earned by a failure we actually hit (plan 66 §10).
  // Order matters: it is the reading order for a human and a machine alike.
  const HEADER_FIELDS = [
    "kind",            // plan | runbook | record | register | index | document  (routing)
    "status",          // live | superseded | archived                            (is it current)
    "verified",        // YYYY-MM-DD, or empty — never guessed
    "verified_by",     // the gate, the fix note, or who proved it
    "supersedes",      // path this replaces
    "superseded_by",   // path that replaced this
    "grade",           // WRITTEN BY THE GRADER, never by a human: nyr|eldri|forn|safn
    "aliases",         // former names, so a search finds a doc after a rename
    "canonical",       // true|false — the working copy is not the master
    "origin",          // where the claim came from (a port, a doc, a measurement)
    "used_by",         // skill / door / gate that consumes it (the one-to-one law)
    "sensitivity",     // private | internal — lets the door REFUSE a secret
    "owner",           // who answers for this
  ] as const;


  // ── the well: drink before you act, water it after ────────────────────────
  // The house law is 'recall on the way in, observe on the way out'. A door into
  // the home that cannot reach the well makes an agent file a lesson it already
  // knows, and re-file one it has filed. So the well is part of the DOOR, not a
  // separate thing the agent has to remember to use.
  pi.registerTool({
    name: "ymir_recall",
    description:
      "RECALL from the well before acting on anything the home owns. The house law: drink before " +
      "you act. Thin — it calls bin/mimir.sh, so a human or a cron row recalls the same way.",
    parameters: {
      type: "object",
      properties: {
        query: { type: "string", description: "what you are about to do, in words" },
        limit: { type: "number", description: "episodes to return (default 5)" },
      },
      required: ["query"],
    },
    handler: async (args: any) => {
      try {
        const out = run("bash", ["-c", '"$1" recall "$2" "$3"', "_",
          `${ROOT_BIN}/bin/mimir.sh`, String(args.query), String(args.limit ?? 5)], HOME);
        return { output: out || "the well has nothing on that (an empty well is a real answer, not a failure)" };
      } catch (e: any) {
        return { output: "the well did not answer: " + String(e?.message ?? e).split("\n")[0] };
      }
    },
  });

  pi.registerTool({
    name: "ymir_remember",
    description:
      "OBSERVE into the well — water it after. Records what was learned, so the NEXT machine (or " +
      "the next session) starts where this one finished. Tags and actors optional; the value is the " +
      "claim, not the transcript.",
    parameters: {
      type: "object",
      properties: {
        lesson: { type: "string", description: "what was learned, as a claim about the work" },
        tags: { type: "array", items: { type: "string" } },
        actors: { type: "array", items: { type: "string" } },
      },
      required: ["lesson"],
    },
    handler: async (args: any) => {
      try {
        const parts = [String(args.lesson)];
        if (args.tags?.length) parts.push(`tags: ${(args.tags as string[]).join(",")}`);
        if (args.actors?.length) parts.push(`actors: ${(args.actors as string[]).join(",")}`);
        run("bash", ["-c", '"$1" observe "$2"', "_", `${ROOT_BIN}/bin/mimir.sh`, parts.join(" ")], HOME);
        return { output: "observed into the well. Next: ymir_note it into the plan it belongs to, or ymir_push the doc that carries it." };
      } catch (e: any) {
        return { output: "the well did not take it: " + String(e?.message ?? e).split("\n")[0] };
      }
    },
  });

  pi.registerTool({
    name: "ymir_header",
    description:
      "The header every document in ymirhome carries, and a checker/fixer for it. `--check` lists " +
      "every doc that has no header or a stale one; `--apply` adds a minimal one. Declared truth " +
      "beats measurement: kind · status · verified · verified_by · supersedes · superseded_by. " +
      "It is also what ymir_dellingr grades from, so a record states how it was proven instead of " +
      "being guessed at from file times.",
    parameters: {
      type: "object",
      properties: {
        action: { type: "string", description: "check | apply" },
        path: { type: "string", description: "home-relative doc or shelf; omit for all of hodd/" },
      },
      required: ["action"],
    },
    handler: async (args: any) => {
      const root = args.path ? `${HOME}/${String(args.path)}` : `${HOME}/hodd`;
      const apply = String(args.action) === "apply";
      const out: string[] = [];
      let ok = 0, applied = 0, missing: string[] = [];
      try {
        const files = run("bash", ["-c", `find "$1" -name '*.md' -not -path '*/.git/*' | head -200`, "_", root], HOME)
          .split("\n").filter(Boolean);
        for (const abs of files) {
          const rel = abs.replace(`${HOME}/`, "");
          const head = run("bash", ["-c", `head -20 "$1"`, "_", abs], HOME);
          const hasHeader = /^---\s*$/m.test(head.split("\n").slice(0, 2).join("\n")) || head.trimStart().startsWith("---");
          if (hasHeader) { ok++; continue; }
          missing.push(rel);
          if (!apply) continue;
          // a MINIMAL header: kind + status + verified + verified_by. It asserts
          // nothing false — 'unverified' is an honest starting value.
          // Derive only what can be DERIVED honestly; leave the rest empty rather
          // than assert something we did not prove.
          const isReg = /(^|\/)(README|INDEX|register)\.md$/i.test(rel);
          const isRun = /runbook|howto|setup|deploy/i.test(rel);
          const kind = isReg ? (rel.includes("/plans/") ? "register" : "index") : isRun ? "runbook" : "document";
          const hdr = [
            "---",
            `kind: ${kind}`,
            "status: live",
            "verified:",                 // unknown until someone proves it — and it is not our job to guess
            "verified_by:",
            "supersedes:",
            "superseded_by:",
            `grade: unmeasured`,          // the grader writes this, not a human
            "aliases:",
            "canonical: false",          // the master is the vault's copy unless proven otherwise
            "origin:",
            "used_by:",
            "sensitivity: internal",
            "owner:",
            "---",
            "",
          ].join("\n");
          run("bash", ["-c", `printf '%s' "$2" | cat - "$1" > "$1.tmp" && mv "$1.tmp" "$1"`, "_", abs, hdr], HOME);
          applied++;
        }
      } catch (e: any) {
        out.push("failed: " + String(e?.message ?? e).split("\n")[0]);
      }
      out.push(apply
        ? `applied the FULL header where none existed: ${applied} · already had one: ${ok}`
        : `with a header: ${ok} · without: ${missing.length}`);
      if (apply) out.push("  derived: kind from the path (register/index/runbook/document) · grade is 'unmeasured' until the grader reads it · verified left EMPTY because nobody has proved it yet — an empty field is honest, a filled one would not be.");
      if (apply && missing.length) out.push(`  next: ymir_push with those ${applied} paths BY NAME (never -A), or a human to review them first.`);
      if (!apply && missing.length) out.push(...missing.slice(0, 20).map((m) => "  " + m));
      // ── the FILL RATE: a header that is present but empty carries nothing ─────
      // The Allfather: 'how do we know the format will actually contain what the
      // documents and plans are talking about?' So the tool measures its own
      // usefulness: per field, how many documents DECLARE it against how many
      // carry it empty. A field at 0% is a field nobody has earned — and it is
      // named here, so it cannot be quietly believed in.
      const filled: Record<string, number> = {};
      for (const f of HEADER_FIELDS) filled[f] = 0;
      let declared = 0;
      try {
        const heads = run("bash", ["-c", `find "$1" -name '*.md' -not -path '*/.git/*' | head -300`, "_", root], HOME)
          .split("\n").filter(Boolean);
        for (const abs of heads) {
          const head = run("bash", ["-c", `head -20 "$1"`, "_", abs], HOME);
          if (!head.trimStart().startsWith("---")) continue;
          declared++;
          for (const line of head.split("\n")) {
            if (!line.includes(":")) continue;
            const key = line.slice(0, line.indexOf(":")).trim();
            const val = line.slice(line.indexOf(":") + 1).trim();
            if (!HEADER_FIELDS.includes(key as any)) continue;
            // A value counts only if it is really there: an empty field, the literal
            // 'unmeasured', and a false canonical are all NOT a declaration.
            if (val && val !== "unmeasured" && val !== "false") filled[key]++;
          }
        }
      } catch { /* the report must never break the tool */ }
      out.push("");
      out.push(`fill rate over ${declared} declared header(s) — a field at 0% is a field nobody has earned:`);
      for (const f of HEADER_FIELDS) {
        const pct = declared ? Math.round((filled[f] / declared) * 100) : 0;
        out.push(`  ${f.padEnd(14)} ${String(filled[f]).padStart(4)}/${declared}  ${pct}%`);
      }
      out.push("");
      out.push("the format: --- · kind · status · verified · verified_by · supersedes · superseded_by · grade · aliases · canonical · origin · used_by · sensitivity · owner");
      return { output: out.join("\n") };
    },
  });

  pi.registerTool({
    name: "ymir_find_home",
    description:
      "WHERE SHOULD THIS FILE GO? The placement oracle: takes a file (anywhere on this machine, " +
      "inside the home or not) and answers with the destination shelf, the reason, and whether it " +
      "already sits in a legal place. It NEVER moves anything — answer first, then ymir_place or " +
      "ymir_import to act. Use it before you file, so nothing is placed by guess.",
    parameters: {
      type: "object",
      properties: {
        path: { type: "string", description: "absolute or home-relative path of the file in question" },
        note: { type: "string", description: "one line about what it is, when the name says nothing" },
        sample: { type: "string", description: "a few words from its content, to classify by subject" },
      },
      required: ["path"],
    },
    handler: async (args: any) => {
      const raw = String(args.path);
      const abs = raw.startsWith("/") ? raw : `${HOME}/${raw}`;
      const base = raw.split("/").pop() ?? raw;
      const text = [base, String(args.note ?? ""), String(args.sample ?? "")].join(" ").toLowerCase();

      // 1. already home and legal? say so and stop.
      if (abs.startsWith(`${HOME}/`)) {
        const rel = abs.slice(HOME.length + 1);
        const here = classify(rel);
        return {
          output: here.ok
            ? `already home, and legal:\n  ${rel}\n  shelf: ${here.shelf} (${here.why})\n  nothing to do.`
            : `it is INSIDE the home but in no legal shelf:\n  ${rel}\n  reason: ${here.why}\n  move it with ymir_place(..., move:true) into hodd/reference/ if it is retired.`,
        };
      }

      // 2. classify by subject, most specific first.
      const rules: Array<{ re: RegExp; shelf: string; why: string }> = [
        { re: /secret|credential|\.env$|\.pem$|\.key$|token/, shelf: "hodd/secrets/", why: "a credential — the one place values may live" },
        { re: /masterplan|plan 66|roadmap|master plan/, shelf: "svartalfaheim/whynotproductions/projects/ymir/plans/", why: "a masterplan or architecture plan belongs in the ledger" },
        { re: /register|inventory|index/, shelf: "svartalfaheim/whynotproductions/projects/ymir/plans/", why: "a register is an index — it lives with the plans it indexes" },
        { re: /calendar|mánagandr|managandr|memory|well|engram/, shelf: "svartalfaheim/whynotproductions/projects/ymir/plans/", why: "a feature's design belongs in its plan, not loose" },
        { re: /postiz|social|campaign|marketing|brand|content/, shelf: "hodd/life/marketing/", why: "the operator's own marketing domain" },
        { re: /meeting|minute|standup|1:1/, shelf: "hodd/life/meetings/", why: "a meeting artefact" },
        { re: /journal|diary|personal/, shelf: "hodd/life/personal/", why: "the operator's own personal domain" },
        { re: /runbook|howto|setup|install/, shelf: "hodd/docs/runbooks/", why: "a runbook is a doc about a machine" },
        { re: /architecture|deep.?dive|audit/, shelf: "hodd/docs/", why: "architecture or audit material about the house" },
        { re: /readme|changelog|contribut/, shelf: "hodd/reference/", why: "repo boilerplate — reference, not a house doc" },
      ];
      const hit = rules.find((r) => r.re.test(text));
      let dest = hit ? `${hit.shelf}${base}` : `hodd/reference/imported/${base}`;
      // Two files can share a name (every repo has a README.md). Nest by the source's
      // parent when the flat destination is already taken — a proposal that would
      // overwrite something is worse than no proposal.
      const parent = raw.replace(/\/$/, "").split("/").slice(-2, -1)[0] ?? "";
      const destExists = existsSync(`${HOME}/${dest}`);
      if (destExists && parent && !/^(hodd|svartalfaheim|imported|reference)$/.test(parent)) {
        dest = `${hit ? hit.shelf : "hodd/reference/imported/"}${parent}--${base}`;
      }
      const why = hit ? hit.why : "no rule claims it — reference is the safe shelf; say so in the report";
      const verdict = classify(dest);
      if (!verdict.ok) return { output: `refused: ${verdict.why}\n  would have been: ${dest}` };
      return {
        output:
          `outside the home →\n  ${base}\n  destination: ${dest}\n  because: ${why}\n` +
          `  shelf: ${verdict.shelf}\n` +
          (hit ? "" : "  ⚠ this was a fallback, not a confident classification — confirm it.\n") +
          `  next: ymir_import({ sources: ["${raw}"], dryRun:true }) to confirm, then act.`,
      };
    },
  });

  pi.registerTool({
    name: "ymir_place",
    description:
      "The ONLY sanctioned way a document enters ymirhome. Classifies the proposed path against the " +
      "layout law and refuses what it cannot justify. Never deletes: to retire a file, place it in " +
      "hodd/reference/ with why it went and what replaced it.",
    parameters: {
      type: "object",
      properties: {
        path: { type: "string", description: "home-RELATIVE destination, e.g. hodd/docs/runbooks/thing.md" },
        source: { type: "string", description: "absolute path of the file being placed" },
        why: { type: "string", description: "one line: why it belongs on that shelf" },
        move: { type: "boolean", description: "true = retire an existing file (moves it, never deletes)" },
      },
      required: ["path", "why"],
    },
    handler: async (args: any) => {
      const verdict = classify(String(args.path));
      if (!verdict.ok) {
        return { output: `refused: ${verdict.why}\n  proposed: ${args.path}` };
      }
      const dest = `${HOME}/${args.path}`;
      const lines = [`placed → ${args.path}`, `  shelf: ${verdict.shelf}`, `  because: ${args.why}`];
      if (args.source) {
        const src = String(args.source);
        try {
          run("mkdir", ["-p", dest.slice(0, dest.lastIndexOf("/"))]);
          // git mv when the source is tracked: the vault is a repo and a move is a rename,
          // which is how history reads. Never `git add -A`.
          let staged = false;
          try {
            run("git", ["mv", src, dest], HOME);
            staged = true;
          } catch {
            run("mv", [src, dest]);
          }
          lines.push(`  ${staged ? "git mv (a rename in history)" : "moved (untracked)"}`);
        } catch (e: any) {
          lines.push(`  NOT moved: ${String(e?.message ?? e).split("\n")[0]}`);
        }
      }
      lines.push(`  next: name it in the shelf's README row, or in register.md if it is an ask.`);
      return { output: lines.join("\n") };
    },
  });


  // ── the rest of the door ───────────────────────────────────────────────────
  // Each of these exists because tonight needed it by hand. A door that only
  // covers the first four still leaves the agent reaching for bash.


  pi.registerTool({
    name: "ymir_structure",
    description:
      "The SHAPE of ymirhome as it actually is right now: every shelf, how many files it holds, and " +
      "the convention that applies to it. Ask this before filing anything, so an agent knows the " +
      "structures rather than guessing them.",
    parameters: { type: "object", properties: { depth: { type: "number", description: "default 2" } } },
    handler: async (args: any) => {
      const depth = Number(args.depth || 2);
      const rows: string[] = [];
      const walk = (dir: string, level: number) => {
        if (level > depth) return;
        let entries: string[] = [];
        try {
          entries = run("bash", ["-c", `ls -A "$1" 2>/dev/null`, "_", dir], HOME).split("\n").filter(Boolean);
        } catch { return; }
        for (const e of entries) {
          if (e.startsWith(".")) continue;
          const abs = `${dir}/${e}`;
          const isDir = run("bash", ["-c", `[ -d "$1" ] && echo yes || echo no`, "_", abs], HOME) === "yes";
          if (!isDir) continue;
          let n = "0";
          try { n = run("bash", ["-c", `find "$1" -type f | wc -l`, "_", abs], HOME); } catch { /* keep 0 */ }
          rows.push(`${"  ".repeat(level)}${e}/  (${n} files)`);
          walk(abs, level + 1);
        }
      };
      try {
        walk(`${HOME}/hodd`, 0);
        walk(`${HOME}/svartalfaheim`, 0);
        const untracked = run("git", ["status", "--porcelain"], HOME).split("\n").filter((l) => l.startsWith("??"));
        rows.push("", "strays (untracked, unfiled): " + (untracked.length ? untracked.map((l) => l.slice(3)).join(", ") : "none"));
        rows.push("conventions: hodd/ is PRIVATE material · svartalfaheim/ is realm+project · a register is an INDEX · depth lives in a plan · never delete, only move.");
      } catch (e: any) {
        rows.push("could not walk the home: " + String(e?.message ?? e).split("\n")[0]);
      }
      return { output: rows.join("\n") };
    },
  });

  pi.registerTool({
    name: "ymir_import",
    description:
      "Bring documentation IN FROM OUTSIDE the home and file it where it belongs: classifies the " +
      "content and the name against the layout law, proposes the destination, and moves it with " +
      "git mv so the vault's history shows a rename. Import is the only sanctioned way material " +
      "arrives from another project.",
    parameters: {
      type: "object",
      properties: {
        sources: { type: "array", items: { type: "string" }, description: "absolute paths OUTSIDE the home" },
        area: { type: "string", description: "marketing | personal | work | research | reference — or let the classifier decide" },
        dryRun: { type: "boolean", description: "propose without moving (default true)" },
      },
      required: ["sources"],
    },
    handler: async (args: any) => {
      const dry = args.dryRun !== false;
      const lines: string[] = [];
      for (const raw of (args.sources as string[]) ?? []) {
        const src = String(raw);
        if (src.startsWith(HOME)) { lines.push(`skip ${src} — already inside the home`); continue; }
        const base = src.split("/").pop() ?? "";
        let dest = "";
        const area = String(args.area ?? "");
        const hint = (area || base).toLowerCase();
        if (/market|ads|campaign|brand|postiz/.test(hint)) dest = "hodd/life/marketing/imported/";
        else if (/meeting|note|personal|journal/.test(hint)) dest = "hodd/life/personal/imported/";
        else if (/research|paper|arxiv|readme/.test(hint)) dest = "hodd/docs/research/imported/";
        else if (/plan|roadmap|proposal|strategy/.test(hint)) dest = "hodd/life/work/imported/";
        else dest = "hodd/reference/imported/";
        const verdict = classify(`${dest}${base}`);
        if (!verdict.ok) { lines.push(`refused ${base}: ${verdict.why}`); continue; }
        const abs = `${HOME}/${dest}${base}`;
        lines.push(`${dry ? "would import" : "imported"}  ${src}  ->  ${dest}${base}   (${verdict.why})`);
        if (dry) continue;
        try {
          run("mkdir", ["-p", abs.slice(0, abs.lastIndexOf("/"))], HOME);
          run("git", ["mv", src, abs], HOME);
          lines.push(`  git mv — a rename in the vault's history, never a copy`);
        } catch (e: any) {
          lines.push("  NOT moved: " + String(e?.message ?? e).split("\n")[0]);
        }
      }
      if (args.area === undefined) lines.push("classifier used the filename; pass `area` to override.");
      return { output: lines.join("\n") };
    },
  });

  pi.registerTool({
    name: "ymir_secret_keys",
    description:
      "Which secret key NAMES exist in the vault. Never values - a name can be printed, a value " +
      "never leaves the vault. Use it to answer 'is the grant there?' without touching a secret.",
    parameters: { type: "object", properties: { filter: { type: "string", description: "substring, e.g. GOOGLE" } } },
    handler: async (args: any) => {
      try {
        const names = run("bash", [
          "-c",
          `set -u; f="$1"; if [ -f "$f.age" ]; then age -d -i "$f.key" "$f.age" 2>/dev/null; elif [ -f "$f" ]; then cat "$f"; fi | grep -oE '^[A-Za-z0-9_]+=' | tr -d '=' | sort -u`,
          "_",
          `${HOME}/hodd/secrets/platform.env`,
        ])
          .split("\n")
          .filter(Boolean)
          .filter((n) => !args.filter || n.toLowerCase().includes(String(args.filter).toLowerCase()));
        return { output: names.length ? names.join("\n") : "no matching key names (values are never printed)" };
      } catch (e: any) {
        return { output: "could not read the vault: " + String(e?.message ?? e).split("\n")[0] };
      }
    },
  });

  pi.registerTool({
    name: "ymir_layout",
    description:
      "The layout law itself: which shelf a home-relative path belongs to, and where a given " +
      "thing lives. Ask before writing, so nothing is filed by guess.",
    parameters: { type: "object", properties: { path: { type: "string" } } },
    handler: async (args: any) => {
      if (args.path) {
        const v = classify(String(args.path));
        return { output: v.ok ? `${v.path}\n  shelf: ${v.shelf}\n  because: ${v.why}` : `refused: ${v.why}` };
      }
      return {
        output:
          "hodd/            private material (docs · data · memory · identity · life/<domain>)\n" +
          "  hodd/life/<domain>/   the operator's own domains: marketing · personal · work · meetings\n" +
          "  hodd/reference/       retired files, kept to be learned from (Rule 11)\n" +
          "  hodd/secrets/         credentials — never a document\n" +
          "svartalfaheim/<realm>/projects/<project>/\n" +
          "  …/plans/              the canonical plan ledger\n" +
          "  …/docs/                that project's documents\n" +
          "Law: a register is an INDEX (state + a link); depth lives in a plan.",
      };
    },
  });

  pi.registerTool({
    name: "ymir_find",
    description: "Where something lives in ymirhome — by name and by content — without grep spelunking.",
    parameters: {
      type: "object",
      properties: {
        what: { type: "string", description: "a name, a phrase, or a path fragment" },
        content: { type: "boolean", description: "search inside files, not just names" },
      },
      required: ["what"],
    },
    handler: async (args: any) => {
      const what = String(args.what);
      try {
        const out = args.content
          ? run("grep", ["-ril", "--exclude-dir=.git", what, HOME])
          : run("find", [HOME, "-iname", `*${what}*`]);
        const rows = out.split("\n").filter(Boolean).slice(0, 40).map((p) => p.replace(HOME, "~"));
        return { output: rows.length ? rows.join("\n") : `nothing matched "${what}"` };
      } catch {
        return { output: `nothing matched "${what}"` };
      }
    },
  });

  pi.registerTool({
    name: "ymir_index",
    description:
      "What is uncalled, stale or orphaned in the shelves: untracked strays, empty dirs, files with no " +
      "README row, and the size of each shelf.",
    parameters: { type: "object", properties: { shelf: { type: "string" } } },
    handler: async () => {
      const out: string[] = [];
      try {
        out.push("untracked (strays — ymir_place or git add by NAME, never -A):");
        const un = run("git", ["status", "--porcelain"], HOME).split("\n").filter((l) => l.startsWith("??"));
        out.push(...(un.length ? un.map((l) => "  " + l.slice(3)) : ["  none"]));
        out.push("", "last push: " + (run("git", ["log", "-1", "--format=%h %ad %s", "--date=short"], HOME) || "unknown"));
        out.push("in sync: " + (run("git", ["rev-list", "--left-right", "--count", "origin/main...main"], HOME) || "?"));
      } catch (e: any) {
        out.push("could not read the home: " + String(e?.message ?? e).split("\n")[0]);
      }
      return { output: out.join("\n") };
    },
  });
}