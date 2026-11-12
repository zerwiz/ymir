import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import './styles/tokens.css';
import './styles/base.css';
import './styles/shell.css';
import './styles/chat.css';
import './styles/cards.css';
import './styles/details.css';
import './styles/modals.css';
import './styles/viewer.css';
import './styles/voice.css';
// The house cloth, dressed on last (docs/house-cloth.md): the tokens, then the mapping.
import '@design/tokens.css';
import './styles/house.css';
// @ts-expect-error — plain JS module from the design system; its types live beside it in ember.d.ts
import { startEmbers } from '@design/ember.js';

// The hearth burns behind the whole app, as it does in Rödd.
const hearth = document.createElement('canvas');
hearth.id = 'ember-bg';
hearth.setAttribute('aria-hidden', 'true');
document.body.prepend(hearth);
startEmbers(hearth);

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
