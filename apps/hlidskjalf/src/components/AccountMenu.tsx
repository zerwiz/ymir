import { useEffect, useRef, useState } from 'react';
import { useYmir } from '../state/store';

export function AccountMenu() {
  const session = useYmir((s) => s.session);
  const signOut = useYmir((s) => s.signOut);
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onDoc);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDoc);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  if (!session) return null;
  const { user } = session;

  return (
    <div className="menu-wrap" ref={ref}>
      <button
        className="user-trigger"
        aria-haspopup="dialog"
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
      >
        <span className="avatar" aria-hidden="true">
          {user.avatar}
        </span>
        <span className="col" style={{ lineHeight: 1.25, textAlign: 'left' }}>
          <span style={{ fontSize: 13 }}>{user.login}</span>
          <span className="mono dim" style={{ fontSize: 10 }}>
            signed in
          </span>
        </span>
      </button>

      {open ? (
        <div className="popover account-popover" role="dialog" aria-label="Account">
          <div className="account-head">
            <span className="avatar" aria-hidden="true">
              {user.avatar}
            </span>
            <div className="col" style={{ lineHeight: 1.3 }}>
              <strong>{user.name}</strong>
              <span className="mono dim" style={{ fontSize: 11 }}>
                {user.email}
              </span>
            </div>
          </div>

          <div className="account-foot">
            <span className="mono dim" style={{ fontSize: 10 }}>
              signed in via {session.method}
            </span>
            <button className="btn btn-danger" onClick={signOut}>
              <span aria-hidden="true">ᛪ</span> Sign out
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
