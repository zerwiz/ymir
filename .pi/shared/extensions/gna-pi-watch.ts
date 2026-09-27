// Brokk primary watcher bridge for Pi.
//
// Session-generation ownership (stated once here):
// Pi emits session_shutdown for ordinary same-process replacements (/new, /resume,
// /fork, reload) as well as terminal quit. This extension binds one generation per
// session activation. Only the active live generation may start, stop, rearm, or
// clear the arm child. Replacement session_start (or a fresh smidja bind) activates
// a new live generation so monitoring can arm again without restarting Pi. Terminal
// quit leaves the final generation stopped so late callbacks cannot rearm. Stale
// callbacks from a prior generation are no-ops against the active replacement.
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, sep } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { Box, Container, Text, type Component } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import {
  createSkuldDispatchOffer,
  SKULD_BRANCH_DISPATCH_EVENT,
  scopeForSkuldWake,
} from "./lib/skuld-branch-dispatch.ts";
import {
  type RoPresentationState,
  roTranscriptClassIsVisible,
  RO_PRESENTATION_EVENT,
} from "./lib/ro-visibility.ts";
import { encodeRoddOperationalInput } from "./lib/rodd-operational-input.ts";
import { resolveYmirHome, resolveYmirRoot } from "./lib/ymir-home.ts";

type ArmResult = {
  ok: boolean;
  message: string;
};

type LockOwnership = "owned" | "missing" | "other";

type CloseClassification = {
  kind: "actionable" | "failure";
  message: string;
};

type WatchToolShellState = {
  shell?: Box;
  call?: Component;
  result?: Component;
};

type WatchToolRenderContext = {
  isError: boolean;
  isPartial: boolean;
};

type SessionGeneration = {
  id: number;
  stopping: boolean;
  child: ChildProcess | null;
  retryTimer: ReturnType<typeof setTimeout> | null;
  retryFailures: number;
  restoring: boolean;
  seq: number;
};

function refreshWatchToolShell(
  state: WatchToolShellState,
  theme: Theme,
  context: WatchToolRenderContext,
): Box {
  const background = context.isPartial
    ? (text: string) => theme.bg("toolPendingBg", text)
    : context.isError
      ? (text: string) => theme.bg("toolErrorBg", text)
      : (text: string) => theme.bg("toolSuccessBg", text);
  const shell = state.shell ?? new Box(1, 1, background);
  state.shell = shell;
  shell.setBgFn(background);
  shell.clear();
  if (state.call) shell.addChild(state.call);
  if (state.result) shell.addChild(state.result);
  return shell;
}

const extensionFile = fileURLToPath(import.meta.url);
const extensionDir = dirname(extensionFile);
// The distro root is recorded at deploy time (`.ymir-root`, written by
// bin/valknut-load.sh) and read back here: a deployed copy cannot find its own
// bin/ by walking up from ${HOME}/.pi/agent/extensions. See lib/ymir-home.ts.
const root = resolveYmirRoot(extensionDir);
const fmHome = process.env.BROKK_HOME || process.env.BROKK_ROOT_OVERRIDE || root;
const fmRoot = process.env.BROKK_ROOT_OVERRIDE || root;
// The runtime's records live in the OPERATOR'S HOME (Rule 04), and every shell
// tool resolves that through bin/hoard-lib.sh: $YMIR_HOME -> the recorded choice
// (~/.config/ymir/home) -> $HOME/Documents/ymirhome. The extension MUST resolve
// the same place. It once fell back to `${fmHome}/state` — the CODE TREE — while
// the Eindri handoff (bin/eindri-acclaim.sh) wrote $YMIR_STATE_DIR/.wake-queue in
// the hoard. Two queues: the handoff filled one, this watched the other, and no
// wake ever surfaced (2026-09-23). A seat still overrides via BROKK_STATE_OVERRIDE.
const ymirHome = resolveYmirHome();
const state = process.env.BROKK_STATE_OVERRIDE || `${ymirHome}/state`;
const config = process.env.BROKK_CONFIG_OVERRIDE || `${fmHome}/config`;
const armScript = `${fmRoot}/bin/syn-watch-arm.sh`;
const marker = `${state}/.pi-watch-extension-loaded`;
const extensionVersion = `sha256:${createHash("sha256").update(readFileSync(extensionFile)).digest("hex")}`;
const retryBaseMs = positiveInteger("BROKK_WATCH_REARM_RETRY_BASE_MS", 250);
const retryMaxMs = positiveInteger("BROKK_WATCH_REARM_RETRY_MAX_MS", 4000);
const retryLimit = positiveInteger("BROKK_WATCH_REARM_RETRY_LIMIT", 5);
// 35s on Windows so the budget stays above arm's MSYS confirm default (30s in
// bin/syn-watch-arm.sh): a slow but successful Git Bash cold start must not be
// SIGTERMed mid-confirmation. Conditioned on win32 so other platforms keep 12s.
const armReadyTimeoutMs = positiveInteger(
  "BROKK_PI_ARM_READY_TIMEOUT_MS",
  process.platform === "win32" ? 35000 : 12000,
);
const armRetireTimeoutMs = positiveInteger("BROKK_WATCH_ARM_RETIRE_TIMEOUT_MS", 1000);
const repairOnlyHint = "call gna_watch_arm again only after a later notification says the cycle is missing, failed, or unhealthy";
const shuttingDownMessage = "watcher: not armed - Pi session is shutting down";

