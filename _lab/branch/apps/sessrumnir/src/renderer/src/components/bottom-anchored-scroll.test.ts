import assert from 'node:assert/strict'
import {
  BOTTOM_ANCHOR_CONTAINER_CLASS,
  BOTTOM_ANCHOR_SPACER_CLASS,
} from './bottom-anchored-scroll'

// The bottom-anchor invariant (plan 214). If these regress, the chat embers
// paint from the top of the pane again — the bug that has been fixed many
// times. Keep these assertions in sync with the primitive.

assert.equal(
  BOTTOM_ANCHOR_CONTAINER_CLASS,
  'flex flex-1 flex-col overflow-y-auto',
  'scroll container must be a flex column that can scroll'
)

assert.equal(
  BOTTOM_ANCHOR_SPACER_CLASS,
  'shrink-0',
  'top spacer must not shrink'
)

// The spacer's flex grow is set inline (1 1 auto) so it takes the free space
// when the conversation is short and collapses to 0 when it overflows. This
// string is the contract; check it lives in the primitive source.
import { readFileSync } from 'node:fs'
const src = readFileSync(new URL('./bottom-anchored-scroll.tsx', import.meta.url), 'utf8')
assert.ok(
  src.includes("flex: '1 1 auto'"),
  'primitive must set the spacer flex to 1 1 auto (bottom-anchoring)'
)
assert.ok(
  src.includes('aria-hidden'),
  'spacer must be aria-hidden'
)