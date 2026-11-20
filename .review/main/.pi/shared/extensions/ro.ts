// Brokk's home-persistent Pi transcript presentation toggle.
//
// Verified against Pi 0.81.1, 0.82.0, and 0.84.4, which expose built-in ToolDefinitions, per-slot
// renderers, renderShell: "self", session_start replacement reasons, agent_start and
// agent_settled, ExtensionUIContext.setToolsExpanded(), setWorkingVisible(), setWidget()
// with a disposable component smidja, and setHiddenThinkingLabel().
// ./lib/ro-working-ship.ts owns the animated working presentation this file
// installs. The focused tests pin those assumptions but never reject a
// newer Pi solely for its version. The collapsed-thinking and operational-user
// presentation adapters probe the exact API they patch and degrade independently with a
// diagnostic (see installCalmPresentationAdapter below) if a future Pi removes it; Pi
// still exposes no global renderer for arbitrary built-in or custom rows.
// docs/configuration.md owns the home-local Ró preference contract.
//
// Pi has one first-registration-wins ToolDefinition per tool name, with no merge or
// unregister operation. Keep Ró-off registration empty; keep Ró-on load-time
// registration synchronous because restored rows capture the registry before
// session_start; and collision-check only the later first-activation path, when
// getAllTools() is reliable. docs/ro-mode-feasibility.md owns the Pi-source evidence
// and docs/ro.md owns the user-facing behavior and non-retroactive first-toggle bound.
import { randomUUID } from "node:crypto";
import {
  mkdirSync,
  readFileSync,
  realpathSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type {
  ExtensionAPI,
  ExtensionUIContext,
  ToolDefinition,
  ToolInfo,
  ToolRenderResultOptions,
} from "@earendil-works/pi-coding-agent";
import {
  createBashToolDefinition,
  createEditToolDefinition,
  createFindToolDefinition,
  createGrepToolDefinition,
  createLsToolDefinition,
  createReadToolDefinition,
  createWriteToolDefinition,
} from "@earendil-works/pi-coding-agent";
import { Box, Container, getKeybindings, type Component } from "@earendil-works/pi-tui";
import type { TSchema } from "typebox";
import { installRoAssistantLayout } from "./lib/ro-assistant-layout.ts";
import { installRoOperationalUserLayout } from "./lib/ro-operational-user-layout.ts";
import {
  RO_WORKING_SHIP_WIDGET_KEY,
  createCalmWorkingShipAnimation,
  createCalmWorkingShipWidget,
} from "./lib/ro-working-ship.ts";
import {
  roPresentationHides,
  calmPresentationIsActive,
  RO_PRESENTATION_EVENT,
  registerBrokkSyntheticPresentation,
  setCalmPresentation,
  setCalmStockExportRendering,
} from "./lib/ro-visibility.ts";
import { resolveYmirRoot } from "./lib/ymir-home.ts";

type DefinitionFactory<TParams extends TSchema, TDetails, TState> = (
  cwd: string,
) => ToolDefinition<TParams, TDetails, TState>;

type RenderContext<TParams extends TSchema, TDetails, TState> = Parameters<
  NonNullable<ToolDefinition<TParams, TDetails, TState>["renderCall"]>
>[2];

type RenderArgs<TParams extends TSchema, TDetails, TState> = Parameters<
  NonNullable<ToolDefinition<TParams, TDetails, TState>["renderCall"]>
>[0];

type RenderTheme<TParams extends TSchema, TDetails, TState> = Parameters<
  NonNullable<ToolDefinition<TParams, TDetails, TState>["renderCall"]>
>[1];

type RenderResult<TParams extends TSchema, TDetails, TState> = Parameters<
  NonNullable<ToolDefinition<TParams, TDetails, TState>["renderResult"]>
>[0];

type StandardShellState = {
  shell?: Box;
  call?: Component;
  result?: Component;
};

const extensionFile = fileURLToPath(import.meta.url);
const extensionDir = dirname(extensionFile);
// The distro root comes from the deploy-time record (`.ymir-root`), never from
// walking up out of the deployed extension home. See lib/ymir-home.ts.
const root = resolveYmirRoot(extensionDir);

// Resolves symlinks before comparing tool-ownership identity below: sourceInfo.path
// values come from independent path-resolution code paths (this module's own
// import.meta.url vs. Pi's extension loader), and macOS alone symlinks /tmp and /var
// to /private/..., so lexical string comparison alone spuriously reads a symlinked
// self-path as a foreign one. Falls back to the raw path for synthetic, non-file
// sourceInfo paths such as "<builtin:read>" or "<inline>", which realpathSync rejects.
const realpathOrSelf = (path: string): string => {
  try {
    return realpathSync(path);
  } catch {
    return path;
  }
};
const extensionRealFile = realpathOrSelf(extensionFile);

// Each presentation adapter probes the exact Pi API it patches. If a future Pi removes
// that API, only the affected adapter degrades; the rest of Ró keeps working.
function installCalmPresentationAdapter(name: string, install: () => void): void {
  try {
    install();
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    console.error(`Brokk Ró: ${name} presentation adapter unavailable, skipping. ${reason}`);
  }
}

export default function (pi: ExtensionAPI) {
  installCalmPresentationAdapter("collapsed-thinking", installRoAssistantLayout);
  installCalmPresentationAdapter("operational-user-row", installRoOperationalUserLayout);

  let exportRendering = false;
  let removeTerminalInputHandler: (() => void) | undefined;
  // One logical agent run, tracked from agent_start through agent_settled rather than
  // from turns or tool calls, so the boat never flickers between tool calls, automatic
  // continuations, retries, or compaction that stay inside the same run.
  let agentRunActive = false;
  let workingShipShown = false;
  // One animation instance per extension lifetime. Hiding the working widget freezes
  // this state; the next working period resumes it. session_start resets it so a fresh
  // Pi session starts at the normal initial position. Never module-global.
  const workingShipAnimation = createCalmWorkingShipAnimation();

  // Single owner of Ró's working-row presentation choice. The widget is only created
  // or removed on a real transition, so repeated starts cannot duplicate its timer.
  const applyWorkingPresentation = (
    ui: ExtensionUIContext,
    forceStockVisibility = false,
  ): void => {
    const showShip = agentRunActive && calmPresentationIsActive();
    if (showShip !== workingShipShown) {
      workingShipShown = showShip;
      ui.setWidget(
        RO_WORKING_SHIP_WIDGET_KEY,
        showShip
          ? (tui) => createCalmWorkingShipWidget(tui, workingShipAnimation)
          : undefined,
      );
      ui.setWorkingVisible(!showShip);
    } else if (forceStockVisibility && !showShip) {
      ui.setWorkingVisible(true);
    }
  };

  const fmHome = process.env.BROKK_HOME || process.env.BROKK_ROOT_OVERRIDE || root;
  const configDirectory = process.env.BROKK_CONFIG_OVERRIDE || resolve(fmHome, "config");
  const stateDirectory = process.env.BROKK_STATE_OVERRIDE || resolve(fmHome, "state");
  // Ró is a PER-USER preference: it lives in the gitignored state dir so toggling
  // it never dirties the tracked tree, and YMIR_RO/BROKK_RO may set the default.
  // The legacy tracked `config/ro` is still read (upgrade path) but never written.
  const calmPreferencePath = resolve(stateDirectory, "ro");
  const legacyCalmPath = resolve(configDirectory, "ro");
  const truthy = (v: string): boolean => v === "on" || v === "max";
  const loadCalmPreference = (): boolean => {
    for (const p of [calmPreferencePath, legacyCalmPath]) {
      try {
        const stored = readFileSync(p, "utf8").trim();
        if (stored) return truthy(stored);
      } catch {
        /* try the next source */
      }
    }
    const env = (process.env.YMIR_RO || process.env.BROKK_RO || "").trim().toLowerCase();
    if (env === "on" || env === "max") return true;
    if (env === "off") return false;
    return false;
  };
  const persistCalmPreference = (active: boolean): void => {
    mkdirSync(dirname(calmPreferencePath), { recursive: true });
    const temporaryPath = `${calmPreferencePath}.${process.pid}.${randomUUID()}.tmp`;
    try {
      writeFileSync(temporaryPath, active ? "on\n" : "off\n", {
        encoding: "utf8",
        flag: "wx",
        mode: 0o600,
      });
      renameSync(temporaryPath, calmPreferencePath);
    } finally {
      rmSync(temporaryPath, { force: true });
    }
  };

  const publishPresentationState = (): void => {
    pi.events.emit(RO_PRESENTATION_EVENT, {
      active: calmPresentationIsActive(),
      stockExportRendering: exportRendering,
    });
  };

  registerBrokkSyntheticPresentation(pi);

  // Every on-screen tool row Ró currently presents, keyed by the row-local state Pi
  // hands its render slots, so Ró can repaint exactly those rows without touching
  // Pi's transcript. Pi can re-render a row at any time - the built-in edit row
  // invalidates itself once its diff is ready - so a row can be redrawn during the
  // window where /export forces stock rendering and keep that stock content
  // afterwards. Rows Pi's exporter renders are excluded: those use throwaway state
  // and never appear on screen. Cleared per session lifetime, which rebuilds the rows.
  const calmToolRowRepaints = new Map<object, () => void>();
  const rememberCalmToolRow = (state: object, invalidate: unknown): void => {
    if (exportRendering || typeof invalidate !== "function") return;
    calmToolRowRepaints.set(state, invalidate as () => void);
  };
  const repaintCalmToolRows = (): void => {
    for (const invalidate of calmToolRowRepaints.values()) invalidate();
  };

  function wrapBuiltIn<TParams extends TSchema, TDetails, TState>(
    smidja: DefinitionFactory<TParams, TDetails, TState>,
  ): ToolDefinition<TParams, TDetails, TState> {
    const definitions = new Map<string, ToolDefinition<TParams, TDetails, TState>>();
    const definitionFor = (cwd: string): ToolDefinition<TParams, TDetails, TState> => {
      let definition = definitions.get(cwd);
      if (!definition) {
        definition = smidja(cwd);
        definitions.set(cwd, definition);
      }
      return definition;
    };

    const original = definitionFor(process.cwd());
    const originalRenderCall = original.renderCall;
    const originalRenderResult = original.renderResult;
    const originalSelfShell = original.renderShell === "self";
    const standardShells = new WeakMap<object, StandardShellState>();

    if (!originalRenderCall || !originalRenderResult) {
      throw new Error(`Brokk ro mode requires both render slots for Pi built-in tool ${original.name}`);
    }

    const shellStateFor = (
      context: RenderContext<TParams, TDetails, TState>,
    ): StandardShellState => {
      const rowState = context.state as object;
      let shellState = standardShells.get(rowState);
      if (!shellState) {
        shellState = {};
        standardShells.set(rowState, shellState);
      }
      return shellState;
    };

    const refreshStandardShell = (
      state: StandardShellState,
      theme: RenderTheme<TParams, TDetails, TState>,
      context: RenderContext<TParams, TDetails, TState>,
    ): Box => {
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
    };

    return {
      ...original,
      renderShell: "self",

      async execute(toolCallId, params, signal, onUpdate, ctx) {
        return definitionFor(ctx.cwd).execute(toolCallId, params, signal, onUpdate, ctx);
      },

      renderCall(
        args: RenderArgs<TParams, TDetails, TState>,
        theme: RenderTheme<TParams, TDetails, TState>,
        context: RenderContext<TParams, TDetails, TState>,
      ) {
        rememberCalmToolRow(context.state as object, context.invalidate);
        if (exportRendering) return originalRenderCall(args, theme, context);
        if (roPresentationHides("assistant-tool-call")) return new Container();
        if (originalSelfShell) return originalRenderCall(args, theme, context);

        const state = shellStateFor(context);
        state.call = originalRenderCall(args, theme, {
          ...context,
          lastComponent: state.call,
        });
        return refreshStandardShell(state, theme, context);
      },

      renderResult(
        result: RenderResult<TParams, TDetails, TState>,
        options: ToolRenderResultOptions,
        theme: RenderTheme<TParams, TDetails, TState>,
        context: RenderContext<TParams, TDetails, TState>,
      ) {
        rememberCalmToolRow(context.state as object, context.invalidate);
        if (exportRendering) return originalRenderResult(result, options, theme, context);
        if (roPresentationHides("tool-result")) return new Container();
        if (originalSelfShell) return originalRenderResult(result, options, theme, context);

        const state = shellStateFor(context);
        state.result = originalRenderResult(result, options, theme, {
          ...context,
          lastComponent: state.result,
        });
        refreshStandardShell(state, theme, context);
        return new Container();
      },
    };
  }

  // Each wrapBuiltIn() call below has its own concrete TParams/TDetails/TState; the
  // array holding all seven has no single sound instantiation, so it is typed the same
  // way Pi's own ToolDefinition consumers erase this (any, any, any).
  const wrappedBuiltIns: ToolDefinition<any, any, any>[] = [
    wrapBuiltIn(createReadToolDefinition),
    wrapBuiltIn(createBashToolDefinition),
    wrapBuiltIn(createEditToolDefinition),
    wrapBuiltIn(createWriteToolDefinition),
    wrapBuiltIn(createGrepToolDefinition),
    wrapBuiltIn(createFindToolDefinition),
    wrapBuiltIn(createLsToolDefinition),
  ];

  // True once this extension has handled built-in registration for its lifetime:
  // either all seven synchronously at load, or only the uncontested subset during
  // first activation.
  let builtInsRegistered = false;

  // Gate on Ró already being on at load time. This must stay synchronous and
  // unconditional here (see file header): a foreign-claim check is not reachable at
  // this point, while deferral would make restored rows capture the wrong definition.
  // A Ró-off session or reload registers nothing and creates no collision exposure.
  if (loadCalmPreference()) {
    for (const tool of wrappedBuiltIns) pi.registerTool(tool);
    builtInsRegistered = true;
  }

  // Which of the 7 built-ins are currently owned by a different, non-builtin
  // extension. Only safe to call once every extension has finished loading (see file
  // header); never call this during the smidja's own synchronous execution above.
  function contestedBuiltIns(): ToolDefinition<any, any, any>[] {
    let registered: ToolInfo[];
    try {
      registered = pi.getAllTools();
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      console.error(`Brokk Ró: built-in ownership check unavailable, claiming every built-in unconditionally. ${reason}`);
      return [];
    }
    return wrappedBuiltIns.filter((tool) => {
      const owner = registered.find((info) => info.name === tool.name)?.sourceInfo;
      return owner !== undefined && owner.source !== "builtin" && realpathOrSelf(owner.path) !== extensionRealFile;
    });
  }

  // The first time Ró turns on in a session that started off, claim every
  // uncontested built-in and leave each contested tool and its owning extension
  // untouched. Tell the user which built-in Ró could not take over, since Ró's
  // presentation does not apply to it.
  function activateBuiltInsIfNeeded(ui: ExtensionUIContext): void {
    if (builtInsRegistered) return;
    const contested = contestedBuiltIns();
    const contestedNames = new Set(contested.map((tool) => tool.name));
    for (const tool of wrappedBuiltIns) {
      if (!contestedNames.has(tool.name)) pi.registerTool(tool);
    }
    builtInsRegistered = true;
    if (contested.length === 0) return;
    const names = contested.map((tool) => `"${tool.name}"`).join(", ");
    const plural = contested.length > 1;
    ui.notify(
      `Brokk Ró: the ${names} built-in tool${plural ? "s are" : " is"} already provided by another extension, so Ró may not fully function for ${plural ? "them" : "it"} this session.`,
      "warning",
    );
    for (const tool of contested) {
      console.error(`Brokk Ró: skipped claiming built-in "${tool.name}" because another extension already owns it.`);
    }
  }

  // Backstop for the one case activateBuiltInsIfNeeded cannot reach: Ró registered
  // unconditionally at load time because it was already on, without any chance to
  // check for a foreign claim first, so it can still silently lose a name to an
  // earlier-loaded extension. Runs on every session_start reason because a reload
  // rebuilds every extension's registrations from scratch, so last session's clean
  // bill of health does not carry over.
  function reportBuiltInLosses(): void {
    if (!builtInsRegistered) return;
    let registered: ToolInfo[];
    try {
      registered = pi.getAllTools();
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      console.error(`Brokk Ró: built-in ownership check unavailable. ${reason}`);
      return;
    }
    for (const tool of wrappedBuiltIns) {
      const owner = registered.find((info) => info.name === tool.name)?.sourceInfo;
      if (owner && owner.source !== "builtin" && realpathOrSelf(owner.path) !== extensionRealFile) {
        console.error(
          `Brokk Ró: another extension (${owner.path}) also claimed the built-in "${tool.name}" tool and won; Ró's presentation for it is unavailable this session.`,
        );
      }
    }
  }

  pi.on("session_start", (_event, ctx) => {
    reportBuiltInLosses();
    calmToolRowRepaints.clear();
    exportRendering = false;
    setCalmPresentation(loadCalmPreference());
    setCalmStockExportRendering(false);
    publishPresentationState();
    agentRunActive = false;
    workingShipShown = false;
    // A genuine new session lifetime starts the boat at the normal initial position.
    workingShipAnimation.reset();
    applyWorkingPresentation(ctx.ui, true);
    ctx.ui.setHiddenThinkingLabel(calmPresentationIsActive() ? "" : undefined);
    ctx.ui.setStatus("brokk-ro", undefined);
    removeTerminalInputHandler?.();
    removeTerminalInputHandler = ctx.ui.onTerminalInput((data) => {
      if (!getKeybindings().matches(data, "tui.input.submit")) return undefined;

      const input = ctx.ui.getEditorText().trim();
      if (
        input !== "/share" &&
        input !== "/export" &&
        !input.startsWith("/export ")
      ) {
        return undefined;
      }

      exportRendering = true;
      setCalmStockExportRendering(true);
      publishPresentationState();
      setTimeout(() => {
        exportRendering = false;
        setCalmStockExportRendering(false);
        publishPresentationState();
        // Repaint the rows Ró presents, never the whole transcript. Pi's export
        // prints "Session exported to: <path>" immediately before this runs, and
        // since Pi 0.83.0 setToolsExpanded() emits its own status line; consecutive
        // status lines coalesce, so a tools-expanded round-trip here silently
        // overwrote the confirmation and left the Allfather no record of where their
        // export landed. Invalidating the rows individually repaints the same
        // content with no status line of its own, and setStatus adds the redraw the
        // rows that consult Ró live in render(), such as operational user rows,
        // need without appending anything to the transcript.
        repaintCalmToolRows();
        ctx.ui.setStatus("brokk-ro", undefined);
      }, 0);
      return undefined;
    });
  });

  pi.on("agent_start", (_event, ctx) => {
    agentRunActive = true;
    applyWorkingPresentation(ctx.ui);
  });

  // agent_settled is emitted from a finally block, so it also covers abort and failure.
  pi.on("agent_settled", (_event, ctx) => {
    agentRunActive = false;
    applyWorkingPresentation(ctx.ui);
  });

  pi.on("session_shutdown", (_event, ctx) => {
    agentRunActive = false;
    applyWorkingPresentation(ctx.ui);
  });

  pi.registerCommand("ro", {
    description: "Toggle Brokk's supported conversation-only transcript presentation.",
    handler: async (_args, ctx) => {
      const active = !calmPresentationIsActive();
      persistCalmPreference(active);
      setCalmPresentation(active);
      if (active) activateBuiltInsIfNeeded(ctx.ui);
      publishPresentationState();
      applyWorkingPresentation(ctx.ui, true);
      // Pi re-runs every assistant row's layout from this call even when the label is
      // unchanged, which is what makes a toggle apply to rows already on screen.
      ctx.ui.setHiddenThinkingLabel(active ? "" : undefined);
      ctx.ui.setStatus("brokk-ro", undefined);

      const expanded = ctx.ui.getToolsExpanded();
      ctx.ui.setToolsExpanded(!expanded);
      ctx.ui.setToolsExpanded(expanded);
    },
  });
}
