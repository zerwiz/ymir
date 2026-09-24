import { useYmir } from '../state/store';
import { PRCard } from '../components/PRCard';
import { MetricTile } from '../components/MetricTile';

/**
 * Glitnir — Reviews (audited 2026-09-24). The cards come from `/api/reviews`:
 * real PRs (gh) + the Brokk lint/compliance gate card (number 0 — NOT a PR).
 * The tiles count REAL pull requests only, and a dead GitHub read is shown,
 * never silently swallowed.
 */
export function Reviews() {
  const info = useYmir((s) => s.reviews);
  const cards = info?.cards ?? [];
  const real = cards.filter((c) => c.number > 0);
  const ghError = info?.ghError ? (info.ghError.length > 160 ? `${info.ghError.slice(0, 160)}…` : info.ghError) : '';

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Glitnir — Reviews</h1>
          <p className="stage-deck">
            Human in the loop · Mjollnir never force-merges · a rune seals every approval
          </p>
        </div>
      </div>

      {ghError ? (
        <div
          className="muted"
          style={{
            marginBottom: 'var(--ymir-space-4)',
            padding: '8px 12px',
            fontSize: 12,
            border: '1px solid var(--ymir-warn, #b45309)',
            borderRadius: 8,
          }}
        >
          github read failed — {ghError}
        </div>
      ) : null}

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Open PRs" value={real.length} delta="awaiting the Allfather" />
        <MetricTile label="Approved" value={real.filter((r) => r.state === 'approved').length} tone="var(--ymir-ok)" delta="ready to merge" />
        <MetricTile label="Changes requested" value={real.filter((r) => r.state === 'changes').length} tone="var(--ymir-warn)" delta="blocked" />
        <MetricTile label="CI failing" value={real.filter((r) => r.checks.some((c) => c.state === 'down')).length} tone="var(--ymir-danger)" delta="do not seal" />
      </div>

      <div className="gate-grid cols-2">
        {cards.map((pr) => (
          <PRCard key={pr.id} pr={pr} />
        ))}
        {cards.length === 0 ? (
          <div className="panel">
            <div className="panel-body">
              <p className="muted">No cards yet — open a PR and it lands here.</p>
            </div>
          </div>
        ) : null}
      </div>
    </>
  );
}