let nextGenerationId = 0;
let activeGeneration: SessionGeneration | null = null;
const armReadiness = new WeakMap<ChildProcess, Promise<boolean>>();
const armClose = new WeakMap<ChildProcess, Promise<void>>();
const armRecovery = new WeakMap<ChildProcess, { generation: string; watcherPid: string }>();

function positiveInteger(name: string, fallback: number): number {
  const value = Number(process.env[name]);
  if (!Number.isFinite(value) || value <= 0) return fallback;
  return Math.floor(value);
}

function parentPid(pid: string): string {
  const result = spawnSync("ps", ["-o", "ppid=", "-p", pid], { encoding: "utf8" });
  if (result.status !== 0) return "";
  return result.stdout.trim();
}

// Liveness that actually sees death: process.kill(pid, 0) alone "succeeds" for
// a zombie (dead but unreaped) and for a recycled pid. /proc/<pid>/stat resolves
// both — the state character (field 3: Z = zombie, X = dead) and the process
// starttime (field 22), which is stable for a pid's whole life. A mismatch with
// the starttime recorded at acquire means the original holder is gone and the
// kernel handed the pid to an unrelated process.
function procStatParts(pid: string): string[] | null {
  if (!/^[0-9]+$/.test(pid) || pid === "1") return null;
  try {
    const stat = readFileSync(`/proc/${pid}/stat`, "utf8");
    const close = stat.lastIndexOf(")");
    if (close < 0) return null;
    const parts = stat.slice(close + 2).trim().split(/\s+/);
    return parts[0] === "" ? parts.slice(1) : parts;
  } catch {
    return null;
  }
}

function procStarttime(pid: string): string {
  const parts = procStatParts(pid);
  // Field 22 sits at index 19 after the comm field (remaining fields start at 3).
  return parts && parts.length > 19 ? parts[19] : "";
}

function pidAlive(pid: string, starttime = ""): boolean {
  const parts = procStatParts(pid);
  if (parts) {
    if (parts[0] === "Z" || parts[0] === "X") return false;
    if (starttime) {
      const current = parts.length > 19 ? parts[19] : "";
      if (current && current !== starttime) return false;
    }
  }
  try {
    process.kill(Number(pid), 0);
    return true;
  } catch {
    return false;
  }
}

// The machine-global state dir — the primary's lock lives here, never in the
// tree (mirrors gleipnir_machine_state_dir in bin/gleipnir-lock-lib.sh).
function machineStateDir(): string {
  const env = process.env.BROKK_MACHINE_STATE_DIR;
  if (env) return env;
  const xdg = process.env.XDG_STATE_HOME;
  const base = xdg && xdg.trim() ? xdg : `${process.env.HOME || root}/.local/state`;
  return `${base}/ymir`;
}

// A seat (Eindri-home) keeps a per-home lock; the primary's lock is machine-global.
function isSeatHome(): boolean {
  return Boolean(process.env.BROKK_STATE_OVERRIDE) || process.env.BROKK_HOME_KIND === "eindri";
}

function derivedLockPath(): string {
  return isSeatHome() ? `${state}/.lock` : `${machineStateDir()}/brokk.lock`;
}

