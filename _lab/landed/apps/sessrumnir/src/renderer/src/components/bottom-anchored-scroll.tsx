import { forwardRef } from 'react'
import type { ReactNode, UIEventHandler } from 'react'

/**
 * BottomAnchoredScroll — the durable home of the "embers grow from the bottom"
 * invariant for the chat pane (plan 214).
 *
 * A plain block container paints from the top, so a short or freshly loaded
 * conversation renders mid-viewport instead of anchored to the bottom. This
 * component is a flex column with a top spacer that takes the free space when
 * the conversation is short (bottom-anchored) and collapses to 0 when it
 * overflows — deliberately avoiding the `justify-content: flex-end` overflow
 * trap, which can make the START of long content unreachable. The scroll hook
 * still ends a long conversation at the bottom.
 *
 * Do NOT replace this with a plain div or justify-end: that is the regression
 * this primitive exists to prevent.
 */

export const BOTTOM_ANCHOR_CONTAINER_CLASS =
  'flex flex-1 flex-col overflow-y-auto'

export const BOTTOM_ANCHOR_SPACER_CLASS = 'shrink-0'

export interface BottomAnchoredScrollProps {
  children: ReactNode
  onScroll?: UIEventHandler<HTMLDivElement>
  className?: string
}

export const BottomAnchoredScroll = forwardRef<
  HTMLDivElement,
  BottomAnchoredScrollProps
>(function BottomAnchoredScroll({ children, onScroll, className }, ref) {
  return (
    <div
      ref={ref}
      onScroll={onScroll}
      className={BOTTOM_ANCHOR_CONTAINER_CLASS + (className ? ' ' + className : '')}
    >
      <div
        aria-hidden
        className={BOTTOM_ANCHOR_SPACER_CLASS}
        style={{ flex: '1 1 auto' }}
      />
      {children}
    </div>
  )
})