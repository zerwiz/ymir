import { useEffect, useState } from 'react';
import { Shell } from './Shell';
import { Overlay } from '../components/Overlay';
import { LoginModal } from '../components/LoginModal';
import { EmberBackground } from '../components/EmberBackground';
import { HallsChooser } from '../components/Halls';
import { gateApi, isDesktopSeat } from '../services/api';
import { startStream } from '../services/stream';
import { gateFromHash, useYmir } from '../state/store';

export default function App() {
  const session = useYmir((s) => s.session);
  const [authed, setAuthed] = useState<boolean | null>(null);
  // After the gate admits us, offer the three halls once per login.
  // A desktop shell is a SEAT, not a lobby: it does not ask which hall you
  // want, it opens the one you are in. The picker belongs to the web door.
  const [choosing, setChoosing] = useState(!isDesktopSeat());

  /**
   * One question at boot: has the gate let this browser in?
   *
   * There is exactly one login — the gate's own (`LoginModal`). An earlier build
   * fell through to a second, mock identity picker when the store had no session
   * yet, which meant signing in correctly could land you on a screen offering
   * somebody else's name. The gate's answer now names the operator, and the UI
   * session is built from it.
   */
  useEffect(() => {
    void gateApi
      .session()
      .then((r) => {
        setAuthed(r.authed);
        if (r.authed && r.login) useYmir.getState().establishSession(r.login);
      })
      .catch(() => setAuthed(true));
  }, []);

  // A 401 anywhere re-locks the gate.
  useEffect(() => {
    const lock = () => setAuthed(false);
    window.addEventListener('ymir:unauthorized', lock);
    return () => window.removeEventListener('ymir:unauthorized', lock);
  }, []);

  useEffect(() => {
    if (!session) return;
    return startStream();
  }, [session]);

  // Smíðja runs land in smidja.db at any time; poll so the Sessions/Trace/Stats
  // gates pick up a newly-written run without a page reload.
  useEffect(() => {
    if (!session) return;
    const id = window.setInterval(() => { void useYmir.getState().refreshSmidja(); void useYmir.getState().refreshAgents(); }, 5000);
    const reviewsId = window.setInterval(() => { void useYmir.getState().refreshReviews(); }, 30_000);
    return () => { window.clearInterval(id); window.clearInterval(reviewsId); };
  }, [session]);

  useEffect(() => {
    const onHash = () => useYmir.getState().setGate(gateFromHash());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  /** After the gate admits us, take its word for who we are. */
  /**
   * One login for every app: an app host sends its visitors here with ?next=,
   * so after the gate admits us we hand them back where they were going.
   */
  const returnToNext = () => {
    const next = new URLSearchParams(window.location.search).get('next');
    if (!next) return;
    try {
      const t = new URL(next);
      if (t.origin !== window.location.origin) window.location.replace(t.toString());
    } catch {
      /* a malformed next is ignored, never followed */
    }
  };

  const admitted = () => {
    setAuthed(true);
    returnToNext();
    void gateApi
      .session()
      .then((r) => {
        if (r.login) useYmir.getState().establishSession(r.login);
      })
      .catch(() => setAuthed(false));
  };

  // Hold until we know (no unauthenticated flash of the app).
  if (authed === null) return null;

  if (!authed) {
    return (
      <>
        <EmberBackground />
        <LoginModal onAuthed={admitted} />
        <Overlay />
      </>
    );
  }

  // Auth in flight: the gate admitted us a moment ago and the session is
  // being established. Hold rather than flash the login again.
  if (!session) return null;

  return (
    <>
      <EmberBackground />
      <Shell />
      <Overlay />
      {choosing && <HallsChooser onClose={() => setChoosing(false)} />}
    </>
  );
}
