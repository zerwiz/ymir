import { useEffect, useState } from 'react';

/** The widths at which the hall narrows (styles/screens.css holds the same numbers). */
export const OVERLAY_QUERY = '(max-width: 1180px)'; // the details slide over the chat
export const DRAWER_QUERY = '(max-width: 860px)'; // the rooms list becomes a drawer

const matches = (q: string) => { try { return window.matchMedia(q).matches; } catch { return false; } };

/** True while the media query matches; follows the window as it is resized or turned. */
export function useMedia(query: string): boolean {
  const [on, setOn] = useState(() => matches(query));
  useEffect(() => {
    let mq: MediaQueryList;
    try { mq = window.matchMedia(query); } catch { return; }
    const onChange = () => setOn(mq.matches);
    onChange();
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, [query]);
  return on;
}
