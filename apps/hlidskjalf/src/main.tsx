import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';

// Canonical design tokens — single source of truth (design.md §8).
import '../../../midgard/design-system/tokens.css';
import './styles/global.css';
import './styles/shell.css';
import './styles/components.css';
import './styles/auth.css';
import './styles/menus.css';
import './styles/overlays.css';
import './styles/forge.css';
import './styles/mobile.css';

import App from './app/App';

const el = document.getElementById('root');
if (!el) throw new Error('Hlidskjalf: #root not found');

createRoot(el).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
