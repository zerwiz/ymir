import { useEffect, useState } from 'react';
import { Shell } from './Shell';
import { Overlay } from '../components/Overlay';
import { LoginModal } from '../components/LoginModal';
import { gateApi } from '../services/api';
import { startStream } from '../services/stream';
import { gateFromHash, useYmir } from '../state/store';

export default function App() {
  const session = useYmir((s) => s.session);
  const [authed, setAuthed] = useState<boolean | null>(null);

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
    const id = window.setInterval(() => void useYmir.getState().refreshSmidja(), 5000);
    return () => window.clearInterval(id);
  }, [session]);

  useEffect(() => {
    const onHash = () => useYmir.getState().setGate(gateFromHash());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  /** After the gate admits us, take its word for who we are. */
  const admitted = () => {
    setAuthed(true);
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
      <Shell />
      <Overlay />
    </>
  );
}
