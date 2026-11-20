import { useEffect, useRef } from 'react';
import mainRaw from '../hall/lh-main.html?raw';
import sagaRaw from '../hall/lh-saga.json?raw';
import boardJs from '../hall/lh-board.js?raw';

/**
 * LivehallBoard — the hall's own board, THE SAME LAYOUT AS IT HAD on the Astro
 * page (2026-09-24 law: a port is never simplified — the original is the
 * contract). The original <main id="livehall"> markup, the saga payload, and
 * the original board script (tally strip · the dealt call with recommended
 * marks + freeform + the 512-byte queue guard · stack navigation · the carved
 * ledger thread rows · the dispatch picker · fail-closed render) are carried
 * VERBATIM via vite ?raw, and the original kit (cloth.css + livehall.css)
 * applies scoped to #livehall (lh-scoped.css). Read-only, always — exactly as
 * the Astro board was.
 */
export default function LivehallBoard() {
  const ran = useRef(false);

  useEffect(() => {
    if (ran.current) return; // one mount, one run of the machinery
    ran.current = true;

    const root = document.getElementById('livehall');
    if (!root) return;

    // 1. the saga payload the machinery paints first (the tale), before it
    //    reads the livehall snapshot.
    let saga = document.getElementById('lh-saga') as HTMLScriptElement | null;
    if (!saga) {
      saga = document.createElement('script');
      saga.id = 'lh-saga';
      saga.type = 'application/json';
      root.appendChild(saga);
    }
    saga.textContent = (sagaRaw.match(/<script[^>]*>([\s\S]*?)<\/script>/i) || [null, sagaRaw])[1].trim();

    // 2. the board machinery — the original IIFE, against the same ids.
    try {
      // eslint-disable-next-line no-new-func
      new Function(boardJs)();
    } catch {
      /* fail-closed: the tale and the snapshot stay unpainted, nothing crashes */
    }
  }, []);

  return <div className="lh-host" dangerouslySetInnerHTML={{ __html: mainRaw }} />;
}