# Plan 30 — Mobile (APK / PWA)

- **Status:** active · **Owner:** Brokk · **Depends:** Hlidskjalf SPA, gate API,
  Gjallarhorn tunnel, Capacitor shell
- **Reality:** Hlidskjalf is desktop-first. A responsive stylesheet is the first
  step, not the finish. This plan is the full mobile workstream.

## Objective

The whole Ymir control plane usable on a phone: native-feel navigation, every
gate legible and operable by touch, a real APK + installable PWA, and an auth /
session flow that survives mobile.

## Workstreams

### 1. Navigation & shell
- **Bottom tab bar** for the primary gates (Fleet · Tasks · Well · Chat · More),
  not the desktop rail. A **More** sheet lists the rest.
- Topbar → compact: workspace switcher as a **bottom sheet**; drop desktop-only
  controls (density, search) or move them into the sheet.
- Safe-area insets (notch / home indicator): `env(safe-area-inset-*)`.
- Back button (Android) → close sheet/modal, else navigate up, not exit.

### 2. Every gate on a phone
- Audit all 16 gates at 390×844: Fleet (graph → list), Tasks (board → cards),
  Well (recall cards), Runes (table → cards), Reviews, Processes, Files (tree),
  OmniChat, Forge, Runtime, Cron, Sessions, Trace, Decisions, Stats, Profile.
- **Tables → card lists** on mobile (not horizontal scroll where cards read better).
- Touch targets ≥ 44px; no hover-only affordances.

### 3. Chat (the daily surface)
- Full-screen thread, **sticky composer**, keyboard-aware scroll, safe-area.
- Session switcher + model picker as sheets; thinking indicator already present.
- Streaming/typing on slow links.

### 4. PWA
- Manifest: **maskable** icons (192/512), `display: standalone`, theme color.
- Service worker: offline app shell + asset cache; "add to home screen" prompt.

### 5. APK (Capacitor)
- App **icon** (adaptive) + **splash**; status-bar style; safe areas.
- Decide **remote (`server.url`) vs bundled (`webDir: dist`)** — bundled is more
  robust offline and avoids CDN cache; remote updates instantly. Recommend
  **bundled** for the shell + API to the tunnel.
- Back-button + deep links; keep-alive.
- **Release signing** (keystore) for a distributable APK/AAB.
- Device test path: AVD (needs a system image) + `adb install`.

### 6. Auth & session
- Mobile-friendly login (already a modal; ensure it fits + scrolls).
- Session cookie persistence in the WebView; refresh on resume.
- Optional biometric unlock (Capacitor plugin) — later.

### 7. Performance
- Lazy-load gates; trim bundle (currently ~366 KB JS).
- Streaming SSE on mobile networks (reconnect).

## Done when

A phone user installs the APK (or PWA), signs in, navigates every gate by thumb,
chats with Kaia, watches the stream, and the app survives background/return and
offline reload — with no desktop layout leaking through.

## Test matrix

- Android Chrome (PWA) · the APK on a real device · one small screen (≤ 360px) ·
  one large (≥ 430px) · offline reload · backgrounding.
