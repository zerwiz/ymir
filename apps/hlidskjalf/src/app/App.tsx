import { useEffect, useState } from 'react';
import { Shell } from './Shell';
import { Login } from './Login';
import { Overlay } from '../components/Overlay';
import { LoginModal } from '../components/LoginModal';
import { gateApi } from '../services/api';
import { startStream } from '../services/stream';
import { gateFromHash, useYmir } from '../state/store';

export default function App() {
  const session = useYmir((s) => s.session);
  const demo = useYmir((s) => s.demo);
  const [authed, setAuthed] = useState<boolean | null>(null);

  useEffect(() => {
    if (demo) {
      setAuthed(true);
      return;
    }
    void gateApi
      .session()
      .then((r) => setAuthed(r.authed))
      .catch(() => setAuthed(true));
  }, [demo]);

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
    if (!session || demo) return;
    const id = window.setInterval(() => void useYmir.getState().refreshSmidja(), 5000);
    return () => window.clearInterval(id);
  }, [session, demo]);

  useEffect(() => {
    const onHash = () => useYmir.getState().setGate(gateFromHash());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  // Hold until we know (no unauthenticated flash of the app), then hard-gate.
  if (authed === null && !demo) {
    return null;
  }

  if (authed === false) {
    return (
      <>
        <LoginModal
          onAuthed={() => {
            setAuthed(true);
            void useYmir.getState().loadLive();
          }}
        />
        <Overlay />
      </>
    );
  }

  return (
    <>
      {session ? <Shell /> : <Login />}
      <Overlay />
    </>
  );
}
