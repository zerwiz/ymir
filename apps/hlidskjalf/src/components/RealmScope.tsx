import { useYmir } from '../state/store';
import { WORKSPACES } from '../data/realms';

/**
 * The realm a page is scoped to — a FILTER, never a mode (plan 275 items 11, 21).
 *
 * The top bar's Work · Personal · Svein chips went with the one-runtime change,
 * and that is right: there is one Hlidskjalf. But a realm is still a shelf of the
 * home (`svartalfaheim/<realm>`), and pinning the runtime to one of them stranded
 * the other two. So the chips come back where they actually mean something — a
 * page that scopes its work by realm — and nowhere else. Every realm stays
 * reachable and visible; none is hidden by a default.
 */
export function RealmScope({ hint }: { hint?: string }) {
  const realm = useYmir((s) => s.realm);
  const setRealm = useYmir((s) => s.setRealm);
  return (
    <div className="realm-scope" role="group" aria-label="Realm">
      <span className="realm-scope-label">realm</span>
      {WORKSPACES.map((r) => (
        <button
          key={r.id}
          type="button"
          className={`chip ${realm === r.id ? 'on' : ''}`}
          aria-pressed={realm === r.id}
          title={hint ?? `${r.name} — svartalfaheim/${r.id}`}
          onClick={() => realm !== r.id && setRealm(r.id)}
        >
          <span aria-hidden="true">{r.glyph}</span> {r.name}
        </button>
      ))}
    </div>
  );
}
