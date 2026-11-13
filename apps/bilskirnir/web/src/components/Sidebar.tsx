import { memo, useCallback, useState } from 'react';
import { useConfigUI } from '../configStore';
import { TasksIsland } from './config/TasksView';
import type { Bot } from '@shared/types';
import { BotAvatarFor } from '../avatar/BotAvatar';
import { displayName, useStore } from '../store';
import { DRAWER_QUERY, useMedia } from '../lib/media';
import { api } from '../lib/api';
import { Icon } from './Icon';
import { Menu } from './Menu';
import { Glyph } from './config/glyphs';
import { configApi } from '../lib/configApi';

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  return ((parts[0]?.[0] ?? '') + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase() || '?';
}

/** On a narrow screen the rooms list is a drawer; this opens it from the chat's own header. */
export function RoomsButton() {
  const set = useStore((s) => s.set);
  return (
    <button type="button" className="icon-btn icon-btn--bordered chat__rooms-btn" onClick={() => set({ drawerOpen: true })} aria-label="Show the rooms" title="The rooms">
      <Icon name="sidebar" opacity={0.66} />
    </button>
  );
}

export function TrafficLights() {
  return (
    <div className="traffic-lights" aria-hidden>
      <span style={{ background: '#FF5F57' }} />
      <span style={{ background: '#FEBC2E' }} />
      <span style={{ background: '#28C840' }} />
    </div>
  );
}

function previewFor(bot: Bot, running: boolean, awaiting: string | null) {
  if (awaiting) return `Waiting for you: ${awaiting}`;
  if (running && !bot.lastPreview) return 'At work…';
  return bot.lastPreview ?? 'Nothing said yet';
}

const BotRow = memo(function BotRow({ bot, selected, running, awaiting, onSelect }: { bot: Bot; selected: boolean; running: boolean; awaiting: string | null; onSelect: (id: string) => void }) {
  // plan 275 (2026-11-13), at the Allfather's word: "i wanna have a delete agent option here, under a settings
  // button per agent". The button opens the agent's settings or deletes it, asking once more before it does.
  const [menu, setMenu] = useState<null | 'main' | 'confirm'>(null);
  const [up, setUp] = useState(false);   // no room below: the menu opens above the row (his word: it went off screen)
  const del = async () => {
    try {
      await configApi.deleteBot(bot.id);
      const st = useStore.getState();
      st.set({ bots: st.bots.filter((b) => b.id !== bot.id) });
      st.loadBots().catch(() => {});
    } catch (e) { window.alert(`${bot.name} was not deleted: ${(e as Error).message}`); }
  };
  const items = menu === 'confirm'
    ? [{ label: `Delete ${bot.name} for good`, danger: true, hint: 'chat, memories, skills, routines', onSelect: del },
       { label: 'Keep it', onSelect: () => {} }]
    : [{ label: 'Settings', onSelect: () => useConfigUI.getState().openBotSettings(bot.id) },
       bot.isPrimary
         ? { label: 'Delete agent…', hint: 'make another first in the hall', onSelect: () => useConfigUI.getState().openBotSettings(bot.id) }
         : { label: 'Delete agent…', danger: true, onSelect: () => setTimeout(() => setMenu('confirm')) }];
  return (
    <div className={`bot-row-wrap${menu ? ' has-menu' : ''}`}>
      <button type="button" className={`bot-row${selected ? ' is-selected' : ''}`} onClick={() => onSelect(bot.id)} aria-current={selected || undefined}>
        <span className="bot-row__avatar">
          <BotAvatarFor bot={bot} size={36} />
          {(running || awaiting || bot.unread > 0) && (
            <span className={`status-dot ${awaiting ? 'is-attention' : running ? 'is-working' : 'is-unread'}`} aria-label={awaiting ? 'Needs attention' : running ? 'Working' : 'Unread activity'} />
          )}
        </span>
        <span className="bot-row__text">
          <span className="bot-row__name">{displayName(bot)}</span>
          <span className="bot-row__preview">{previewFor(bot, running, awaiting)}</span>
        </span>
      </button>
      <button type="button" className="bot-row__more" aria-label={`${bot.name}: settings`} title={`${bot.name}: settings`}
        aria-haspopup="menu" aria-expanded={!!menu} onClick={(e) => { e.stopPropagation(); setUp(window.innerHeight - e.currentTarget.getBoundingClientRect().bottom < 150); setMenu(menu ? null : 'main'); }}>
        <Glyph name="gear" size={15} opacity={0.75} />
      </button>
      {menu && <Menu items={items} align="right" placement={up ? 'above' : 'below'} onClose={() => setMenu(null)} />}
    </div>
  );
});

