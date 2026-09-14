import { createApp } from 'vue'
// The cloth's type — Cormorant (display), Newsreader (UI), IBM Plex Mono (data).
import '@fontsource/cormorant/400.css'
import '@fontsource/cormorant/500.css'
import '@fontsource/cormorant/600.css'
import '@fontsource-variable/newsreader'
import '@fontsource/ibm-plex-mono/300.css'
import '@fontsource/ibm-plex-mono/400.css'
import '@fontsource/ibm-plex-mono/500.css'
import App from './App.vue'
import './style.css'

createApp(App).mount('#app')
