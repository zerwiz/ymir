/**
 * Type declarations for the shared hearth (ember.js).
 *
 * The implementation is plain JS so any surface — React, Vue, Astro, or a bare
 * page — can import the same fire. These types keep TypeScript consumers honest
 * without forcing the module itself into a build step.
 */

/** Start the hearth on <host> (a canvas, or an element to receive one). Returns a stop function. */
export function startEmbers(host: Element | null): () => void;

/** Light every element marked `data-ember`. Returns one stop function per hearth. */
export function startAllEmbers(root?: ParentNode): Array<() => void>;