// A synced pointer may name another user's home — a box reinstalled under a new
// username (heimdallomarchy -> heimdall) carries the old pointer in $YMIR_HOME,
// which syncs between machines. A path that does not live under the current
// user's home cannot be this machine's lock, so it is stale by definition and
// must never be trusted: it once made the arm mkdir a foreign home and fail with
// EACCES, stranding supervision (2026-09-23).
function pointerIsCurrentMachine(path: string): boolean {
  if (!path || !isAbsolute(path)) return false;
  const home = process.env.HOME || process.env.USERPROFILE || "";
  if (!home) return path === derivedLockPath();
  const prefix = home.endsWith(sep) ? home : `${home}${sep}`;
  return path === home || path.startsWith(prefix);
}

// Rewrite a stale pointer so the next reader (and the shell tools) see the truth.
function healLockPointer(path: string): void {
  try {
    mkdirSync(state, { recursive: true });
    writeFileSync(`${state}/.lock-path`, `${path}\n`);
  } catch {
    // best-effort: a read-only home still resolves correctly below
  }
}

// The resolved session-lock path. The primary holds a machine-global lock; an
// Eindri-home holds a per-home one. gleipnir-lock-lib.sh records whichever it
// resolved in state/.lock-path, but a pointer carried in from another machine is
// validated against the current home before it is trusted; a stale one is healed
// to the path this machine derives.
function resolvedLockPath(): string {
  let pointer = "";
  try {
    pointer = readFileSync(`${state}/.lock-path`, "utf8").trim();
  } catch {
    // no pointer yet — pre-machine-lock session
  }
  if (pointer && pointerIsCurrentMachine(pointer)) return pointer;
  const derived = derivedLockPath();
  if (pointer) healLockPointer(derived);
  return derived;
}

// The opt-in gate (plan 58 Phase 0c). The extensions deploy GLOBALLY, so every
// `pi` session on this machine loads them and resolves the SAME machine lock. A
// session that was never SEATED here (no saga-session-start) must never reclaim
// or delete that lock. The seat marker records the pid the lock was acquired for
// and ownership is proven by ancestry, so an unrelated session stands down.
function isSeatedSession(): boolean {
  let seated = "";
  try {
    seated = readFileSync(`${state}/.seated`, "utf8").trim();
  } catch {
    return false;
  }
  if (!/^[0-9]+$/.test(seated)) return false;
  let pid = String(process.pid);
  for (let i = 0; i < 8; i += 1) {
    if (pid === seated) return true;
    pid = parentPid(pid);
    if (!pid || pid === "1") break;
  }
  return false;
}

function lockOwnership(): LockOwnership {
  const lockPath = resolvedLockPath();
  let lockPid = "";
  try {
    lockPid = readFileSync(lockPath, "utf8").trim();
  } catch {
    return "missing";
  }
  // An empty lock carries no verifiably-live holder — a vacant helm, not
  // another session's. Classify it missing so the reclaim takes the helm in
  // place; a truncated/empty lock must never strand supervision or punt to a
  // manual session start.
  if (!lockPid) return "missing";
  if (!/^[0-9]+$/.test(lockPid) || lockPid === "1") return "other";
  let pid = String(process.pid);
  for (let i = 0; i < 8; i += 1) {
    if (pid === lockPid) return "owned";
    pid = parentPid(pid);
    if (!pid || pid === "1") break;
  }
  let recordedStarttime = "";
  try {
    recordedStarttime = readFileSync(`${lockPath}.starttime`, "utf8").trim();
  } catch {
    // lock predates the starttime sidecar — liveness falls back to the
    // state/zombie check and kill(0)
  }
  // pidAlive rejects zombies and recycled pids, so "missing" truly means the
  // recorded holder is verifiably gone — never a live "other" session.
  return pidAlive(lockPid, recordedStarttime) ? "other" : "missing";
}

