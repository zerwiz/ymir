import { useEffect } from 'react';
import { Shell } from './Shell';
import { Login } from './Login';
import { Overlay } from '../components/Overlay';
import { startStream } from '../services/stream';
import { gateFromHash, useYmir } from '../state/store';

export default function App() {
  const session = useYmir((s) => s.session);
  const demo = useYmir((s) => s.demo);

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

  return (
    <>
      {session ? <Shell /> : <Login />}
      <Overlay />
    </>
  );
}
