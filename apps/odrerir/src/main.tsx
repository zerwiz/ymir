import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './hall.css';
// The original hall board's kit, scoped to #livehall. Imported HERE and not by a CSS
// @import inside hall.css: CSS requires @import to come first, so the one that sat at the
// end of that file was dropped by the build (and the board rendered unstyled). Loading it
// after hall.css keeps the kit's intended order — it wins where the two overlap.
import './hall/lh-scoped.css';

createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);