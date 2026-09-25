/**
 * Open Editor
 *
 * Opens files from the current working directory in the user's default
 * terminal editor. Resolves the editor from $VISUAL → $EDITOR → vi.
 *
 * Usage:
 *   /edit [path]   Slash command with tab-completion over cwd files.
 *                  No path → opens the current working directory
 *                  (like `nvim .` / `code .`).
 *   ctrl+shift+e   Keyboard shortcut → file picker over cwd.
 *
 * Inside Þjazi (herdr) the editor is seated in its OWN tab of the home
 * workspace — focused, labelled for the file, recorded for close-all —
 * so this session keeps its TUI and its agent alive. Outside herdr the
 * old roads remain: terminal editors (nvim, vim, …) suspend the pi TUI
 * and resume on exit; GUI editors (code, cursor, …) launch detached.
 *
 * Strictly user-facing — no LLM-callable tool is registered; agents
 * have built-in `read` and `edit` already.
 */

import { spawn, spawnSync } from "node:child_process";
import { appendFileSync, mkdirSync, readdirSync, statSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { AutocompleteItem } from "@mariozechner/pi-tui";
import { resolveYmirHome } from "./lib/ymir-home.ts";

// Editors that open in their own window / don't occupy the terminal.
// We launch these detached so pi keeps running.
const GUI_EDITORS = new Set([
	"code",
	"code-insiders",
	"cursor",
	"windsurf",
	"subl",
	"sublime_text",
	"mate",
	"atom",
	"gedit",
	"kate",
	"zed",
]);

// Editors tried in order when neither $VISUAL nor $EDITOR names one that exists.
// Ordered by fitness for a terminal session: GUI first (detached, never blocks
// pi), then the common terminal editors, with plain `vi` last.
const FALLBACK_EDITORS = [
	"code",
	"cursor",
	"zed",
	"subl",
	"nvim",
	"vim",
	"hx",
	"helix",
	"nano",
	"micro",
	"emacs",
	"vi",
];

// Directories skipped by the non-git file walk fallback.
const EXCLUDED_DIRS = new Set([
	"node_modules",
	".git",
	".hg",
	".svn",
	"dist",
	"build",
	".next",
	".nuxt",
	"target",
	".venv",
	"venv",
	"__pycache__",
	".tox",
	".mypy_cache",
	".pytest_cache",
	".cache",
	".turbo",
	".parcel-cache",
]);

const MAX_WALK_ENTRIES = 5000;
const LIST_CACHE_MS = 2000;
const MAX_COMPLETIONS = 50;

interface ResolvedEditor {
	command: string;
	argv: string[];
	isGui: boolean;
}

function resolveEditor(): ResolvedEditor {
	for (const raw of [process.env.VISUAL, process.env.EDITOR, "vi"]) {
		if (!raw || !raw.trim()) continue;
		// The configured command must actually exist: this extension runs on hosts
		// that are not Omarchy, where `$EDITOR` may name a binary that is absent
		// (Omarchy's own `omarchy-launch-editor`, or a bare `vi` on a box that only
		// has `nvim`). Never spawn into an ENOENT — fall through to a real editor.
		const parts = raw.trim().split(/\s+/).filter(Boolean);
		const command = parts[0] || "";
		if (!command) continue;
		const found = findOnPath(command);
		if (!found) continue;
		const argv = parts.slice(1);
		const isGui = GUI_EDITORS.has(basename(found).toLowerCase());
		return { command: found, argv, isGui };
	}
	// Nothing configured and nothing found: pick the first editor that exists.
	for (const candidate of FALLBACK_EDITORS) {
		const found = findOnPath(candidate);
		if (found) {
			return { command: found, argv: [], isGui: GUI_EDITORS.has(candidate) };
		}
	}
	// Truly nothing: keep the historical shape so the caller's error is familiar.
	return { command: "vi", argv: [], isGui: false };
}

// Resolve <name> on PATH, returning the absolute path or null. Handles a name
// that is already a path (`/usr/bin/nvim`).
function findOnPath(name: string): string | null {
	if (name.includes("/")) {
		try {
			statSync(name);
			return name;
		} catch {
			return null;
		}
	}
	const dirs = (process.env.PATH || "").split(":").filter(Boolean);
	for (const dir of dirs) {
		try {
			const full = join(dir, name);
			const st = statSync(full);
			if (st.isFile()) return full;
		} catch {
			// try the next directory
		}
	}
	return null;
}

// ──────────────────────────────────────────────────────────────────────
// File listing (git ls-files → bounded walk fallback) with small cache
// ──────────────────────────────────────────────────────────────────────

interface CacheEntry {
	at: number;
	files: string[];
}

const listCache = new Map<string, CacheEntry>();
const listInflight = new Map<string, Promise<string[]>>();

function walkFiles(cwd: string): string[] {
	const out: string[] = [];
	const stack: string[] = [""];
	while (stack.length > 0 && out.length < MAX_WALK_ENTRIES) {
		const rel = stack.pop()!;
		const abs = rel ? join(cwd, rel) : cwd;
		let entries;
		try {
			entries = readdirSync(abs, { withFileTypes: true });
		} catch {
			continue;
		}
		for (const e of entries) {
			if (out.length >= MAX_WALK_ENTRIES) break;
			const entryRel = rel ? `${rel}/${e.name}` : e.name;
			if (e.isDirectory()) {
				if (EXCLUDED_DIRS.has(e.name)) continue;
				stack.push(entryRel);
			} else if (e.isFile()) {
				out.push(entryRel);
			}
		}
	}
	return out.sort();
}

async function listFiles(pi: ExtensionAPI, cwd: string): Promise<string[]> {
	const cached = listCache.get(cwd);
	const now = Date.now();
	if (cached && now - cached.at < LIST_CACHE_MS) return cached.files;

	const inflight = listInflight.get(cwd);
	if (inflight) return inflight;

	const p = (async (): Promise<string[]> => {
		let files: string[] = [];
		try {
			const res = await pi.exec(
				"git",
				["ls-files", "-co", "--exclude-standard"],
				{ timeout: 2000, cwd },
			);
			if (res.code === 0 && res.stdout) {
				files = res.stdout.split("\n").map((s) => s.trim()).filter(Boolean).sort();
			}
		} catch {
			// fall through to the walk
		}
		// git misses ignored dotfiles (.env.local, .env.realm, …); the walk
		// already includes hidden entries — merge it in so the picker and the
		// tab-completion can open them too. Tracked/visible first, bounded.
		const seen = new Set(files);
		for (const entry of walkFiles(cwd)) {
			if (!seen.has(entry)) {
				files.push(entry);
				seen.add(entry);
			}
		}
		files.sort();
		listCache.set(cwd, { at: Date.now(), files });
		return files;
	})();

	listInflight.set(cwd, p);
	try {
		return await p;
	} finally {
		listInflight.delete(cwd);
	}
}

/** Synchronous accessor for tab-completion. Kicks off async refresh if cold. */
function listFilesSync(pi: ExtensionAPI, cwd: string): string[] | null {
	const cached = listCache.get(cwd);
	if (cached && Date.now() - cached.at < LIST_CACHE_MS) return cached.files;
	// Prime cache in background; return whatever we have (possibly stale).
	void listFiles(pi, cwd);
	return cached ? cached.files : null;
}

// ──────────────────────────────────────────────────────────────────────
// Þjazi (herdr): the editor keeps its own tab — never this hall
// ──────────────────────────────────────────────────────────────────────

interface HerdrEnv {
	available: boolean;
	bin: string;
	session: string;
	workspace: string;
}

function herdrEnv(): HerdrEnv {
	return {
		available:
			process.env.HERDR_ENV === "1" &&
			!!process.env.HERDR_SOCKET_PATH &&
			!!process.env.HERDR_BIN_PATH,
		bin: process.env.HERDR_BIN_PATH || "herdr",
		session: process.env.HERDR_SESSION || "default",
		workspace: process.env.HERDR_WORKSPACE_ID || "",
	};
}

function runHerdr(
	env: HerdrEnv,
	args: string[],
	timeoutMs = 15000,
): Promise<{ code: number | null; stdout: string; stderr: string }> {
	return new Promise((resolveResult) => {
		const child = spawn(env.bin, ["--session", env.session, ...args], {
			env: process.env,
		});
		let stdout = "";
		let stderr = "";
		child.stdout?.on("data", (d: Buffer) => (stdout += String(d)));
		child.stderr?.on("data", (d: Buffer) => (stderr += String(d)));
		child.on("error", (err: Error) =>
			resolveResult({ code: null, stdout, stderr: err.message }),
		);
		child.on("close", (code) => resolveResult({ code, stdout, stderr }));
		const timer = setTimeout(() => {
			child.kill("SIGKILL");
			resolveResult({ code: null, stdout, stderr: "herdr timed out" });
		}, timeoutMs);
		timer.unref?.();
	});
}

// Seat the editor in a fresh tab of the home workspace, labelled for the file
// and focused so it appears before the Allfather. The pane owns the editor;
// this hall keeps its TUI and its agent. Never blocks on the editor itself.
async function openInHerdrTab(
	ctx: ExtensionContext,
	env: HerdrEnv,
	editor: ResolvedEditor,
	absTarget: string,
	openCwd: boolean,
): Promise<void> {
	const label = openCwd
		? "ymir:edit"
		: `ymir:edit:${basename(absTarget).slice(0, 24)}`;
	const paneCwd = openCwd ? absTarget : dirname(absTarget);
	const editorTarget = openCwd ? "." : absTarget;

	const createArgs = [
		"tab",
		"create",
		"--cwd",
		paneCwd,
		"--label",
		label,
		"--focus",
	];
	if (env.workspace) {
		createArgs.push("--workspace", env.workspace);
	}

	const created = await runHerdr(env, createArgs);
	let tabId = "";
	let paneId = "";
	try {
		const doc = JSON.parse(created.stdout) as {
			result?: { tab?: { tab_id?: string }; root_pane?: { pane_id?: string } };
		};
		const r = doc.result ?? {};
		tabId = r.tab?.tab_id ?? "";
		paneId = r.root_pane?.pane_id ?? "";
	} catch {
		// parse failure falls through to the error branch below
	}
	if (!tabId || !paneId) {
		ctx.ui.notify(
			`herdr could not seat the editor tab: ${created.stderr || created.stdout || "unknown"}`,
			"error",
		);
		return;
	}

	// Record the seat so `bin/herdr-run.sh close-all` can clear it.
	try {
		// The seat record is runtime state in the OPERATOR'S HOME (Rule 04), never
		// the code tree when BROKK_HOME is unset — resolved like every shell tool.
		const state =
			process.env.BROKK_STATE_OVERRIDE || join(resolveYmirHome(), "state");
		mkdirSync(state, { recursive: true });
		appendFileSync(join(state, "herdr-seats"), `${tabId}\t${label}\n`);
	} catch {
		// bookkeeping is best-effort
	}

	// Fire the editor into the pane and return at once. `pane run` sends the
	// command line plus Enter; the pane's interactive shell owns it from there.
	const run = spawn(
		env.bin,
		[
			"--session",
			env.session,
			"pane",
			"run",
			paneId,
			editor.command,
			...editor.argv,
			editorTarget,
		],
		{ env: process.env, detached: true, stdio: "ignore" },
	);
	run.on("error", (err: Error) => {
		ctx.ui.notify(`Editor failed in herdr tab ${tabId}: ${err.message}`, "error");
	});
	run.unref();

	ctx.ui.notify(
		`Opened ${openCwd ? "cwd" : basename(absTarget)} in herdr tab ${tabId}`,
		"info",
	);
}

// ──────────────────────────────────────────────────────────────────────
// Open + picker
// ──────────────────────────────────────────────────────────────────────

async function openFile(ctx: ExtensionContext, relPath: string): Promise<void> {
	const absPath = resolve(ctx.cwd, relPath);
	let isDir = false;
	try {
		const s = statSync(absPath);
		if (s.isDirectory()) {
			isDir = true;
		} else if (!s.isFile()) {
			ctx.ui.notify(`Not a file or directory: ${relPath}`, "error");
			return;
		}
	} catch {
		ctx.ui.notify(`Path not found: ${relPath}`, "error");
		return;
	}
	const openCwd = relPath === "." || isDir;

	const editor = resolveEditor();

	// Inside Þjazi the editor keeps its own tab; this hall stays alive.
	const herdr = herdrEnv();
	if (herdr.available) {
		await openInHerdrTab(ctx, herdr, editor, absPath, openCwd);
		return;
	}

	if (editor.isGui) {
		try {
			const child = spawn(editor.command, [...editor.argv, absPath], {
				detached: true,
				stdio: "ignore",
				env: process.env,
				cwd: ctx.cwd,
			});
			child.on("error", (err) => {
				ctx.ui.notify(`Editor failed: ${err.message}`, "error");
			});
			child.unref();
			ctx.ui.notify(`Opened ${relPath || "."} in ${editor.command}`, "info");
		} catch (err) {
			const msg = err instanceof Error ? err.message : String(err);
			ctx.ui.notify(`Failed to launch ${editor.command}: ${msg}`, "error");
		}
		return;
	}

	// Terminal editor: suspend TUI, run blocking, resume.
	if (!ctx.hasUI) {
		ctx.ui.notify("Terminal editor requires an interactive TUI", "error");
		return;
	}

	const exitCode = await ctx.ui.custom<number | null>((tui, _theme, _kb, done) => {
		tui.stop();
		process.stdout.write("\x1b[2J\x1b[H");
		let status: number | null = null;
		let spawnError: Error | null = null;
		try {
			const result = spawnSync(editor.command, [...editor.argv, absPath], {
				stdio: "inherit",
				env: process.env,
				cwd: ctx.cwd,
			});
			if (result.error) spawnError = result.error;
			status = result.status;
		} catch (err) {
			spawnError = err instanceof Error ? err : new Error(String(err));
		}
		tui.start();
		tui.requestRender(true);
		if (spawnError) {
			// Surface after TUI comes back so the toast renders.
			queueMicrotask(() =>
				ctx.ui.notify(`Failed to launch ${editor.command}: ${spawnError!.message}`, "error"),
			);
		}
		done(status);
		return { render: () => [], invalidate: () => {} };
	});

	if (exitCode != null && exitCode !== 0) {
		ctx.ui.notify(`${editor.command} exited with code ${exitCode}`, "warning");
	}
}

async function pickAndOpen(pi: ExtensionAPI, ctx: ExtensionContext): Promise<void> {
	const files = await listFiles(pi, ctx.cwd);
	if (files.length === 0) {
		ctx.ui.notify("No files found in cwd", "warning");
		return;
	}
	const choice = await ctx.ui.select("Open file", files);
	if (!choice) return;
	await openFile(ctx, choice);
}

// ──────────────────────────────────────────────────────────────────────
// Extension entrypoint
// ──────────────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
	// Warm the file list cache on session start so the first tab-complete
	// and the first ctrl+e feel instant.
	pi.on("session_start", (_event, ctx) => {
		void listFiles(pi, ctx.cwd);
	});

	pi.registerCommand("edit", {
		description: "Open a file in $VISUAL/$EDITOR (no arg = picker)",
		getArgumentCompletions: (prefix: string): AutocompleteItem[] | null => {
			// Best-effort synchronous lookup; primes cache in background.
			// ctx.cwd not available here — fall back to process.cwd().
			const files = listFilesSync(pi, process.cwd());
			if (!files) return null;
			const matches = files.filter((f) => f.startsWith(prefix)).slice(0, MAX_COMPLETIONS);
			if (matches.length === 0) return null;
			return matches.map((value) => ({ value, label: value }));
		},
		handler: async (args, ctx) => {
			const target = (args ?? "").trim();
			// No arg: open cwd in the editor (like `nvim .` / `code .`).
			await openFile(ctx, target === "" ? "." : target);
		},
	});

	pi.registerShortcut("ctrl+shift+e", {
		description: "Open file in $VISUAL/$EDITOR",
		handler: async (ctx) => {
			await pickAndOpen(pi, ctx);
		},
	});
}
