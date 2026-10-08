import { useCallback, useEffect, useRef, useState } from 'react';
import { gateApi, type LiveTailStatus } from '../services/api';
import { useUI } from '../state/ui';
import { useYmir } from '../state/store';

/** One beat while the ear is open, and while the book is closing. Idle NEVER
 *  polls — a readout that polls forever is a readout that never sleeps. */
const POLL_MS = 3000;

/** The shape the script writes into the filename. Mirrored here so the operator
 *  sees the name that will actually land in the hoard. */
function sanitizeSlug(raw: string): string {
  const slug = raw
    .trim()
    .replace(/[^a-zA-Z0-9._-]/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug || 'note';
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

/** The newest line wins, so the document reads top-down as it grows. */
const newestFirst = (lines: string[]) => [...lines].reverse();

/**
 * The ONE control for the live tail, beside the halls switcher in the topbar.
 *
 * It is a front for `bin/time/snotra/snotra-live.sh` and nothing more: no
 * transcription, no slice timing, no engine discovery. The script owns the
 * truth, and the surface says what the script says — including its refusals.
 */
export function SnotraLive() {
  const [status, setStatus] = useState<LiveTailStatus | null>(null);
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const panelRef = useRef<HTMLDivElement | null>(null);
  const { openModal, toast } = useUI();
  const pushStream = useYmir((s) => s.pushStream);

  const state = status?.state ?? 'idle';
  const listening = state === 'listening';
  const closing = state === 'closing';

  const read = useCallback(async () => {
    try {
      setStatus(await gateApi.liveStatus());
    } catch {
      // The gate is unreachable: say so rather than claim an ear that is not
      // reporting. The chip falls back to its idle form and the panel explains.
      setStatus({ state: 'idle' });
    }
  }, []);

  // ONE poll loop, and only while there is something to watch. Opening the
  // surface re-reads once so it never shows a stale chip.
  useEffect(() => {
    void read();
  }, [read]);
  useEffect(() => {
    if (!listening && !closing) return;
    const beat = window.setInterval(() => void read(), POLL_MS);
    return () => window.clearInterval(beat);
  }, [listening, closing, read]);

  // A click outside the panel closes it; the listening chip must not hide the
  // words behind a second click.
  useEffect(() => {
    if (!open) return;
    const away = (e: MouseEvent) => {
      if (!panelRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', away);
    return () => document.removeEventListener('mousedown', away);
  }, [open]);

  function emit(message: string) {
    pushStream({
      id: `snotra-live-${Date.now()}`,
      ts: new Date().toISOString(),
      kind: 'rune',
      from: 'Snotra',
      to: 'Hlidskjalf',
      module: 'snotra-live',
      message,
      checksum: Math.random().toString(16).slice(2, 8),
    });
  }

  function askToStart() {
    openModal({
      variant: 'form',
      tone: 'ok',
      glyph: 'ᛟ',
      title: 'Start listening',
      body: 'The live tail writes the words into a document as they are spoken. The name becomes the filename.',
      confirmLabel: 'Listen',
      fields: [
        { name: 'slug', label: 'Name', type: 'text', defaultValue: today() },
        { name: 'topic', label: 'Topic (optional)', type: 'text', placeholder: 'what this meeting is about' },
      ],
      onSubmit: (values) => {
        const slug = sanitizeSlug(values.slug ?? '');
        setBusy(true);
        void gateApi
          .liveStart(slug, values.topic?.trim() || undefined)
          .then((res) => {
            if (!res.ok) {
              // ONE EAR AT A TIME, and the script names the busy ear. Show its
              // sentence, never a generic error the operator cannot act on.
              toast({ kind: 'warn', title: 'The ear is busy', body: res.error });
              return;
            }
            emit(`snotra.live opened — ${slug}`);
            toast({ kind: 'ok', title: 'Listening', body: `The document grows: ${slug}.live.md` });
            setOpen(true);
            return read();
          })
          .catch(() => toast({ kind: 'danger', title: 'The gate did not answer', body: 'Is the gate API up on :3889?' }))
          .finally(() => setBusy(false));
      },
    });
  }

  function askToStop() {
    // Stopping ends a recording and then runs the whole mine -> minutes -> Rune
    // tail, so it is a consequential action and asks first.
    openModal({
      variant: 'confirm',
      tone: 'warn',
      glyph: 'ᛪ',
      title: 'Close the book?',
      body: 'The recording ends here. The slices are joined, the minutes are written and a rune is carved — that takes a while, and the book is closing in the background.',
      confirmLabel: 'Close the book',
      onSubmit: () => {
        setBusy(true);
        void gateApi
          .liveStop()
          .then((res) => {
            if (!res.closing) {
              toast({ kind: 'warn', title: 'Nothing to close', body: res.error });
              return;
            }
            emit('snotra.live closing the book…');
            toast({
              kind: 'ok',
              title: 'Closing the book…',
              body: 'The minutes are written in the background. This panel follows it to the end.',
            });
            setOpen(true);
            return read();
          })
          .catch(() => toast({ kind: 'danger', title: 'The gate did not answer', body: 'Is the gate API up on :3889?' }))
          .finally(() => setBusy(false));
      },
    });
  }

  const lines = newestFirst(status?.lines ?? []);

  return (
    <div className="snotra-live" ref={panelRef}>
      <button
        type="button"
        className={`snotra-live-btn snotra-live-${state}`}
        onClick={() => (listening || closing ? setOpen((v) => !v) : askToStart())}
        disabled={busy}
        aria-expanded={open}
        title={
          listening
            ? 'The live tail is listening — open the transcript'
            : closing
              ? 'Closing the book — the minutes are being written'
              : 'Start listening — transcribe this machine as you speak'
        }
      >
        <span className="glyph" aria-hidden="true">
          {closing ? 'ᛃ' : 'ᛟ'}
        </span>
        <span className="snotra-live-text">
          {listening ? 'Listening' : closing ? 'Closing…' : 'Start listening'}
        </span>
      </button>

      {open && (
        <div className="snotra-live-panel" role="region" aria-label="Live tail">
          <header className="snotra-live-head">
            <span className={`status status-${listening ? 'ok' : closing ? 'warn' : 'info'}`}>
              <span className="dot" aria-hidden="true">
                {closing ? 'ᛃ' : listening ? 'ᛟ' : 'ᛪ'}
              </span>
              {listening ? 'LISTENING' : closing ? 'CLOSING THE BOOK' : 'NOT LISTENING'}
            </span>
            {status?.slices !== undefined && (
              <span className="snotra-live-meta">
                {status.slices} slice{status.slices === 1 ? '' : 's'} written
              </span>
            )}
          </header>

          {closing && (
            <p className="snotra-live-note">
              The ear is stilled; the slices are joined, the minutes written and a rune carved.
              This panel follows it until the script says the book is closed.
            </p>
          )}

          {lines.length > 0 ? (
            <div className="snotra-live-lines">
              {lines.map((line, i) => {
                const m = line.match(/^\[(\d{2}:\d{2}:\d{2})\]\s?(.*)$/);
                return (
                  <p className="snotra-live-line" key={`${m?.[1] ?? i}-${i}`}>
                    <span className="snotra-live-stamp">{m?.[1] ?? '--:--:--'}</span>
                    <span className="snotra-live-text-line">{m?.[2] ?? line}</span>
                  </p>
                );
              })}
            </div>
          ) : (
            // No tail running is a STATE to say, never an empty panel drawn as
            // if it were the truth.
            <p className="snotra-live-note">
              {closing
                ? 'The document is closed; the minutes are still being written.'
                : listening
                  ? 'Listening — the first line arrives a few seconds after you speak.'
                  : 'No live tail is running. The document grows here only while the ear is open.'}
            </p>
          )}

          {status?.doc && (
            <footer className="snotra-live-foot">
              <span className="snotra-live-doc" title={status.doc}>
                {status.doc}
              </span>
              {listening && (
                <button type="button" className="btn btn-sm" onClick={askToStop}>
                  <span aria-hidden="true">ᛪ</span> Close the book
                </button>
              )}
            </footer>
          )}
        </div>
      )}
    </div>
  );
}