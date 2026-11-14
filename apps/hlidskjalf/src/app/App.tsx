import { useEffect } from 'react';
import { Shell } from './Shell';
import { Overlay } from '../components/Overlay';
import { EmberBackground } from '../components/EmberBackground';
import { gateApi } from '../services/api';
import { startStream } from '../services/stream';
import { gateFromHash, useYmir } from '../state/store';

export default function App() {
  const session = useYmir((s) => s.session);

  /**
   * The halls are LOCAL (plan 275 item 30): there is no login to pass and no
   * chooser to answer. The desktop session is the authority, so boot goes
   * straight to the seat, and the one thing asked of the gate is the seat's own
   * name — never a credential. An earlier build asked the gate whether it had
   * "authenticated" a browser, offered an invite code, a GitHub door and a
   * "three halls share one login" chooser; all of that was for hosting the apps
   * publicly, which they never should have been (plans 277 and 279).
   */
  useEffect(() => {
    void gateApi
      .session()
      .then((r) => useYmir.getState().establishSession(r.login || 'operator'))
      .catch(() => useYmir.getState().establishSession('operator'));
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

  // Hold until the session exists: the tenant list (the realm folders) comes
  // from it, and rendering a gate with no workspaces would hide two realms.
  if (!session) return <EmberBackground />;

  return (
    <>
      <EmberBackground />
      <Shell />
      <Overlay />
    </>
  );
}
