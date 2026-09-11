import { useEffect } from 'react';
import { Shell } from './Shell';
import { Login } from './Login';
import { Overlay } from '../components/Overlay';
import { startStream } from '../services/stream';
import { gateFromHash, useYmir } from '../state/store';

export default function App() {
  const session = useYmir((s) => s.session);

  useEffect(() => {
    if (!session) return;
    return startStream();
  }, [session]);

  useEffect(() => {
    const onHash = () => useYmir.setState({ gate: gateFromHash() });
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
