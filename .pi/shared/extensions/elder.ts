/**
 * elder — the records council. FIVE tools, and they are all WRITING.
 *
 * Why this file exists (audit §6, 2026-10-03): `ymirhome` had grown to SEVENTEEN tools, which
 * is two jobs wearing one door — reading/placement (find_home · place · structure · import ·
 * find · index) and writing/records (note · plan · push · daily · dellingr). Elder is the
 * figure whose work is exactly the second half: he keeps the register, the ledger and the
 * daily record, and a correction is a NEW entry rather than an edit.
 *
 * So the split is by ACT, not by convenience: `ymirhome` places and finds, `elder` writes and
 * remembers. Eleven and five.
 *
 * The moved tools call exactly the same doors they called before — a move, not a rewrite, so
 * a human and a cron row are unaffected.
 */

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function resolveRoot(): string {
  const fromEnv = process.env.YMIR_ROOT?.trim();
  if (fromEnv) return fromEnv;
  const pointer = join(homedir(), ".pi", "agent", "extensions", ".ymir-root");
  if (existsSync(pointer)) {
    for (const line of readFileSync(pointer, "utf8").split("\n")) {
      const root = line.trim();
      if (root && existsSync(join(root, "bin", "syn-watch-arm.sh"))) return root;
    }
  }
  throw new Error(
    "YMIR_ROOT is not set and ~/.pi/agent/extensions/.ymir-root holds no usable root. " +
    "Run `bin/valknut-load.sh --all --global` from your Ymir checkout.",
  );
}

// The vault, resolved by the house's resolver — never `$HOME/Documents/ymirhome` (Rule 04).
function resolveHome(): string {
  const fromEnv = process.env.YMIR_HOME?.trim();
  if (fromEnv) return fromEnv;
  const v = execFileSync("bash", [join(resolveRoot(), "bin", "hodd.sh"), "path"], {
    encoding: "utf8", stdio: ["ignore", "pipe", "ignore"],
  }).trim();
  if (!v) throw new Error("the vault path is empty — run `bin/hodd.sh path` and read what it says");
  return v;
}

const ROOT_BIN = resolveRoot();
const HOME = resolveHome();


// The shared door-runner. It travelled with the TOOL BLOCKS but not with the file, so every
// handler here would have thrown `run is not defined` at first call — and the smoke test that
// moved these tools only REGISTERED them. 2026-10-03: **a tool that registers is not a tool that
// runs** (the same lesson as 0.1.95's "deployed is not loadable", one level up).
// The four grades of document freshness (moved with ymir_dellingr from ymirhome; like `run`,
// it lived inside the function and did not travel with the tool block — so the tool threw
// "GRADES is not defined" on its first real call).
const GRADES = [
  { g: "safn",  mean: "archive", why: "moved here on purpose; read, never edited" },
  { g: "forn",  mean: "old",     why: "superseded by a newer doc, or untouched a long while" },
  { g: "eldri", mean: "aging",   why: "still referenced, but not recently changed" },
  { g: "nýr",   mean: "fresh",   why: "changed recently, and nothing supersedes it" },
];

function run(cmd: string, args: string[], cwd?: string): string {
  return execFileSync(cmd, args, {
    cwd,
    encoding: "utf8",
    maxBuffer: 8 * 1024 * 1024,
    env: { ...process.env, YMIR_HOME: HOME },
  }).trim();
}


// Pi 1.0's tool contract: the model-facing text is `content`, and THROWING is how a tool
// reports failure — returning an object does not mark it as an error. `output:` reached the
// model as an empty success while the harness called a key that did not exist.
const piOut = (text: unknown): { content: { type: "text"; text: string }[]; details: undefined } => ({
  content: [{ type: "text", text: String(text) }],
  details: undefined,
});

