import { useEffect, useMemo, useState } from 'react';
import { useYmir } from '../state/store';
import { gateApi } from '../services/api';
import { Markdown } from '../components/Markdown';
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

interface Preview {
  path: string;
  size?: number;
  updated?: string;
  body?: string;
  note?: string;
  error?: string;
}

/** Files (Skrymir) — the realm tree from the gate API, with real file contents. */
export function Files() {
  const files = useYmir((s) => s.files);
  const realm = useYmir((s) => s.realm);
  const live = useYmir((s) => s.live);
  const flat = useMemo(() => flatten(files), [files]);
  const [selected, setSelected] = useState<string>(
    () => flat.find((f) => f.node.type === 'file')?.node.path ?? files.path,
  );
  const [preview, setPreview] = useState<Preview | null>(null);
  const [loading, setLoading] = useState(false);

  const selectedNode = flat.find((f) => f.node.path === selected)?.node;

  useEffect(() => {
    if (!selectedNode || selectedNode.type !== 'file' || live !== true) {
      setPreview(null);
      return;
    }
    let alive = true;
    setLoading(true);
    gateApi
      .file(realm, selected)
      .then((r) => alive && setPreview(r))
      .catch(() => alive && setPreview({ path: selected, error: 'unavailable' }))
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
  }, [selected, selectedNode, realm, live]);

  const body =
    selectedNode?.type !== 'file'
      ? selectedNode
        ? 'directory — select a file to preview'
        : 'select a file'
      : loading
        ? 'reading…'
        : preview?.body != null
          ? preview.body
          : (preview?.note ?? preview?.error ?? 'no content available');

  const isMarkdown =
    selectedNode?.type === 'file' &&
    !loading &&
    preview?.body != null &&
    /\.(md|markdown)$/i.test(selectedNode.name);

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Skrymir</h1>
          <p className="stage-deck">The giant's hand · realm-scoped file browser · read-only</p>
        </div>
      </div>

      <div className="files-layout">
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛊ</span>
              {files.name}
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>
              {flat.filter((f) => f.node.type === 'file').length} files
            </span>
          </div>
          <div className="file-tree">
            {flat.length <= 1 ? (
              <div className="empty" style={{ padding: 16 }}>
                <p className="mono dim" style={{ fontSize: 11 }}>no files in this realm</p>
              </div>
            ) : (
              flat.map(({ node, depth }) => (
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
              ))
            )}
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛊ</span>
              {selected}
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>
              {selectedNode?.size ? `${selectedNode.size} bytes` : selectedNode?.type === 'dir' ? 'directory' : ''}
            </span>
          </div>
          <div className={`file-preview${isMarkdown ? ' md-preview' : ''}`}>
            {isMarkdown ? <Markdown source={body} /> : body}
          </div>
        </section>
      </div>
    </>
  );
}
