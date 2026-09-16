/**
 * A no-op extension, kept only so nothing loads TWICE.
 *
 * The real extension is `skuld-branch-supervision`, in the shared source
 * (`.pi/shared/extensions/`), deployed to the one global home. Two copies made pi
 * refuse the duplicate tool; no factory at all is an error. This is neither: a valid
 * factory that registers nothing.
 */
export default function skuldBranchSupervision(): void {
  // deliberately empty: this seat is not the extension's home.
}