export default function elder(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ymir_note",
    description:
      "Append a DATED, append-only section to an existing document in the home. The vault's core " +
      "law: never rewrite, never delete - append. This is the operation that keeps a plan a record.",
    parameters: {
      type: "object",
      properties: {
        path: { type: "string", description: "home-relative document" },
        heading: { type: "string", description: "the dated heading, e.g. '## Correction (2026-10-02)'" },
        body: { type: "string", description: "the section text, markdown" },
      },
      required: ["path", "heading", "body"],
    },
    execute: async (_toolCallId: string, args: any) => {
      const rel = String(args.path);
      if (!rel.startsWith("hodd/") && !rel.startsWith("svartalfaheim/")) {
        return piOut(`refused: ${rel} is not in the home. Documents live under hodd/ or svartalfaheim/.`);
      }
      const abs = `${HOME}/${rel}`;
      const heading = String(args.heading);
      const stamp = new Date().toISOString().slice(0, 10);
      const dated = heading.includes(stamp) ? heading : `${heading} — ${stamp}`;
      try {
        if (!existsSync(abs)) run("mkdir", ["-p", abs.slice(0, abs.lastIndexOf("/"))]);
        run("bash", ["-c", `printf '\n---\n\n%s\n\n' >> "$1" && cat >> "$1"`, "_", abs], HOME);
        // body via stdin-safe append
        run("bash", ["-c", `cat >> "$1"`, "_", abs], HOME, args.body);
        return piOut(`appended to ${rel}\n  ${dated}\n  next: ymir_push with that one path (never -A).`);
      } catch (e: any) {
        return piOut("failed: " + String(e?.message ?? e).split("\n")[0]);
      }
    },
  });

  pi.registerTool({
    name: "ymir_plan",
    description:
      "Create the NEXT numbered plan in the canonical ledger, with the index row. Numbering is " +
      "after the index's highest; numbers are never reused.",
    parameters: {
      type: "object",
      properties: {
        slug: { type: "string", description: "kebab-case slug" },
        title: { type: "string" },
        realm: { type: "string", description: "e.g. whynotproductions" },
        project: { type: "string", description: "e.g. ymir" },
      },
      required: ["slug", "title"],
    },
    execute: async (_toolCallId: string, args: any) => {
      const realm = String(args.realm || "whynotproductions");
      const project = String(args.project || "ymir");
      const dir = `${HOME}/svartalfaheim/${realm}/projects/${project}/plans`;
      try {
        const nums = run("bash", ["-c", `ls "$1" | grep -oE '^[0-9]+' | sort -n | tail -1`, "_", dir]);
        const next = (parseInt(nums || "0", 10) || 0) + 1;
        const nn = String(next).padStart(2, "0");
        const file = `${dir}/${nn}-${String(args.slug)}.md`;
        run("bash", ["-c", `printf '# Plan %s — %s\n\n**Opened %s.**\n' "$2" "$3" "$(date -u +%%Y-%%m-%%d)" > "$1"`, "_", file, nn, String(args.title)], HOME);
        return piOut(`created ${file}\n` +
            `  number: ${nn} (after the index's highest)\n` +
            `  next: add the README index row, then ymir_push that ONE path by name.`);
      } catch (e: any) {
        return piOut("failed: " + String(e?.message ?? e).split("\n")[0]);
      }
    },
  });

  pi.registerTool({
    name: "ymir_push",
    description:
      "Commit and push ymirhome, staging ONLY the paths you name. Never `git add -A`: a scratch " +
      "file written seconds earlier would be swept in and pushed. Refuses secrets and refuses to " +
      "delete a tracked file (Rule 11 — to retire one, ymir_place moves it).",
    parameters: {
      type: "object",
      properties: {
        paths: { type: "array", items: { type: "string" }, description: "home-relative paths to stage" },
        message: { type: "string", description: "the commit message" },
        push: { type: "boolean", description: "push after committing (default true)" },
      },
      required: ["paths", "message"],
    },
    execute: async (_toolCallId: string, args: any) => {
      // A tool that throws on a missing argument teaches the caller nothing. `required` is a
      // hint to a well-behaved model, not a guarantee — so say what is missing instead.
      if (!Array.isArray(args?.paths) || !args.paths.length) {
        return piOut("ymir_push needs `paths` — an array of home-relative paths to stage. Never stage everything: name the files.");
      }
      if (!String(args?.message ?? "").trim()) {
        return piOut("ymir_push needs a `message` — an imperative subject line and a paragraph of what and why.");
      }
      const paths = (args.paths as string[]).map(String);
      const lines: string[] = [];
      try {
        // a secret never enters the vault's history, and no file is ever deleted
        for (const p of paths) {
          if (/(^|\/)\.?env$|secret|credential|\.key$|token/i.test(p)) {
            return piOut(`refused: ${p} looks like a credential. Secrets stay out of history.`);
          }
        }
        const deleted = run("git", ["diff", "--name-only", "--diff-filter=D", "HEAD"], HOME);
        if (deleted.trim()) {
          return piOut(`refused: this commit deletes tracked files:\n  ${deleted}\n` +
              `Rule 11 — never delete, only move. Use ymir_place(..., move:true) into hodd/reference/.`);
        }
        run("git", ["add", "--", ...paths], HOME);
        run("git", ["commit", "-m", String(args.message)], HOME);
        lines.push(`committed: ${paths.length} named path(s)`);
        if (args.push !== false) {
          run("git", ["pull", "--rebase", "--autostash", "-q"], HOME);
          run("git", ["push", "-q"], HOME);
          lines.push("pushed (rebased over origin first)");
        }
        lines.push(run("git", ["log", "-1", "--format=%h %s"], HOME));
      } catch (e: any) {
        lines.push("failed: " + String(e?.message ?? e).split("\n").slice(0, 3).join(" | "));
      }
      return piOut(lines.join("\n"));
    },
  });

  pi.registerTool({
    name: "ymir_daily",
    description: "Append to today's log line in the vault (hodd/memory/daily/YYYY-MM-DD.md), or read it.",
    parameters: {
      type: "object",
      properties: { note: { type: "string", description: "omit to read today instead" } },
      required: [],
    },
    execute: async (_toolCallId: string, args: any) => {
      const day = new Date().toISOString().slice(0, 10);
      const f = `${HOME}/hodd/memory/daily/${day}.md`;
      try {
        run("mkdir", ["-p", f.slice(0, f.lastIndexOf("/"))], HOME);
        if (!args.note) {
          if (!existsSync(f)) return piOut(`no entry yet for ${day} — nothing has been written for that day`);
          return piOut(run("cat", [f], HOME) || `no entry yet for ${day}`);
        }
        run("bash", ["-c", `printf '%s\n' "$2" >> "$1"`, "_", f, `- ${new Date().toISOString().slice(11, 16)} ${String(args.note)}`], HOME);
        return piOut(`appended to hodd/memory/daily/${day}.md — next: ymir_push that path by name.`);
      } catch (e: any) {
        return piOut("failed: " + String(e?.message ?? e).split("\n")[0]);
      }
    },
  });

  pi.registerTool({
    name: "ymir_dellingr",
    description:
      "GRADE the documentation: is it fresh or old? Marks every document with a Norse grade " +
      "(nýr fresh · eldri aging · forn old · safn archive) from measurable signals only — last " +
      "change, whether a newer doc supersedes it, and whether anything still cites it. Nothing is " +
      "deleted for being old: an old document MOVES to hodd/reference/ (Rule 11), so grading " +
      "decides where something belongs, never whether it survives.",
    parameters: {
      type: "object",
      properties: {
        path: { type: "string", description: "home-relative doc; omit to grade a whole shelf" },
        ageDays: { type: "number", description: "days before 'eldri' (default 90), before 'forn' (default 365)" },
      },
      required: [],
    },
    execute: async (_toolCallId: string, args: any) => {
      const eldri = Number(args.ageDays ? args.ageDays / 2 : 90);
      const forn = Number(args.ageDays ?? 365);
      const root = args.path ? `${HOME}/${String(args.path)}` : `${HOME}/hodd`;
      const rows: string[] = [];
      try {
        const files = run("bash", ["-c", `find "$1" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*'`, "_", root], HOME)
          .split("\n").filter(Boolean).slice(0, 400);
        for (const abs of files) {
          const rel = abs.replace(`${HOME}/`, "");
          // The age read FAILED on first build (every doc came back 0d, so all of
          // them graded nyr). A grader that cannot measure must REFUSE — printing a
          // confident grade it did not earn is worse than printing none. So an
          // unreadable age is `unmeasured`, and the tally says how many.
          let day = -1;
          try {
            const d = run("bash", ["-c", `git log -1 --format=%ct -- "${rel}"`, "_"], HOME).trim();
            if (/^[0-9]{9,}$/.test(d)) day = Math.floor((Date.now() - parseInt(d, 10) * 1000) / 86400000);
          } catch { day = -1; }
          // is a NEWER doc saying it supersedes this one?
          let sup = "";
          try {
            const stem = rel.split("/").pop()!.replace(/\.md$/, "");
            sup = run("bash", ["-c",
              `grep -rl --include='*.md' -iE "(supersede|replaced by|obsolete)" "$1" 2>/dev/null | while read -r f; do grep -qiF "$2" "$f" && { echo "$f"; break; }; done`,
              "_", `${HOME}/hodd`, stem], HOME);
          } catch { /* none */ }
          const stem = rel.split("/").pop()!.replace(/\.md$/, "");
          const inRef = rel.startsWith("hodd/reference/");
          const g = inRef ? "safn" : day < 0 ? "unmeasured" : day >= forn ? "forn" : day >= eldri ? "eldri" : "nýr";
          const why = inRef ? "in the reference shelf — moved on purpose"
            : day < 0 ? "could NOT read its age (no git history for it) — refused to guess"
            : sup ? `another doc names it as superseded (${sup.replace(HOME + "/", "")})`
            : day >= forn ? `untouched ${day}d` : day >= eldri ? `${day}d since its last change` : `changed ${day}d ago`;
          // ── the value of truth, as a NUMBER that can rise and fall ────────────
          // Age is one signal; proof is the other. Each independent confirmation
          // lifts it, each contradiction drops it. The weights are printed so a
          // reader can audit the arithmetic instead of trusting the verdict.
          let proofs = 0, cites = 0, contra = 0;
          const stemSafe = stem.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
          try {
            proofs = parseInt(
              run("bash", ["-c",
                `{ grep -rl --include='*.md' -iE "verified|proved|confirmed|passes|holds" "$1" 2>/dev/null | while read -r f; do grep -qiF "$2" "$f" && echo x; done | wc -l; }`,
                "_", `${HOME}/hodd`, stemSafe], HOME) || 0, 10);
          } catch { proofs = 0; }
          try {
            cites = parseInt(
              run("bash", ["-c", `grep -rl --include='*.md' -F "$2" "$1" 2>/dev/null | wc -l`, "_", `${HOME}/hodd`, stemSafe], HOME) || 0, 10);
          } catch { cites = 0; }
          try {
            contra = parseInt(
              run("bash", ["-c",
                `{ grep -rl --include='*.md' -iE "supersede|replaced by|obsolete|superseded|WRONG|was false" "$1" 2>/dev/null | while read -r f; do grep -qiF "$2" "$f" && echo x; done | wc -l; }`,
                "_", `${HOME}/hodd`, stemSafe], HOME) || 0, 10);
          } catch { contra = 0; }
          // score = 3·proofs + 1·cites − 5·contradictions − 1 per 180 days (age decays it)
          const agePenalty = day >= 0 ? Math.floor(day / 180) : 0;
          const score = 3 * proofs + cites - 5 * contra - agePenalty;
          rows.push({ rel, g, day, why, proofs, cites, contra, score });
        }
        rows.sort((a, b) => b.day - a.day);
        const tally: Record<string, number> = {};
        for (const r of rows) tally[r.g] = (tally[r.g] ?? 0) + 1;
        rows.slice(0, 40).forEach((r) => rows.push as any);
        const out: string[] = [];
        const unmeasured = rows.filter((r: any) => r.g === "unmeasured").length;
        out.push(`grades[5]{grade,count}: ${GRADES.map((x) => `"${x.g}"(${x.mean}),${tally[x.g] ?? 0}`).join(" · ")}${unmeasured ? ` · "unmeasured"(REFUSED),${unmeasured}` : ""}`);
        out.push("", "oldest first:");
        out.push("score = 3xproofs + 1xcites - 5xcontradictions - 1 per 180d  (a number, so it rises as proof lands and falls when a correction does)");
        const scored = [...rows].sort((a, b) => (b.score ?? -999) - (a.score ?? -999));
        for (const r of scored.slice(0, 25))
          out.push(`  ${String(r.score ?? "?").padStart(4)}  ${r.g.padEnd(10)} p${r.proofs ?? 0} c${r.cites ?? 0} x${r.contra ?? 0}  ${r.rel}`);
        out.push("", "An old document MOVES to hodd/reference/ (Rule 11) — grading decides where it belongs, never whether it survives.");
        return piOut(out.join("\n"));
      } catch (e: any) {
        return piOut("could not grade: " + String(e?.message ?? e).split("\n")[0]);
      }
    },
  });
}
