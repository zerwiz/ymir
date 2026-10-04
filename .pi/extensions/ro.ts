/**
 * A no-op extension, kept only so nothing loads TWICE.
 *
 * The real extension is `ro`, in the shared source (`.pi/shared/extensions/`),
 * deployed to the one global home. This file exports a valid factory that registers
 * nothing — an extension loading twice makes pi refuse the duplicate tool, and a file
 * exporting no factory is an error in its own right.
 */
export default function ro(): void {
  // deliberately empty: this seat is not the extension's home.
}
