import { useEffect } from 'react';
import { startEvents } from './lib/events';
import { isWide, useStore } from './store';
import { DRAWER_QUERY } from './lib/media';
import { ChatView } from './components/ChatView';
import { ComputerViewer } from './components/ComputerViewer';
import { DetailsPanel } from './components/DetailsPanel';
import { Sidebar } from './components/Sidebar';
import { SignIn } from './components/SignIn';
import { ConnectAppsModal } from './components/modals/ConnectAppsModal';
import { CreateBotModal } from './components/modals/CreateBotModal';
import { CreateGroupModal } from './components/modals/CreateGroupModal';
import { SearchModal } from './components/modals/SearchModal';
import { ConfigLayer } from './components/config/ConfigLayer';
import { TasksView } from './components/config/TasksView';
import { useConfigUI } from './configStore';

function Shell() {
  const detailsOpen = useStore((s) => s.detailsOpen);
  const modal = useStore((s) => s.modal);
  const viewerOpen = useStore((s) => s.viewerOpen);
  const collapsed = useStore((s) => s.sidebarCollapsed);
  const drawerOpen = useStore((s) => s.drawerOpen);
  const hasBot = useStore((s) => !!s.selectedBotId);
  const view = useConfigUI((s) => s.view);
  const showDetails = detailsOpen && hasBot && view === 'chat';

  useEffect(() => {
    const st = useStore.getState();
    st.loadBots().catch(console.error);
    st.loadComputer().catch(console.error);
    const stop = startEvents();
    // OAuth popups post back here; refresh connection-dependent views and the open transcript.
    const onMsg = (e: MessageEvent) => {
      if ((e.data as { type?: string })?.type !== 'grokbot-connected') return;
      const s = useStore.getState();
      s.set({ connectionsVersion: s.connectionsVersion + 1 });
      if (s.selectedBotId) s.loadRows(s.selectedBotId).catch(() => {});
    };
    window.addEventListener('message', onMsg);
    return () => { stop(); window.removeEventListener('message', onMsg); };
  }, []);

  // Global shortcuts: ⌘K search, ⌘B sidebar, ⇧⌘, details, ⌘N new bot.
  useEffect(() => {
    const k = (e: KeyboardEvent) => {
      const st = useStore.getState();
      // Escape folds away whatever covers the chat on a narrow screen: the drawer first, then the details.
      if (e.key === 'Escape' && !st.modal && !st.viewerOpen) {
        if (st.drawerOpen) { st.set({ drawerOpen: false }); return; }
        if (st.detailsOpen && !isWide()) { st.set({ detailsOpen: false }); return; }
      }
      const mod = e.metaKey || e.ctrlKey;
      if (!mod) return;
      const key = e.key.toLowerCase();
      if (key === 'k') { e.preventDefault(); st.setModal(st.modal === 'search' ? null : 'search'); }
      else if (key === 'b') { e.preventDefault(); if (window.matchMedia(DRAWER_QUERY).matches) st.set({ drawerOpen: !st.drawerOpen }); else st.set({ sidebarCollapsed: !st.sidebarCollapsed }); }
      else if (e.shiftKey && (key === ',' || key === '<')) { e.preventDefault(); st.set({ detailsOpen: !st.detailsOpen }); }
      else if (key === ',') { e.preventDefault(); useConfigUI.getState().openAppSettings(); }
    };
    window.addEventListener('keydown', k);
    return () => window.removeEventListener('keydown', k);
  }, []);

  return (
    <div className={`app${collapsed ? ' is-sidebar-collapsed' : ''}${showDetails ? ' has-details' : ''}${drawerOpen ? ' has-drawer' : ''}`}>
      <Sidebar />
      {view === 'tasks' ? <TasksView /> : <ChatView />}
      {/* the veil: only drawn on a narrow screen, behind the drawer or the details; a tap folds them away */}
      <div className="shell-veil" aria-hidden onClick={() => useStore.getState().set(drawerOpen ? { drawerOpen: false } : { detailsOpen: false })} />
      {showDetails && <DetailsPanel />}
      {modal === 'create' && <CreateBotModal />}
      {modal === 'group' && <CreateGroupModal />}
      {modal === 'search' && <SearchModal />}
      {modal === 'apps' && <ConnectAppsModal />}
      {viewerOpen && <ComputerViewer />}
      <ConfigLayer />
    </div>
  );
}

export function App() {
  const authChecked = useStore((s) => s.authChecked);
  const user = useStore((s) => s.user);
  useEffect(() => { useStore.getState().checkAuth(); }, []);
  if (!authChecked) return <div className="boot" />;
  return user ? <Shell /> : <SignIn />;
}
