/**
 * A no-op extension, kept only so nothing loads TWICE.
 *
 * An extension that registers the same tools as one already loaded from the global
 * home makes pi refuse the duplicate — `Tool "gna_watch_arm" conflicts with …`. But a
 * file that exports no factory at all is its own error:
 *   "Extension does not export a valid factory function".
 * So this exports a valid factory that registers nothing.
 *
 * The real extension is `gna-pi-watch`, in the shared source
 * (`.pi/shared/extensions/`), deployed to the one global home.
 */
export default function well(): void {
  // deliberately empty: this seat is not the extension's home.
}
