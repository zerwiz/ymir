import { useMemo, useState } from 'react';
import { useYmir } from '../state/store';
import { useUI } from '../state/ui';
import type { FileNode } from '../types';

interface FlatNode {
  node: FileNode;
  depth: number;
}

function flatten(node: FileNode, depth = 0, out: FlatNode[] = []): FlatNode[] {
  out.push({ node, depth });
  if (node.type === 'dir' && node.children) {
    for (const child of node.children) flatten(child, depth + 1, out);
  }
  return out;
}

const PREVIEWS: Record<string, string> = {
  '/company/offer.md': `# Offer — WayOf\n\n## Promise\nOne operator, an entire business, run from a single repository.\n\n## Lines\n- Ymir OS — the platform itself\n- Brokk Forge — engineering & build tooling\n- Runestone Labs — records & compliance\n\n> The forge stays hot.`,
  '/development/specs/hlidskjalf.md': `# Hlidskjalf — Spec\n\n## Shell\n- grid-template-columns: 236px rail | 1fr\n- rows: 56px topbar · stage · 192px stream\n- data-realm drives the tenant tint\n\n## Gates\nFleet · Tasks · Well · Runes · Reviews · Processes · Files · OmniChat\n\n## Components\nAgentCard · TaskChip · TraceRow · RecallPanel · MetricTile · RuneTag · PRCard`,
  '/memory/daily/2026-09-11.md': `# 2026-09-11 — Daily\n\n## Forged\n- Ported the reference shell + realm tints (W0026)\n- Wired the bottom stream (Ratatoskr + Runes)\n- Raised all eight gates with mock data\n\n## Observed into the well\n- 128 episodes. Well warm.\n\n## Next\n- Wire SSE to the gate API (W0027)`,
  '/.env.realm': `# realm secrets — never committed\nREALM_ID=way-of\nVECTOR_DB_PATH=./.agents/memory/mimbrunn.db\nLM_STUDIO_URL=http://localhost:1234`,
  '/Brokk.md': `# Brokk — WayOf realm persona\n\nYou are Brokk, the bellows-smith. You keep the forge hot and drive every task to a tangible artifact.\n\n## Laws\n1. Output over process\n2. Isolation by default\n3. Audit everything`,
};

export function Files() {
  const files = useYmir((s) => s.files);
  const pushStream = useYmir((s) => s.pushStream);
  const { openModal, toast } = useUI();
  const flat = useMemo(() => flatten(files), [files]);
  const [selected, setSelected] = useState<string>(
    () => flat.find((f) => f.node.type === 'file')?.node.path ?? files.path,
  );

  function upload() {
    openModal({
      variant: 'form',
      tone: 'info',
      glyph: 'ᛊ',
      title: 'Upload to Skrymir',
      body: `Realm-scoped write under ${files.path}. Bifrost scopes every path to the tenant.`,
      confirmLabel: 'Write file',
      fields: [
        { name: 'name', label: 'File name', placeholder: 'notes.md' },
        { name: 'body', label: 'Contents', type: 'textarea', placeholder: '# …' },
      ],
      onSubmit: (v) => {
        const name = v.name || 'untitled.md';
        pushStream({
          id: `file-${Date.now()}`,
          ts: new Date().toISOString(),
          kind: 'rune',
          from: 'Skrymir',
          module: 'skrymir',
          message: `file.write ${name} (${(v.body ?? '').length} bytes)`,
          checksum: Math.random().toString(16).slice(2, 8),
        });
        toast({ kind: 'ok', title: `${name} written`, body: files.path });
      },
    });
  }

  const selectedNode = flat.find((f) => f.node.path === selected)?.node;
  const preview = PREVIEWS[selected] ?? `# ${selectedNode?.name ?? selected}\n\n(Skrymir Vue sub-app mounts here — W0032.)\n\npath: ${selected}\nsize: ${selectedNode?.size ?? 0} bytes\nupdated: ${selectedNode?.updated ? new Date(selectedNode.updated).toLocaleString('en-GB') : '—'}`;

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Skrymir</h1>
          <p className="stage-deck">
            The giant's hand · realm-scoped file browser · served through Bifrost /files
          </p>
        </div>
        <button className="btn" onClick={upload}>
          <span aria-hidden="true">ᛊ</span> Upload
        </button>
      </div>

      <div className="files-layout">
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛊ</span>
              {files.name}
            </div>
          </div>
          <div className="file-tree">
            {flat.map(({ node, depth }) => (
              <button
                key={node.path}
                className="file-node"
                style={{ paddingLeft: 12 + depth * 14 }}
                aria-selected={selected === node.path}
                onClick={() => setSelected(node.path)}
              >
                <span className="f-glyph" aria-hidden="true">
                  {node.type === 'dir' ? '▸' : '◆'}
                </span>
                <span className="truncate">{node.name}</span>
              </button>
            ))}
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛊ</span>
              {selected}
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>
              {selectedNode?.size ? `${selectedNode.size} bytes` : 'directory'}
            </span>
          </div>
          <div className="file-preview">{preview}</div>
        </section>
      </div>
    </>
  );
}
