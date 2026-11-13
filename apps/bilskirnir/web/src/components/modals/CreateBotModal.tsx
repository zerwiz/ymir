import { useCallback, useState } from 'react';
import type { AvatarColor, AvatarShape, Bot } from '@shared/types';
import { BotAvatar } from '../../avatar/BotAvatar';
import { CharacterPicker } from '../../avatar/CharacterPicker';
import { api } from '../../lib/api';
import { COLOR_NAMES, COLOR_ORDER, palette } from '../../lib/colors';
import { useStore } from '../../store';
import { Icon } from '../Icon';
import { Modal } from './Modal';


export function CreateBotModal() {
  const setModal = useStore((s) => s.setModal);
  const [name, setName] = useState('');
  // the house's characters (plan 275, 2026-11-13): the Ymir mark by default, or one of the fourteen figures
  const [shape, setShape] = useState<AvatarShape>('ymir');
  const [color, setColor] = useState<AvatarColor>('yellow');
  const [mode, setMode] = useState<Bot['mode']>('personal');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const close = useCallback(() => setModal(null), [setModal]);
  const canCreate = name.trim().length > 0 && !busy;

  const create = async () => {
    if (!canCreate) return;
    setBusy(true); setError(null);
    try {
      const { bot } = await api.createBot({ name: name.trim(), avatarShape: shape, avatarColor: color, mode });
      const st = useStore.getState();
      st.set({ bots: st.bots.some((b) => b.id === bot.id) ? st.bots : [...st.bots, bot] });
      st.selectBot(bot.id);
      close();
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  };

  return (
    <Modal onClose={close} className="create-modal" label="Seat a new agent">
      <form onSubmit={(e) => { e.preventDefault(); create(); }}>
        <div className="modal__header">
          <div className="modal__title">Seat a new agent</div>
          <button type="button" className="modal__close" onClick={close} aria-label="Close"><Icon name="close" size={14} opacity={0.68} /></button>
        </div>
        <div className="create-modal__body">
          <BotAvatar shape={shape} color={color} size={96} className="create-modal__preview" />
          <input
            className="text-input create-modal__name"
            placeholder="Name your agent"
            value={name}
            maxLength={60}
            onChange={(e) => setName(e.target.value)}
            autoFocus
            aria-label="Agent name"
          />
          <CharacterPicker shape={shape} color={color} onShape={setShape} />
          <div className="swatches" role="radiogroup" aria-label="The agent's hue">
            <div className="swatches__row">
              {COLOR_ORDER.map((c) => (
                <button key={c} type="button" role="radio" aria-checked={color === c} aria-label={COLOR_NAMES[c]} title={COLOR_NAMES[c]} className="swatch-cell" onClick={() => setColor(c)}>
                  <span className={`swatch${color === c ? ' is-selected' : ''}`} style={{ background: palette(c).fill }} />
                </button>
              ))}
            </div>
          </div>
          <div className="mode-pick" role="radiogroup" aria-label="Whose it is">
            <button type="button" role="radio" aria-checked={mode === 'personal'} className={`mode-pick__opt${mode === 'personal' ? ' is-active' : ''}`} onClick={() => setMode('personal')}>
              <span className="mode-pick__title">Yours alone</span>
              <span className="mode-pick__sub">Works for you, with your apps and your mail</span>
            </button>
            <button type="button" role="radio" aria-checked={mode === 'teammate'} className={`mode-pick__opt${mode === 'teammate' ? ' is-active' : ''}`} onClick={() => setMode('teammate')}>
              <span className="mode-pick__title">The whole house’s</span>
              <span className="mode-pick__sub">Works for everyone in the house</span>
            </button>
          </div>
          {error && <div className="card__error">{error}</div>}
        </div>
        <div className="modal__footer">
          <button type="button" className="link-btn link-btn--small" style={{ marginRight: 'auto' }} onClick={() => setModal('group')}>A shared room instead</button>
          <button type="button" className="btn btn--secondary btn--sm" onClick={close}>Cancel</button>
          <button type="submit" className="btn btn--primary btn--sm" disabled={!canCreate}>{busy ? 'Creating…' : 'Create'}</button>
        </div>
      </form>
    </Modal>
  );
}
