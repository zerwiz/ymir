/**
 * A no-op extension, kept only so nothing loads TWICE.
 *
 * The real `herdr` lives in the shared source (`.pi/shared/extensions/`), which
 * the loader deploys to the one global pi extension home. An extension present in
 * both the global home and this project-local `.pi/extensions` registers its
 * tools twice, and pi refuses the duplicate — while a file that exports no factory
 * at all is its own error. So this exports a valid factory that registers nothing.
 *
 * This seat is not the extension's home.
 */
export default function herdr(): void {
  // deliberately empty: the mesh's tools are the deployed copy's alone.
}
