interface MetricTileProps {
  label: string;
  value: string | number;
  delta?: string;
  tone?: string;
  spark?: number[];
}

function Spark({ points }: { points: number[] }) {
  const w = 92;
  const h = 26;
  const max = Math.max(...points, 1);
  const min = Math.min(...points, 0);
  const span = max - min || 1;
  const d = points
    .map((p, i) => {
      const x = (i / (points.length - 1)) * w;
      const y = h - ((p - min) / span) * h;
      return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(' ');
  return (
    <svg className="spark" width={w} height={h} aria-hidden="true">
      <path d={d} fill="none" stroke="var(--ymir-cyan-1)" strokeWidth="1.5" />
    </svg>
  );
}

export function MetricTile({ label, value, delta, tone, spark }: MetricTileProps) {
  return (
    <div className="metric-tile">
      <div className="label">{label}</div>
      <div className="value" style={tone ? { color: tone } : undefined}>
        {value}
      </div>
      {delta ? <div className="delta">{delta}</div> : null}
      {spark ? <Spark points={spark} /> : null}
    </div>
  );
}
