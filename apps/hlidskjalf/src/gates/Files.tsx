import { useCallback, useEffect, useMemo, useState } from 'react';
import { useYmir } from '../state/store';
import { gateApi } from '../services/api';
import { Markdown } from '../components/Markdown';
import type { FileNode } from '../types';

interface FlatNode {
  node: FileNode;
  depth: number;
}

// The tree folds (2026-09-24) and now LAZY-LOADS (2026-11-14, plan 275 item 21):
// Skrymir's root is the whole home, so a folder is read when it is OPENED — the
// whole home is never walked to paint a tree. Hence the state is the set of
// EXPANDED folders (empty at start, so every folder begins closed) and a map of
// the children fetched so far; a folder with no entry is one nobody opened yet.
function visibleFlat(
  node: FileNode,
  children: ReadonlyMap<string, FileNode[]>,
  expanded: ReadonlySet<string>,
  depth = 0,
  out: FlatNode[] = [],
): FlatNode[] {
  out.push({ node, depth });
  if (node.type !== 'dir' || !expanded.has(node.path)) return out;
  for (const child of children.get(node.path) ?? []) visibleFlat(child, children, expanded, depth + 1, out);
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
      <path d="M11.4 2.8H6a1.2 1.2 0 0 0-1.2 1.2v12A1.2 1.2 0 0 0 6 17.2h8a1.2 1.2 0 0 0 1.2-1.2v-9.4L11.4 2.8z" />
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

/** Files (Skrymir) — the WHOLE home, read-only, a folder at a time. */
export function Files() {
  const rootFiles = useYmir((s) => s.files);
  const live = useYmir((s) => s.live);
  const root: FileNode = useMemo(
    () => ({ name: rootFiles.name || 'ymirhome', type: 'dir', path: '', children: rootFiles.children }),
    [rootFiles],
  );
  // path → its children, as fetched. `''` is the root, seeded from the store.
  const [children, setChildren] = useState<Map<string, FileNode[]>>(() => new Map());
  // The ROOT is always open (its path is ''), so the home's own shelves show at
  // once; every folder beneath it starts closed and is read on open.
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set(['']));
  const [selected, setSelected] = useState<string>('');
  const [preview, setPreview] = useState<Preview | null>(null);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);

  useEffect(() => {
    if (rootFiles.children?.length) {
      setChildren((prev) => (prev.has('') ? prev : new Map(prev).set('', rootFiles.children ?? [])));
      return;
    }
    // The store's root arrives with its fast batch; if this page is opened before
    // it, ask for the root itself rather than painting an empty home.
    if (!children.has('')) void load('');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rootFiles]);

  const load = useCallback(async (path: string) => {
    setBusy(path);
    try {
      const dir = await gateApi.files(path);
      if (dir.error) throw new Error(dir.error);
      setChildren((prev) => new Map(prev).set(path, dir.children ?? []));
    } catch {
      setChildren((prev) => new Map(prev).set(path, []));
    } finally {
      setBusy(null);
    }
  }, []);

  const flat = useMemo(() => visibleFlat(root, children, expanded), [root, children, expanded]);

  const toggleDir = (node: FileNode) => {
    const path = node.path;
    setSelected(path);
    const isOpen = expanded.has(path);
    setExpanded((prev) => {
      const next = new Set(prev);
      if (isOpen) next.delete(path);
      else next.add(path);
      return next;
    });
    if (!isOpen && !children.has(path)) void load(path);
  };

  const selectedNode = flat.find((f) => f.node.path === selected)?.node;

  useEffect(() => {
    if (!selectedNode || selectedNode.type !== 'file' || live !== true) {
      setPreview(null);
      return;
    }
    let alive = true;
    setLoading(true);
    gateApi
      .file(selected)
      .then((r) => alive && setPreview(r))
      .catch(() => alive && setPreview({ path: selected, error: 'unavailable' }))
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
  }, [selected, selectedNode, live]);

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

  const fileCount = flat.filter((f) => f.node.type === 'file').length;

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Skrymir</h1>
          <p className="stage-deck">
            The giant's hand · the whole home · realms are folders · read-only
          </p>
        </div>
      </div>

      <div className="files-layout">
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛊ</span>
              {root.name}
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>
              {busy ? 'reading…' : `${fileCount} files shown`}
            </span>
          </div>
          <div className="file-tree">
            {flat.length <= 1 ? (
              <div className="empty" style={{ padding: 16 }}>
                <p className="mono dim" style={{ fontSize: 11 }}>the home is empty</p>
              </div>
            ) : (
              flat
                .slice(1)
                .map(({ node, depth }) => {
                  const isDir = node.type === 'dir';
                  return (
                    <button
                      key={node.path}
                      className="file-node"
                      style={{ paddingLeft: 12 + (depth - 1) * 14 }}
                      aria-selected={selected === node.path}
                      aria-expanded={isDir ? expanded.has(node.path) : undefined}
                      onClick={() => (isDir ? toggleDir(node) : setSelected(node.path))}
                    >
                      {isDir ? (
                        <>
                          <Chevron open={expanded.has(node.path)} />
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
              {selected || root.name}
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
