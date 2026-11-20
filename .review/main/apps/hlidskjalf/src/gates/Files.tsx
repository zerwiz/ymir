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

// The tree CAN fold (2026-09-24): a dir's children render only while the dir is
// open. The old tree was always fully expanded, so folders could neither open
// nor close — every click merely selected. `collapsed` is the fold state.
function visibleFlat(
  node: FileNode,
  collapsed: ReadonlySet<string>,
  depth = 0,
  out: FlatNode[] = [],
): FlatNode[] {
  out.push({ node, depth });
  if (node.type === 'dir' && node.children && !collapsed.has(node.path)) {
    for (const child of node.children) visibleFlat(child, collapsed, depth + 1, out);
  }
  return out;
}

function Chevron({ open }: { open: boolean }) {
  return (
    <span className="f-glyph" aria-hidden="true" style={{ width: 12, flex: 'none' }}>
      {open ? '▾' : '▸'}
    </span>
  );
}

function FolderGlyph() {
  // Folder-shaped, not a text triangle (the Allfather's 2026-09-24 word): the
  // silhouette carries the shape; the chevron beside it carries open/closed.
  return (
    <svg
      className="f-glyph"
      style={{ flex: 'none' }}
      width="15"
      height="15"
      viewBox="0 0 20 20"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M2.8 6.4A1.8 1.8 0 0 1 4.6 4.6h3.4l1.5 1.8h6.1a1.8 1.8 0 0 1 1.8 1.8v6.4a1.8 1.8 0 0 1-1.8 1.8H4.6a1.8 1.8 0 0 1-1.8-1.8V6.4z" />
    </svg>
  );
}

function FileGlyph() {
  return (
    <svg
      className="f-glyph"
      style={{ flex: 'none' }}
      width="14"
      height="15"
      viewBox="0 0 20 20"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M11.4 2.8H6a1.2 1.2 0 0 0-1.2 1.2v12A1.2 1.2 0 0 0 6 17.2h8a1.2 1.2 0 0 0 1.2-1.2V6.6L11.4 2.8z" />
      <path d="M11.4 2.8v3.8h3.8" />
    </svg>
  );
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
  // Folds start CLOSED (a 96-file realm opens tidy): each dir except the root
  // begins collapsed, and clicking a dir opens/closes it (2026-09-24).
  const initialDirs = useMemo(
    () => flat.filter((f) => f.node.type === 'dir' && f.node.path !== files.path).map((f) => f.node.path),
    [flat, files.path],
  );
  const [collapsed, setCollapsed] = useState<Set<string>>(() => new Set(initialDirs));
  const visible = useMemo(() => visibleFlat(files, collapsed), [files, collapsed]);
  const [selected, setSelected] = useState<string>(
    () => flat.find((f) => f.node.type === 'file')?.node.path ?? files.path,
  );
  const [preview, setPreview] = useState<Preview | null>(null);
  const [loading, setLoading] = useState(false);

  const toggleDir = (path: string) =>
    setCollapsed((prev) => {
      const next = new Set(prev);
      if (next.has(path)) next.delete(path);
      else next.add(path);
      return next;
    });

  // The tree starts folded, so the initially selected file would hide under its
  // closed parents — open just that ancestor chain once (2026-09-24).
  useEffect(() => {
    setCollapsed((prev) => {
      if (!prev.size) return prev;
      const parts = selected.split('/');
      const dirs = new Set<string>();
      for (let i = 1; i < parts.length - 1; i++) dirs.add(parts.slice(0, i).join('/'));
      let changed = false;
      const next = new Set(prev);
      for (const d of dirs) if (next.has(d)) {
        next.delete(d);
        changed = true;
      }
      return changed ? next : prev;
    });
    // The intent is one-time on mount; `selected` at mount is the loaded
    // default and is intentionally captured, not tracked.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
              visible.map(({ node, depth }) => {
                const isDir = node.type === 'dir';
                return (
                  <button
                    key={node.path}
                    className="file-node"
                    style={{ paddingLeft: 12 + depth * 14 }}
                    aria-selected={selected === node.path}
                    aria-expanded={isDir ? !collapsed.has(node.path) : undefined}
                    onClick={() => {
                      setSelected(node.path);
                      if (isDir) toggleDir(node.path);
                    }}
                  >
                    {isDir ? (
                      <>
                        <Chevron open={!collapsed.has(node.path)} />
                        <FolderGlyph />
                      </>
                    ) : (
                      <FileGlyph />
                    )}
                    <span className="truncate">{node.name}</span>
                  </button>
                );
              })
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
