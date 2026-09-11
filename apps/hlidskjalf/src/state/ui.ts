import { create } from 'zustand';

export type Tone = 'ok' | 'info' | 'warn' | 'danger';

export interface Toast {
  id: string;
  kind: Tone;
  title: string;
  body?: string;
}

export interface ModalField {
  name: string;
  label: string;
  placeholder?: string;
  type?: 'text' | 'textarea' | 'number';
  defaultValue?: string;
}

export interface ModalSpec {
  id: string;
  variant: 'confirm' | 'form' | 'info';
  title: string;
  body?: string;
  glyph?: string;
  tone?: Tone;
  confirmLabel?: string;
  cancelLabel?: string;
  fields?: ModalField[];
  /** long pre-formatted text for info modals (e.g. a diff or logs) */
  content?: string;
  onSubmit?: (values: Record<string, string>) => void;
}

interface UIState {
  toasts: Toast[];
  modal: ModalSpec | null;
  toast: (t: Omit<Toast, 'id'>) => void;
  dismiss: (id: string) => void;
  openModal: (m: Omit<ModalSpec, 'id'>) => void;
  closeModal: () => void;
}

let seq = 0;
const uid = (p: string) => `${p}-${Date.now()}-${++seq}`;

export const useUI = create<UIState>((set, get) => ({
  toasts: [],
  modal: null,

  toast: (t) => {
    const id = uid('toast');
    set((s) => ({ toasts: [...s.toasts, { ...t, id }] }));
    window.setTimeout(() => get().dismiss(id), 3800);
  },

  dismiss: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),

  openModal: (m) => set({ modal: { ...m, id: uid('modal') } }),
  closeModal: () => set({ modal: null }),
}));
