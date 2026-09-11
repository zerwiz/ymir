import type { PullRequest } from '../types';
import { StatusChip } from './Status';
import { RuneTag } from './RuneTag';
import { useUI } from '../state/ui';
import { useYmir } from '../state/store';

const STATE_META: Record<
  PullRequest['state'],
  { label: string; tone: 'ok' | 'warn' | 'danger' | 'info'; glyph: string }
> = {
  open: { label: 'OPEN', tone: 'info', glyph: 'ᛟ' },
  draft: { label: 'DRAFT', tone: 'warn', glyph: 'ᚦ' },
  changes: { label: 'CHANGES REQUESTED', tone: 'warn', glyph: 'ᚱ' },
  approved: { label: 'APPROVED', tone: 'ok', glyph: 'ᛉ' },
  merged: { label: 'MERGED', tone: 'ok', glyph: 'ᛗ' },
};

function syntheticDiff(pr: PullRequest): string {
  return [
    `diff --git a/${pr.repo}/${pr.title.split(':')[0]} b/${pr.repo}/patch`,
    `--- a/${pr.repo}`,
    `+++ b/${pr.repo}`,
    `@@ -1,${Math.max(3, pr.deletions)} +1,${Math.max(6, pr.additions)} @@`,
    `-# ${pr.title}`,
    `+# ${pr.title}`,
    `+`,
    `+// forged in a Yggdrasil worktree, validated in Utgard`,
    `+export function ${pr.title.split(/[^a-zA-Z]/).filter(Boolean)[1] ?? 'patch'}() {`,
    `+  return '${pr.issue ?? 'artifact'}';`,
    `+}`,
    ``,
    `  ... ${pr.additions} added, ${pr.deletions} removed across ${1 + (pr.number % 4)} files`,
  ].join('\n');
}

export function PRCard({ pr }: { pr: PullRequest }) {
  const state = STATE_META[pr.state];
  const { openModal, toast } = useUI();
  const updateReview = useYmir((s) => s.updateReview);
  const pushStream = useYmir((s) => s.pushStream);

  const frozen = pr.state === 'approved' || pr.state === 'merged';
  const failing = pr.checks.some((c) => c.state === 'down');

  function emit(kind: 'rune' | 'ratatoskr', message: string) {
    pushStream({
      id: `pr-${pr.id}-${Date.now()}`,
      ts: new Date().toISOString(),
      kind,
      from: 'Glitnir',
      to: 'Mjollnir',
      state: kind === 'ratatoskr' ? 'COMPLETED' : undefined,
      module: 'glitnir',
      message,
      checksum: Math.random().toString(16).slice(2, 8),
    });
  }

  function seal() {
    openModal({
      variant: 'confirm',
      tone: failing ? 'warn' : 'ok',
      glyph: 'ᛉ',
      title: `Seal PR #${pr.number}?`,
      body: failing
        ? 'CI is failing on at least one rune. The captain may still seal — human judgement overrides the gate — but Mjollnir will not force-merge.'
        : 'A rune seals every approval. Mjollnir strikes and returns, but never force-merges without the captain.',
      confirmLabel: 'Seal — approve',
      onSubmit: () => {
        updateReview(pr.id, {
          state: 'approved',
          checklist: pr.checklist.map((c) => ({ ...c, done: true })),
        });
        emit('rune', `pr.sealed #${pr.number} — captain approved`);
        toast({ kind: 'ok', title: `PR #${pr.number} sealed`, body: 'Observed into the well; rune carved.' });
      },
    });
  }

  function requestChanges() {
    openModal({
      variant: 'form',
      tone: 'warn',
      glyph: 'ᚱ',
      title: `Request changes on #${pr.number}`,
      body: 'The review is returned to the smith with your note.',
      confirmLabel: 'Request changes',
      fields: [{ name: 'note', label: 'Review note', type: 'textarea', placeholder: 'What must change?' }],
      onSubmit: (values) => {
        updateReview(pr.id, { state: 'changes' });
        emit('ratatoskr', `pr.changes #${pr.number} — ${values.note || 'changes requested'}`);
        toast({ kind: 'warn', title: `Changes requested on #${pr.number}`, body: values.note || undefined });
      },
    });
  }

  function viewDiff() {
    openModal({
      variant: 'info',
      tone: 'info',
      glyph: 'ᛞ',
      title: `Diff — #${pr.number}`,
      body: pr.title,
      content: syntheticDiff(pr),
    });
  }

  return (
    <article className="pr-card">
      <div className="row-between">
        <div className="row grow" style={{ minWidth: 0 }}>
          <span className="pr-num">#{pr.number}</span>
          <span className="pr-title truncate">{pr.title}</span>
        </div>
        <span className={`status status-${state.tone}`}>
          <span className="dot" aria-hidden="true">{state.glyph}</span>
          {state.label}
        </span>
      </div>

      <div className="row" style={{ gap: 'var(--ymir-space-3)', flexWrap: 'wrap' }}>
        <RuneTag label={pr.repo} glyph="ᚱ" color="var(--ymir-cyan-1)" />
        <span className="mono muted" style={{ fontSize: 11 }}>@{pr.author}</span>
        {pr.issue ? <span className="mono muted" style={{ fontSize: 11 }}>closes {pr.issue}</span> : null}
        <span className="pr-diff">
          <span className="add">+{pr.additions}</span>{' '}
          <span className="del">−{pr.deletions}</span>
        </span>
      </div>

      <div className="check-row">
        <span className="eyebrow">CI</span>
        {pr.checks.map((c) => (
          <StatusChip key={c.name} status={c.state} />
        ))}
      </div>

      <div className="checklist">
        {pr.checklist.map((item) => (
          <div key={item.label} className={`check-item ${item.done ? 'done' : ''}`}>
            <span className="box" aria-hidden="true">{item.done ? '✓' : ''}</span>
            <span>{item.label}</span>
          </div>
        ))}
      </div>

      <div className="pr-actions">
        <button className="btn btn-seal" onClick={seal} disabled={frozen}>
          <span aria-hidden="true">ᛉ</span> {pr.state === 'approved' ? 'Sealed' : 'Seal — approve'}
        </button>
        <button className="btn" onClick={requestChanges} disabled={frozen}>
          Request changes
        </button>
        <button className="btn" onClick={viewDiff}>
          View diff
        </button>
      </div>
    </article>
  );
}
