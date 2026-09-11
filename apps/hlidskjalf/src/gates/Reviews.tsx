import { useYmir } from '../state/store';
import { PRCard } from '../components/PRCard';
import { MetricTile } from '../components/MetricTile';

export function Reviews() {
  const reviews = useYmir((s) => s.reviews);

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

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Open PRs" value={reviews.length} delta="awaiting the captain" />
        <MetricTile label="Approved" value={reviews.filter((r) => r.state === 'approved').length} tone="var(--ymir-ok)" delta="ready to merge" />
        <MetricTile label="Changes requested" value={reviews.filter((r) => r.state === 'changes').length} tone="var(--ymir-warn)" delta="blocked" />
        <MetricTile label="CI failing" value={reviews.filter((r) => r.checks.some((c) => c.state === 'down')).length} tone="var(--ymir-danger)" delta="do not seal" />
      </div>

      <div className="gate-grid cols-2">
        {reviews.map((pr) => (
          <PRCard key={pr.id} pr={pr} />
        ))}
      </div>
    </>
  );
}
