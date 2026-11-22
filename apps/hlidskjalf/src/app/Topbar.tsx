import { useYmir } from '../state/store';
import { AccentPicker } from '../components/AccentPicker';
import { AccountMenu } from '../components/AccountMenu';
import { SnotraLive } from '../components/SnotraLive';
import { Ward } from '../components/Ward';

export function Topbar() {
  const query = useYmir((s) => s.query);
  const setQuery = useYmir((s) => s.setQuery);
  const density = useYmir((s) => s.density);
  const setDensity = useYmir((s) => s.setDensity);
  const agents = useYmir((s) => s.agents);

  return (
    <header className="topbar">
      <div className="trace-chip" title="Fleet — nominal agents of connected">
        <span className="label">Fleet</span>
        <span
          className="value"
          style={{
            color: !agents.length
              ? undefined
              : agents.every((a) => a.status === 'nominal')
                ? 'var(--ymir-ok)'
                : agents.some((a) => a.status === 'nominal')
                  ? 'var(--ymir-warn)'
                  : 'var(--ymir-danger)',
          }}
        >
          {agents.filter((a) => a.status === 'nominal').length}/{agents.length}
        </span>
      </div>

      <label className="search">
        <span aria-hidden="true">ᛊ</span>
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search the house…"
          aria-label="Search"
        />
        <kbd>/</kbd>
      </label>

      <div className="topbar-spacer" />

      {/* Snotra's live recording — a meeting transcribed into the hoard. It sits
          on its own, clearly apart from Skírnir (the assistant), which is a page
          of its own reached from the gate rail: one way to talk to Skírnir, and
          one control that records. */}
      <SnotraLive />

      <Ward />

      <a
        className="icon-btn"
        href="https://ymir.zerwiz.org/saga/"
        target="_blank"
        rel="noopener noreferrer"
        title="The saga — the lore and the long telling"
        aria-label="Open the saga"
      >
        ᛊ
      </a>

      <AccentPicker />

      <button
        className="icon-btn"
        aria-pressed={density === 'compact'}
        onClick={() => setDensity(density === 'compact' ? 'comfortable' : 'compact')}
        title="Compact density"
      >
        {density === 'compact' ? 'ᛃ' : 'ᚼ'}
      </button>

      <AccountMenu />
    </header>
  );
}