export function Sidebar() {
  const bots = useStore((s) => s.bots);
  const live = useStore((s) => s.live);
  const storeSelectedBotId = useStore((s) => s.selectedBotId);
  const inTasks = useConfigUI((s) => s.view === 'tasks');
  const selectedBotId = inTasks ? null : storeSelectedBotId; // nothing highlighted while the Tasks view is open
  const user = useStore((s) => s.user);
  const narrow = useMedia(DRAWER_QUERY);
  // in the drawer the rooms are always shown in full; the folded rail is a wide-screen habit
  const collapsed = useStore((s) => s.sidebarCollapsed) && !narrow;
  const set = useStore((s) => s.set);
  const storeSelectBot = useStore((s) => s.selectBot);
  // Picking a bot (even the one already selected) leaves the Tasks view, and closes the drawer.
  const selectBot = useCallback((id: string) => { useConfigUI.getState().setView('chat'); storeSelectBot(id); set({ drawerOpen: false }); }, [storeSelectBot, set]);
  const setModal = useStore((s) => s.setModal);
  const [accountMenu, setAccountMenu] = useState(false);
  const logout = async () => { await api.logout().catch(() => {}); location.reload(); };

  const primary = bots.find((b) => b.isPrimary);
  const others = bots.filter((b) => !b.isPrimary).sort((a, b) => b.lastActivityAt - a.lastActivityAt);

  return (
    <aside className={`sidebar${collapsed ? ' is-collapsed' : ''}`}>
      <div className="sidebar__titlebar">
        <button type="button" className="icon-btn icon-btn--plain sidebar__close" onClick={() => set({ drawerOpen: false })} aria-label="Close the rooms" title="Close">
          <Icon name="close" size={14} opacity={0.66} />
        </button>
        <div className="sidebar__controls">
          <button type="button" className="icon-btn icon-btn--plain sidebar__collapse" onClick={() => set({ sidebarCollapsed: !collapsed })} aria-label={collapsed ? 'Widen the rooms' : 'Fold the rooms'} title="Fold or widen the rooms (⌘B)">
            <Icon name="sidebar" opacity={0.66} />
          </button>
          {!collapsed && (
            <>
              <button type="button" className="icon-btn" onClick={() => setModal('search')} aria-label="Search" title="Search (⌘K)">
                <Icon name="search" opacity={0.66} />
              </button>
              <button type="button" className="icon-btn" onClick={() => setModal('create')} aria-label="New agent" title="New agent">
                <Icon name="plus" opacity={0.66} />
              </button>
            </>
          )}
        </div>
      </div>

      <div className="sidebar__scroll">
        <TasksIsland />
        {primary && (
          <div className="pinned">
            <button type="button" className={`pinned__tile${selectedBotId === primary.id ? ' is-selected' : ''}`} onClick={() => selectBot(primary.id)} title={displayName(primary)}>
              <span className="pinned__avatar">
                <BotAvatarFor bot={primary} size={collapsed ? 44 : 60} star />
                {live[primary.id]?.isRunning && <span className="status-dot is-working pinned__dot" />}
              </span>
              {!collapsed && <span className="pinned__label">{displayName(primary)}</span>}
            </button>
          </div>
        )}
        <div className="bot-list">
          {others.map((b) =>
            collapsed ? (
              <button key={b.id} type="button" className={`bot-rail-item${selectedBotId === b.id ? ' is-selected' : ''}`} onClick={() => selectBot(b.id)} title={displayName(b)}>
                <BotAvatarFor bot={b} size={36} />
              </button>
            ) : (
              <BotRow key={b.id} bot={b} selected={selectedBotId === b.id} running={!!live[b.id]?.isRunning} awaiting={live[b.id]?.awaiting?.reason ?? null} onSelect={selectBot} />
            ),
          )}
          {!collapsed && others.length === 0 && (
            <button type="button" className="bot-list__empty" onClick={() => setModal('create')}>
              <span className="bot-list__empty-plus"><Icon name="plus" size={14} opacity={0.66} /></span>
              <span>
                <span className="bot-row__name">Seat an agent</span>
                <span className="bot-row__preview">Give it an errand, like research or the inbox</span>
              </span>
            </button>
          )}
        </div>
      </div>

      <div className="sidebar__footer">
        <div className="sidebar__fade" />
        {!collapsed && (
          <div className="account">
            <button type="button" className="account__btn" onClick={() => setAccountMenu(!accountMenu)} aria-haspopup="menu" aria-expanded={accountMenu} title={user?.email}>
              <span className="account__initials">{initials(user?.name ?? user?.email ?? '')}</span>
              <span className="account__name">{user?.name ?? user?.email}</span>
            </button>
            {accountMenu && (
              <Menu
                placement="above"
                onClose={() => setAccountMenu(false)}
                items={[
                  { label: 'Settings', hint: '⌘,', onSelect: () => useConfigUI.getState().openAppSettings() },
                  { label: 'Connect apps', onSelect: () => setModal('apps') },
                  { label: 'Leave the hall', danger: true, onSelect: logout },
                ]}
              >
                <div className="menu__header">{user?.email}</div>
              </Menu>
            )}
          </div>
        )}
        <button type="button" className="icon-btn icon-btn--bordered" onClick={() => setModal('apps')} aria-label="Connect apps" title="Connect apps">
          <Icon name="apps" />
        </button>
      </div>
    </aside>
  );
}