// A stale lock (owner dead / zombie / pid reused) is cleared and the helm is
// taken directly, so a leftover lock can never strand supervision. This mirrors
// gleipnir_lock_acquire in bin/gleipnir-lock-lib.sh (pid + starttime sidecar +
// state/.lock-path pointer; the legacy state/.lock is dropped).
function reclaimStaleLock(lockPath: string): void {
  mkdirSync(dirname(lockPath), { recursive: true });
  writeFileSync(lockPath, `${process.pid}\n`);
  const starttime = procStarttime(String(process.pid));
  if (starttime) writeFileSync(`${lockPath}.starttime`, `${starttime}\n`);
  const legacyPath = `${state}/.lock`;
  if (legacyPath !== lockPath) {
    try {
      const legacyOwner = readFileSync(legacyPath, "utf8").trim();
      if (legacyOwner === String(process.pid) || !pidAlive(legacyOwner)) {
        rmSync(legacyPath, { force: true });
      }
    } catch {
      // no legacy lock to clear
    }
  }
  writeFileSync(`${state}/.lock-path`, `${lockPath}\n`);
}

// On real process exit (never on in-process /new resets, which reuse the same
// pid and keep the lock), drop the lock this session owns so a dying or killed
// agent cannot leave the helm for everyone after it. A hard kill that skips
// this hook is covered by the next session's reap (zombie/pid-reuse aware).
function releaseLockIfOwned(): void {
  if (lockOwnership() !== "owned") return;
  const lockPath = resolvedLockPath();
  try {
    rmSync(lockPath, { force: true });
    rmSync(`${lockPath}.starttime`, { force: true });
  } catch {
    // best-effort: the next session's reap covers a leftover lock
  }
}

function markLoaded(): void {
  if (lockOwnership() === "other") return;
  mkdirSync(state, { recursive: true });
  writeFileSync(marker, `${extensionVersion}\n${process.pid}\n`);
}

function actionableLine(output: string): string {
  const lines = output.split(/\r?\n/);
  return lines.find((line) => /^(signal:|stale:|check:|heartbeat($|:))/.test(line)) || "";
}

function classifyClose(stdout: string, stderr: string, code: number | null, signal: NodeJS.Signals | null): CloseClassification {
  const combined = `${stdout}\n${stderr}`.trim();
  const reason = actionableLine(combined);
  if (reason) return { kind: "actionable", message: reason };
  const healthy = combined.split(/\r?\n/).find((line) => /^watcher: healthy\b/.test(line));
  if (healthy) {
    return {
      kind: "failure",
      message: `watcher: FAILED - Pi extension arm child found an external healthy watcher instead of owning wake delivery\n${healthy}`,
    };
  }
  const failed = combined.split(/\r?\n/).find((line) => /^watcher: FAILED/.test(line));
  if (failed) return { kind: "failure", message: failed };
  if (signal) {
    return {
      kind: "failure",
      message: `watcher: FAILED - Pi extension arm child ended from ${signal}${combined ? `\n${combined}` : ""}`,
    };
  }
  if (code && code !== 0) {
    return {
      kind: "failure",
      message: `watcher: FAILED - syn-watch-arm.sh exited ${code}${combined ? `\n${combined}` : ""}`,
    };
  }
  return {
    kind: "failure",
    message: "watcher: FAILED - Pi extension arm cycle ended without an actionable reason",
  };
}

function createGeneration(): SessionGeneration {
  return {
    id: ++nextGenerationId,
    stopping: false,
    child: null,
    retryTimer: null,
    retryFailures: 0,
    restoring: false,
    seq: 0,
  };
}

function activateGeneration(generation: SessionGeneration): void {
  activeGeneration = generation;
}

function generationIsLive(generation: SessionGeneration): boolean {
  return activeGeneration === generation && !generation.stopping;
}

function stopGeneration(generation: SessionGeneration): void {
  generation.stopping = true;
  if (generation.retryTimer) clearTimeout(generation.retryTimer);
  generation.retryTimer = null;
  if (generation.child) generation.child.kill("SIGTERM");
  generation.child = null;
}

const cleanupOnProcessExit = () => {
  if (activeGeneration) stopGeneration(activeGeneration);
  releaseLockIfOwned();
};
process.once("exit", cleanupOnProcessExit);

