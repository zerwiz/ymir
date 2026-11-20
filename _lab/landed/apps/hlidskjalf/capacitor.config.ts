import type { CapacitorConfig } from '@capacitor/cli';

// The APK is a thin native shell over the Hlidskjalf web app. Point it at the
// tunnel by default; change the address later with YMIR_SERVER_URL (e.g. your
// own server) — no code change needed.
// Where the app looks for its own gate. A fresh install serves it locally;
// an operator with a tunnel sets YMIR_SERVER_URL to their own hostname.
const serverUrl = process.env.YMIR_SERVER_URL ?? 'http://127.0.0.1:3888';

const config: CapacitorConfig = {
  appId: 'org.ymir.hlidskjalf',
  appName: 'Ymir',
  webDir: 'dist',
  server: {
    url: serverUrl,
    cleartext: false,
    androidScheme: 'https',
    // Only the host the operator actually serves from, never a fixed domain.
    allowNavigation: [new URL(serverUrl).host],
  },
  android: {
    allowMixedContent: false,
  },
};

export default config;
