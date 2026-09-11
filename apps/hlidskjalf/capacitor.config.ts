import type { CapacitorConfig } from '@capacitor/cli';

// The APK is a thin native shell over the Hlidskjalf web app. Point it at the
// tunnel by default; change the address later with YMIR_SERVER_URL (e.g. your
// own server) — no code change needed.
const serverUrl = process.env.YMIR_SERVER_URL ?? 'https://ymirdell.zerwiz.org';

const config: CapacitorConfig = {
  appId: 'org.zerwiz.ymir',
  appName: 'Ymir',
  webDir: 'dist',
  server: {
    url: serverUrl,
    cleartext: false,
    androidScheme: 'https',
    allowNavigation: ['ymirdell.zerwiz.org', '*.zerwiz.org'],
  },
  android: {
    allowMixedContent: false,
  },
};

export default config;
