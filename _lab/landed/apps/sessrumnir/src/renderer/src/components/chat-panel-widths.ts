/**
 * Width math for the chat view's side panel.
 *
 * Extracted so the drag handlers and the render both read one set of bounds. They
 * previously disagreed: the file-tree drag clamped to a standalone literal while
 * the render clamped to a ceiling derived from the layout, so dragging pushed the
 * state past what was drawn. The pane looked stuck, and a drag back did nothing
 * until the invisible state re-entered range.
 */

/**
 * The editor and image panes carry this as a CSS min-width, so the file pane
 * beside them may not grow past `sidePanel - MIN_EDITOR_PANE_WIDTH` without
 * squeezing them out. One constant, so the reservation and the subtraction cannot
 * drift apart.
 */
export const MIN_EDITOR_PANE_WIDTH = 360

export const MIN_FILE_PANE_WIDTH = 220
export const MIN_SIDE_PANEL_WIDTH = 360
/** A file tree beside an editor needs room for both at once. */
export const MIN_SIDE_PANEL_WIDTH_WITH_EDITOR = 600
/**
 * The chat center's own floor. A side panel is a guest in this column and may
 * never take the width the chat needs to stay readable — at 360 the prose is
 * still prose; below it a message is a column of single words.
 */
export const MIN_CHAT_CENTER_WIDTH = 320
export const MAX_SIDE_PANEL_WIDTH = 1280

export const DEFAULT_SIDE_PANEL_WIDTH = 640
export const DEFAULT_FILE_PANE_WIDTH = 280

export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max)
}

/** Which panes the side panel is currently showing. */
export interface SidePanelPanes {
  showFileTree: boolean
  showEditor: boolean
  showImage: boolean
}

/**
 * What became of the panel the layout asked for.
 *
 * `full` — it was drawn at the size it asked for.
 * `shrunk` — the column could spare less than it asked for, so it was narrowed,
 *            still at or above MIN_SIDE_PANEL_WIDTH.
 * `closed` — the column could not spare even that, so the panel is not drawn at
 *            all and the chat keeps its own floor. The render says which of the
 *            three it was, so a panel that disappeared is explained rather than
 *            missed.
 */
export type SidePanelFit = 'full' | 'shrunk' | 'closed'

export interface SidePanelMetrics {
  /** The file tree fills the side panel on its own. */
  fileTreeOnly: boolean
  /** Lower bound for the side panel in the current layout. */
  minSidePanelWidth: number
  /** Rendered width of the whole side panel. */
  contentWidth: number
  /** Rendered width of the file-tree pane. */
  filePaneWidth: number
  /** The one ceiling both the drag handlers and the render must respect. */
  maxFilePaneWidth: number
  /** The widest the whole panel may be in this column — the drag's ceiling too. */
  maxSidePanelWidth: number
  /** Whether the panel was drawn whole, narrowed to fit, or not drawn at all. */
  fit: SidePanelFit
  /** The floor actually honoured, which is the layout's only while it fits. */
  editorPaneMinWidth: number
}

/**
 * Resolve the rendered widths and the bounds a drag must clamp to.
 *
 * `resolveSidePanelMetrics(panes, sidePanel, metrics.filePaneWidth)` returns the
 * same `filePaneWidth` it was given — that fixed-point property is what keeps a
 * drag from moving state the render will not follow.
 *
 * `availableWidth` is the chat column's own rendered width. The side panel
 * shares that column with the chat center, so it may never be wider than the
 * column itself: a persisted or dragged width beyond that pushes the panel's
 * right edge (the editor/image pane) outside the window, and the flex parent's
 * `overflow-hidden` clips it there.
 */
export function resolveSidePanelMetrics(
  panes: SidePanelPanes,
  sidePanelWidth: number,
  filePaneWidth: number,
  availableWidth?: number
): SidePanelMetrics {
  const besideAnotherPane = panes.showEditor || panes.showImage
  const fileTreeOnly = panes.showFileTree && !besideAnotherPane

  const layoutMin =
    panes.showFileTree && besideAnotherPane
      ? MIN_SIDE_PANEL_WIDTH_WITH_EDITOR
      : MIN_SIDE_PANEL_WIDTH

  // The column is the one input that is not a constant: when it is known the
  // panel's ceiling is what the chat can spare, never the whole column.
  const column = availableWidth !== undefined && availableWidth > 0 ? availableWidth : null
  const spareWidth =
    column === null
      ? MAX_SIDE_PANEL_WIDTH
      : Math.min(MAX_SIDE_PANEL_WIDTH, Math.max(0, column - MIN_CHAT_CENTER_WIDTH))

  // Neither pane can be usable in what is left: close the panel, keep the chat.
  const closed = column !== null && spareWidth < MIN_SIDE_PANEL_WIDTH
  const maxSidePanelWidth = closed ? 0 : spareWidth
  // The layout's floor applies only as far as the column allows it to.
  const minSidePanelWidth = closed ? 0 : Math.min(layoutMin, maxSidePanelWidth)
  const sidePanel = closed ? 0 : clamp(sidePanelWidth, minSidePanelWidth, maxSidePanelWidth)

  // The verdict is about what is DRAWN, not about the panel's stored preference:
  // a lone file tree whose pane fits exactly has not been narrowed, whatever the
  // panel's remembered width says.
  const requestedWidth = fileTreeOnly ? filePaneWidth : sidePanelWidth

  // Alone, the file tree *is* the side panel, so there is nothing to reserve —
  // reserving anyway is what pinned it to a fraction of the panel. The window
  // width caps it too, so a lone tree cannot spill past the glass.
  const maxFilePaneWidth = closed
    ? 0
    : fileTreeOnly
      ? maxSidePanelWidth
      : column === null
        ? Math.max(MIN_FILE_PANE_WIDTH, sidePanel - MIN_EDITOR_PANE_WIDTH)
        : Math.max(MIN_FILE_PANE_WIDTH, sidePanel - MIN_EDITOR_PANE_WIDTH)

  const filePane = closed ? 0 : clamp(filePaneWidth, MIN_FILE_PANE_WIDTH, maxFilePaneWidth)

  // An editor beside the file tree keeps its floor only while there is room for
  // one; squeezing it to 220 is a narrow preview, squeezing the chat to 120 is a
  // window nobody can read.
  const editorPaneMinWidth = closed
    ? 0
    : Math.min(MIN_EDITOR_PANE_WIDTH, Math.max(0, sidePanel - MIN_FILE_PANE_WIDTH))

  const contentWidth = closed ? 0 : fileTreeOnly ? filePane : sidePanel
  const fit: SidePanelFit = closed ? 'closed' : contentWidth < requestedWidth ? 'shrunk' : 'full'

  return {
    fileTreeOnly,
    minSidePanelWidth,
    contentWidth,
    filePaneWidth: filePane,
    maxFilePaneWidth,
    maxSidePanelWidth,
    fit,
    editorPaneMinWidth,
  }
}
