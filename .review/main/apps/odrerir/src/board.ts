// board.ts — the ONE anatomy shared by the tickets and the plans boards
// (plan 55 law: the same layout, the same skin). The state colours and the
// badge renderer live here so the two boards can never drift apart.
export const STATUS_COLORS: Record<string, string> = {
  Backlog: '#6B7280',
  Planned: '#7d5f2a',
  Ready: '#96a0a8',
  'In Progress': '#3B82F6',
  'Submitted for Review': '#EAB308',
  'In Review': '#EAB308',
  Approved: '#22C55E',
  Done: '#22C55E',
  'Changes Requested': '#F97316',
};

export function esc(s: string | undefined | null): string {
  const d = document.createElement('div');
  d.textContent = s ?? '';
  return d.innerHTML;
}

export function stBadge(st: string): string {
  const c = STATUS_COLORS[st] ?? '#c9973f';
  return `<span class="st-badge" style="background:${c}22;color:${c};border:1px solid ${c}">${esc(st)}</span>`;
}