export default function (pi: ExtensionAPI) {
  let generation = createGeneration();
  activateGeneration(generation);

  let calmPresentation: RoPresentationState = {
    active: false,
    stockExportRendering: false,
  };
  pi.events?.on?.(RO_PRESENTATION_EVENT, (data) => {
    const next = data as Partial<RoPresentationState>;
    calmPresentation = {
      active: next.active === true,
      stockExportRendering: next.stockExportRendering === true,
    };
  });
  const calmHides = (itemClass: Parameters<typeof roTranscriptClassIsVisible>[0]): boolean =>
    calmPresentation.active &&
    !calmPresentation.stockExportRendering &&
    !roTranscriptClassIsVisible(itemClass);

  let lastWatcherWake = "";

  function queueHasFreshContent(): boolean {
    // A wake is fresh only while one of the durable doors still carries a line;
    // with both empty, a repeated identical wake is an echo of one already
    // drained (the loud-stretch flood came from exactly this re-presentation).
    for (const p of [`${state}/.wake-queue`, `${fmHome}/.agents/state/.wake-queue`]) {
      try {
        if (readFileSync(p, "utf8").trim().length > 0) return true;
      } catch {
        // absent queue reads as empty
      }
    }
    return false;
  }

  async function sendWake(
    owner: SessionGeneration,
    message: string,
  ): Promise<void> {
    if (!generationIsLive(owner)) return;
    // Deliver an identical wake at most once per drained state: a repeat with
    // no fresh queue content is the same news the primary already handled, and
    // re-sending it floods the follow-up queue one-per-prompt.
    if (message === lastWatcherWake && !queueHasFreshContent()) return;
    lastWatcherWake = message;
    const content = encodeRoddOperationalInput(
      "watcher",
      `BROKK WATCHER WAKE: ${message}\n\nRun bin/saga-wake-drain.sh first and handle the queued wake. Watcher continuity is extension-owned.`,
    );
    await pi.sendUserMessage(content, { deliverAs: "followUp" });
  }

  function confirmHandlingDelivery(recovery: { generation: string; watcherPid: string }): {
    ok: boolean;
    detail: string;
  } {
    try {
      const result = spawnSync(
        "bash",
        [armScript, "--handling-delivered", recovery.generation, "--watcher-pid", recovery.watcherPid],
        {
          cwd: fmRoot,
          encoding: "utf8",
          env: { ...process.env, BROKK_HOME: fmHome, BROKK_STATE_OVERRIDE: state, BROKK_ROOT_OVERRIDE: fmRoot },
        },
      );
      if (result.status === 0) return { ok: true, detail: "" };
      const stderr = (result.stderr || "").trim();
      return {
        ok: false,
        detail: `watcher: FAILED - handling delivery confirmation was rejected (status=${result.status ?? "none"} generation=${recovery.generation} watcherPid=${recovery.watcherPid})${stderr ? `\n${stderr}` : ""}`,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        ok: false,
        detail: `watcher: FAILED - handling delivery confirmation could not be executed (generation=${recovery.generation} watcherPid=${recovery.watcherPid})\n${message}`,
      };
    }
  }

  function confirmHandlingDeliveryWithRetry(
    owner: SessionGeneration,
    recovery: { generation: string; watcherPid: string },
  ): { ok: boolean; detail: string } {
    const snapshot = (): { generation: string; watcherPid: string } => {
      const current = owner.child ? armRecovery.get(owner.child) : undefined;
      return current ?? recovery;
    };
    const first = confirmHandlingDelivery(snapshot());
    if (first.ok) return first;
    return confirmHandlingDelivery(snapshot());
  }

  function offerWakeToBranch(message: string): boolean {
    const heartbeat = /^heartbeat($|:)/.test(message);
    // A check-kind close (merge-confirmation polls, Relay mentions,
    // credential/auth failures, and every other legitimately main-only
    // class - docs/pi-supervision-branch.md) is never routed to the branch
    // even when other currently-unread rows are individually eligible: this
    // watcher cycle's own triggering event stays on main, exactly as before
    // scopeForSkuldWake stopped letting a co-present check row veto the
    // whole scan. That relaxation is what lets an UNRELATED eligible
    // signal/stale row still reach the branch on this cycle; it must never
    // also let a check-kind trigger itself slip past main's delivery.
    const isCheckTrigger = /^check:/.test(message);
    const scope = scopeForSkuldWake(state, heartbeat);
    const eligible = !isCheckTrigger && scope.eligible;
    const offer = createSkuldDispatchOffer(message, scope.projects, heartbeat, eligible);
    pi.events?.emit?.(SKULD_BRANCH_DISPATCH_EVENT, offer);
    return offer.accepted;
  }

  async function deliverActionableWake(
    owner: SessionGeneration,
    message: string,
    repairFailed: boolean,
    recovery?: { generation: string; watcherPid: string },
  ): Promise<void> {
    if (!generationIsLive(owner)) return;
    if (recovery) {
      const confirmed = confirmHandlingDeliveryWithRetry(owner, recovery);
      if (!confirmed.ok) {
        const watcherPid = recovery.watcherPid;
        if (!pidAlive(watcherPid)) {
          await retireArm(owner.child);
        }
        await sendWake(owner, `${message}\n\n${confirmed.detail}`);
        return;
      }
    }
    if (!repairFailed && offerWakeToBranch(message)) return;
    await sendWake(owner, message);
  }

  function surfaceFailure(owner: SessionGeneration, message: string): void {
    void sendWake(owner, message).catch(() => {
      // Pi owns delivery errors; continuity restoration never waits on prompting.
    });
  }

  function retryDelay(attempt: number): number {
    return Math.min(retryMaxMs, retryBaseMs * 2 ** Math.max(0, attempt - 1));
  }

  function waitForRetry(attempt: number): Promise<void> {
    return new Promise((resolveRetry) => {
      const timer = setTimeout(resolveRetry, retryDelay(attempt));
      timer.unref();
    });
  }

  function waitForReadiness(armChild: ChildProcess): Promise<boolean> {
    const readiness = armReadiness.get(armChild);
    if (!readiness) return Promise.resolve(false);
    return new Promise((resolveReady) => {
      const timer = setTimeout(() => resolveReady(false), armReadyTimeoutMs);
      timer.unref();
      void readiness.then((ready) => {
        clearTimeout(timer);
        resolveReady(ready);
      });
    });
  }

  async function retireArm(armChild: ChildProcess | null): Promise<boolean> {
    if (!armChild) return true;
    armChild.kill("SIGTERM");
    const closed = armClose.get(armChild);
    if (!closed) return false;
    return new Promise((resolveRetired) => {
      const timer = setTimeout(() => resolveRetired(false), armRetireTimeoutMs);
      timer.unref();
      void closed.then(() => {
        clearTimeout(timer);
        resolveRetired(true);
      });
    });
  }

  async function restoreAfterActionableClose(owner: SessionGeneration, predecessorArmPid: string): Promise<{
    failure: string;
    recovery?: { generation: string; watcherPid: string };
  }> {
    let failure = "";
    for (let attempt = 0; attempt <= retryLimit; attempt += 1) {
      if (!generationIsLive(owner)) return { failure: "" };
      const replacement = startArm(owner, predecessorArmPid);
      const successorChild = owner.child;
      if (replacement.ok && successorChild && await waitForReadiness(successorChild)) {
        return { failure: "", recovery: armRecovery.get(successorChild) };
      }
      if (replacement.ok) {
        failure = "watcher: FAILED - Pi extension could not verify a ready successor watcher";
        if (!(await retireArm(successorChild))) {
          return {
            failure: `${failure}\nwatcher: FAILED - Pi extension could not restore watcher continuity because the unready successor arm did not exit within ${armRetireTimeoutMs}ms`,
          };
        }
      } else {
        failure = /(?:read-only|no live session)/.test(replacement.message)
          ? `watcher: FAILED - Pi extension cannot restore continuity because this session no longer owns the lock\n${replacement.message}`
          : `watcher: FAILED - Pi extension could not start the successor watcher cycle\n${replacement.message}`;
        if (/(?:read-only|no live session)/.test(replacement.message)) break;
      }
      if (attempt === retryLimit) break;
      await waitForRetry(attempt + 1);
    }
    return { failure: `${failure}\nwatcher: FAILED - Pi extension could not restore watcher continuity after ${retryLimit} retries` };
  }

  function scheduleRetry(owner: SessionGeneration, message: string, predecessorArmPid: string): void {
    if (!generationIsLive(owner) || owner.child || owner.retryTimer) return;
    const ownership = lockOwnership();
    if (ownership !== "owned") {
      surfaceFailure(owner, `watcher: FAILED - Pi extension cannot restore continuity because this session no longer owns the lock\n${message}`);
      return;
    }
    owner.retryFailures += 1;
    if (owner.retryFailures > retryLimit) {
      surfaceFailure(owner, `watcher: FAILED - Pi extension could not restore watcher continuity after ${retryLimit} retries\n${message}`);
      return;
    }
    const timer = setTimeout(() => {
      if (owner.retryTimer === timer) owner.retryTimer = null;
      if (!generationIsLive(owner)) return;
      const result = startArm(owner, predecessorArmPid);
      if (!result.ok) {
        surfaceFailure(owner, `watcher: FAILED - Pi extension could not launch a continuity retry\n${result.message}`);
      }
    }, retryDelay(owner.retryFailures));
    timer.unref();
    owner.retryTimer = timer;
  }

  function startArm(owner: SessionGeneration, predecessorArmPid = ""): ArmResult {
    if (!generationIsLive(owner)) return { ok: false, message: shuttingDownMessage };
    const ownership = lockOwnership();
    if (ownership === "other") return { ok: false, message: "watcher: read-only - session lock is held by another brokk session" };
    if (ownership === "missing") {
      // No verifiably-live holder: the recorded owner is dead, a zombie, or a
      // recycled pid. Only a session SEATED here may reclaim the helm — an
      // unrelated `pi` (the extensions are global) must stand down, never take
      // or delete a lock that is not its own (plan 58 Phase 0c).
      if (!isSeatedSession()) {
        return { ok: false, message: "watcher: stood down - this session was not seated here (no seat marker); not reclaiming the machine lock" };
      }
      reclaimStaleLock(resolvedLockPath());
      return startArm(owner, predecessorArmPid);
    }
    markLoaded();
    if (owner.child) {
      return {
        ok: true,
        message: `watcher: unchanged - Pi extension already owns an arm child; no manual re-arm needed; ${repairOnlyHint}`,
      };
    }
    if (owner.retryTimer) {
      return {
        ok: true,
        message: `watcher: unchanged - Pi extension already owns a scheduled continuity retry; no manual re-arm needed; ${repairOnlyHint}`,
      };
    }
    const id = ++owner.seq;
    const env = {
      ...process.env,
      BROKK_HOME: fmHome,
      BROKK_ROOT_OVERRIDE: fmRoot,
      BROKK_CONFIG_OVERRIDE: config,
      BROKK_WATCH_ARM_SCRIPT: armScript,
      BROKK_WATCH_PREDECESSOR_ARM_PID: predecessorArmPid,
      BROKK_SESSION_PID: String(process.pid),
    };
    const armChild = spawn("bash", ["-lc", "config_dir=\"${BROKK_CONFIG_OVERRIDE:-$BROKK_HOME/config}\"; [ -f \"$config_dir/x-mode.env\" ] && . \"$config_dir/x-mode.env\"; exec \"$BROKK_WATCH_ARM_SCRIPT\" --restart"], {
      cwd: fmRoot,
      env,
      stdio: ["ignore", "pipe", "pipe"],
    });
    owner.child = armChild;
    let stdout = "";
    let stderr = "";
    let settled = false;
    let readinessSettled = false;
    let resolveReadiness: (ready: boolean) => void = () => {};
    let resolveClosed: () => void = () => {};
    const readiness = new Promise<boolean>((resolveReady) => {
      resolveReadiness = resolveReady;
    });
    armReadiness.set(armChild, readiness);
    const closed = new Promise<void>((resolveClosedChild) => {
      resolveClosed = resolveClosedChild;
    });
    armClose.set(armChild, closed);
    const settleReadiness = (ready: boolean): void => {
      if (readinessSettled) return;
      readinessSettled = true;
      resolveReadiness(ready);
    };
    const observeEstablishedArm = (): void => {
      const combined = `${stdout}\n${stderr}`;
      const recovery = combined.match(/^watcher: started pid=([0-9]+).* recovery-generation=([A-Za-z0-9._-]+)$/m);
      if (recovery) armRecovery.set(armChild, { watcherPid: recovery[1], generation: recovery[2] });
      if (/^watcher: (?:started|attached)\b/m.test(combined)) {
        settleReadiness(true);
      }
    };
    const releaseChild = (): void => {
      if (owner.child === armChild) owner.child = null;
    };
    armChild.stdout.on("data", (chunk: Buffer) => {
      stdout += chunk.toString();
      observeEstablishedArm();
    });
    armChild.stderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString();
      observeEstablishedArm();
    });
    armChild.on("close", (code: number | null, signal: NodeJS.Signals | null) => {
      if (settled) return;
      settled = true;
      resolveClosed();
      settleReadiness(false);
      releaseChild();
      if (!generationIsLive(owner)) return;
      const classification = classifyClose(stdout, stderr, code, signal);
      const predecessor = String(armChild.pid ?? "");
      if (classification.kind === "actionable") {
        if (owner.restoring) return;
        owner.retryFailures = 0;
        owner.restoring = true;
        void (async () => {
          try {
            const restoration = await restoreAfterActionableClose(owner, predecessor);
            if (!generationIsLive(owner)) return;
            const message = restoration.failure ? `${classification.message}\n\n${restoration.failure}` : classification.message;
            await deliverActionableWake(owner, message, Boolean(restoration.failure), restoration.recovery);
          } catch (error) {
            const detail = error instanceof Error ? error.message : String(error);
            surfaceFailure(owner, `watcher: FAILED - Pi extension could not deliver an actionable wake\n${detail}`);
          } finally {
            if (generationIsLive(owner)) owner.restoring = false;
          }
        })();
        return;
      }
      if (owner.restoring) return;
      scheduleRetry(owner, classification.message, predecessor);
    });
    armChild.on("error", (error: Error) => {
      if (settled) return;
      settled = true;
      resolveClosed();
      settleReadiness(false);
      releaseChild();
      if (!generationIsLive(owner)) return;
      if (owner.restoring) return;
      scheduleRetry(owner, `watcher: FAILED - Pi extension arm child ${id} failed: ${error.message}`, String(armChild.pid ?? ""));
    });
    return {
      ok: true,
      message: `watcher: started Pi extension arm child ${id}; future ordinary re-arms are automatic; ${repairOnlyHint}`,
    };
  }

  pi.on?.("session_start", () => {
    if (generation.stopping) generation = createGeneration();
    activateGeneration(generation);
    markLoaded();
  });
  pi.on?.("session_shutdown", () => {
    stopGeneration(generation);
  });

  pi.registerCommand?.("gna-watch-arm", {
    description: "Arm brokk watcher supervision through the Pi extension instead of foreground bash.",
    handler: async (_args, ctx) => {
      const result = startArm(generation);
      ctx.ui.notify(result.message, result.ok ? "info" : "warning");
    },
  });

  pi.registerTool?.({
    name: "gna_watch_arm",
    label: "Arm brokk watcher",
    description: "Start the first required Pi watcher cycle, or repair one only after a notification says the cycle is missing, failed, or unhealthy. Do not call after ordinary work or ordinary notifications; the Pi extension re-arms automatically. Never run bin/syn-watch-arm.sh through bash.",
    promptSnippet: "Start the first required Pi watcher cycle or repair a cycle reported missing, failed, or unhealthy; ordinary re-arming is automatic.",
    promptGuidelines: [
      "Call gna_watch_arm only for the first required cycle or after a notification says the cycle is missing, failed, or unhealthy. Do not call it after ordinary work, turn completion, or ordinary signal, stale, check, or heartbeat handling because the Pi extension owns re-arming. Never run bin/syn-watch-arm.sh through bash.",
    ],
    parameters: Type.Object({}),
    renderShell: "self",
    renderCall: (_args, theme, context) => {
      if (calmHides("assistant-tool-call")) return new Container();
      if (calmPresentation.stockExportRendering) {
        return new Text(theme.fg("toolTitle", theme.bold("gna_watch_arm")), 0, 0);
      }
      const state = context.state as WatchToolShellState;
      state.call = new Text(theme.fg("toolTitle", theme.bold("gna_watch_arm")), 0, 0);
      return refreshWatchToolShell(state, theme, context);
    },
    renderResult: (result, _options, theme, context) => {
      if (calmHides("tool-result")) return new Container();
      const output = result.content
        .filter((item) => item.type === "text")
        .map((item) => item.text)
        .join("\n");
      if (calmPresentation.stockExportRendering) {
        return new Text(theme.fg("toolOutput", output), 0, 0);
      }
      const state = context.state as WatchToolShellState;
      state.result = output
        ? new Text(theme.fg("toolOutput", output), 0, 0)
        : new Container();
      refreshWatchToolShell(state, theme, context);
      return new Container();
    },
    execute: async () => {
      const result = startArm(generation);
      return {
        content: [{ type: "text", text: result.message }],
        details: result,
      };
    },
  });

  markLoaded();
}
