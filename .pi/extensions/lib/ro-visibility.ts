import {
  getMarkdownTheme,
  type ExtensionAPI,
  UserMessageComponent,
} from "@earendil-works/pi-coding-agent";
export const RO_TRANSCRIPT_CLASSES = [
  "genuine-user-prompt",
  "genuine-agent-response",
  "assistant-working-note",
  "assistant-thinking",
  "assistant-tool-call",
  "tool-result",
  "tool-image",
  "user-bash",
  "skill-invocation",
  "custom-message",
  "custom-entry",
  "compaction-summary",
  "branch-summary",
  "working-status",
  "command-status",
  "system-notice",
  "cache-notice",
  "project-trust-warning",
  "synthetic-user",
  "synthetic-assistant",
  "unknown",
] as const;

export type CalmTranscriptClass = (typeof RO_TRANSCRIPT_CLASSES)[number];

// Ró is on or off. "assistant-working-note" is deliberately absent from the allowlist:
// Ró hides mid-turn assistant working notes, keeping the genuine final reply.
const CALM_VISIBLE_CLASSES = new Set<CalmTranscriptClass>([
  "genuine-user-prompt",
  "genuine-agent-response",
  "working-status",
]);

// Legacy session entries from Ró versions before 2026-07-23 retain this
// presentation type. New operational input stays user-role and is never rerouted.
export const RO_SYNTHETIC_PRESENTATION_TYPE = "brokk-synthetic-input-presentation";
export const RO_PRESENTATION_EVENT = "brokk:ro-presentation";

export type RoPresentationState = {
  active: boolean;
  stockExportRendering: boolean;
};

export const RO_SYNTHETIC_KINDS = [
  "session-start",
  "watcher",
  "turn-end-guard",
  "away-supervisor",
  "from-brokk",
  "launch-brief",
  "legacy-operational",
] as const;

export type BrokkSyntheticKind = (typeof RO_SYNTHETIC_KINDS)[number];
type BrokkSyntheticPresentation = {
  content: string;
  kind: BrokkSyntheticKind;
};

let ro = false;
let stockExportRendering = false;

export function roTranscriptClassIsVisible(itemClass: CalmTranscriptClass): boolean {
  return CALM_VISIBLE_CLASSES.has(itemClass);
}

export function setCalmPresentation(active: boolean): void {
  ro = active;
}

export function setCalmStockExportRendering(active: boolean): void {
  stockExportRendering = active;
}

export function calmPresentationIsActive(): boolean {
  return ro;
}

export function roPresentationHides(itemClass: CalmTranscriptClass): boolean {
  return ro && !stockExportRendering && !roTranscriptClassIsVisible(itemClass);
}

export function registerBrokkSyntheticPresentation(pi: ExtensionAPI): void {
  pi.registerEntryRenderer<BrokkSyntheticPresentation>(
    RO_SYNTHETIC_PRESENTATION_TYPE,
    (entry) => {
      if (roPresentationHides("synthetic-user")) return undefined;
      const data = entry.data;
      if (!data || typeof data.content !== "string") return undefined;
      return new UserMessageComponent(data.content, getMarkdownTheme());
    },
  );
}
