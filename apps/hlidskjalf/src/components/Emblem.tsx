/**
 * Ymir Root Mark — Algiz (ᛉ) rising from a blacksmith anvil.
 * Dual-layer chisel bevel: iron exterior, luminous cyan inner edge.
 * Construction per design.md §2.1.
 */
export function Emblem({ size = 34 }: { size?: number }) {
  return (
    <svg
      className="emblem"
      width={size}
      height={size}
      viewBox="0 0 48 48"
      role="img"
      aria-label="Ymir Root Mark"
    >
      <defs>
        <linearGradient id="ymir-anvil" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#475569" />
          <stop offset="1" stopColor="#1e293b" />
        </linearGradient>
        <linearGradient id="ymir-rune" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#7dd3fc" />
          <stop offset="1" stopColor="#38bdf8" />
        </linearGradient>
      </defs>
      {/* anvil base */}
      <path
        d="M10 34h28l-3 5H13l-3-5Z"
        fill="url(#ymir-anvil)"
        stroke="#334155"
        strokeWidth="1.5"
      />
      <path d="M6 30h36v4H6z" fill="url(#ymir-anvil)" stroke="#334155" strokeWidth="1.5" />
      {/* Algiz — the branching worker stems */}
      <g
        fill="none"
        stroke="url(#ymir-rune)"
        strokeWidth="3.4"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M24 30V9" />
        <path d="M24 15 12 5" />
        <path d="M24 15 36 5" />
      </g>
    </svg>
  );
}
