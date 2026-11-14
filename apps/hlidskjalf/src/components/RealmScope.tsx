import { useYmir } from '../state/store';

/**
 * The realm a page is scoped to — a FILTER, never a mode (plan 275 items 11, 21).
 *
 * The top bar's mode chips went with the one-runtime change, and that is right:
 * there is one Hlidskjalf. But a realm is still a shelf of the home
 * (`svartalfaheim/<realm>`), and pinning the runtime to one of them stranded the
 * others. So the chips come back where they actually mean something — a page that
 * scopes its work by realm — and nowhere else. Every realm the home holds is here:
 * the list is the operator's own registry, read at run time, so no realm is hidden
 * by a default and none of their names lives in this file.
 */
export function RealmScope({ hint }: { hint?: string }) {
  const realm = useYmir((s) => s.realm);
  const realms = useYmir((s) => s.realms);
  const setRealm = useYmir((s) => s.setRealm);
  return (
    <div className="realm-scope" role="group" aria-label="Realm">
      <span className="realm-scope-label">realm</span>
      {realms.map((r) => (
        <button
          key={r.id}
          type="button"
          className={`chip ${realm === r.id ? 'on' : ''}`}
          aria-pressed={realm === r.id}
          title={hint ?? `${r.name ?? r.id} — svartalfaheim/${r.id}`}
          onClick={() => realm !== r.id && setRealm(r.id)}
        >
          <span aria-hidden="true">{r.glyph}</span> {r.name ?? r.id}
        </button>
      ))}
    </div>
  );
}
