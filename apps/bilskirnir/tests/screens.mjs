// screens.mjs — photograph the hall at the four screen sizes it must fit, in a real Chromium.
//
//   node tests/screens.mjs [url] [out-dir] [label]
//     url      the running web face   (default http://localhost:5173)
//     out-dir  where the PNGs land     (default tests/out, git-ignored)
//     label    a prefix for the files  (default "after")
//
// For each size it takes the hall as it opens, then — where the layout hides them — with the
// rooms drawer open and with the details open, so every stage of the narrowing is on record.
// It also fails loudly when the page scrolls sideways or the composer falls off the screen.
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';

const url = process.argv[2] ?? 'http://localhost:5173';
const out = process.argv[3] ?? new URL('./out', import.meta.url).pathname;
const label = process.argv[4] ?? 'after';
mkdirSync(out, { recursive: true });

const sizes = [
  { name: 'phone', width: 390, height: 844, mobile: true },
  { name: 'tablet', width: 768, height: 1024, mobile: true },
  { name: 'laptop', width: 1280, height: 800, mobile: false },
  { name: 'desktop', width: 1920, height: 1080, mobile: false },
];

// a real Chromium: CHROMIUM if set, else the system's own (probed), else Playwright's bundled one
import { execSync } from 'node:child_process';
const probe = () => { for (const b of ['chromium', 'chromium-browser', 'google-chrome-stable']) { try { return execSync(`command -v ${b}`, { shell: '/bin/sh' }).toString().trim(); } catch { /* next */ } } return undefined; };
const executablePath = process.env.CHROMIUM ?? probe();
const browser = await chromium.launch({ executablePath });
let bad = 0;
for (const s of sizes) {
  const ctx = await browser.newContext({ viewport: { width: s.width, height: s.height }, isMobile: s.mobile, hasTouch: s.mobile, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1200);
  const shot = (what) => page.screenshot({ path: join(out, `${label}-${s.name}-${s.width}x${s.height}${what ? '-' + what : ''}.png`) });
  await shot('');

  const m = await page.evaluate(() => {
    const comp = document.querySelector('.composer');
    const r = comp?.getBoundingClientRect();
    return {
      sideways: document.documentElement.scrollWidth > window.innerWidth + 1,
      composerVisible: !!r && r.bottom <= window.innerHeight + 1 && r.top >= 0 && r.left >= 0 && r.right <= window.innerWidth + 1 && r.width > 0,
    };
  });
  const verdict = `${s.name} ${s.width}x${s.height}: sideways-scroll=${m.sideways ? 'YES' : 'no'} composer-on-screen=${m.composerVisible ? 'yes' : 'NO'}`;
  console.log(verdict);
  if (m.sideways || !m.composerVisible) bad++;

  // the rooms drawer, where the sidebar is a drawer
  const opener = page.locator('.chat__rooms-btn');
  if (await opener.isVisible().catch(() => false)) {
    await opener.click();
    await page.waitForTimeout(400);
    await shot('rooms');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(300);
  }
  // the details, where they are an overlay
  const det = page.locator('.chat__details-btn');
  if (await det.isVisible().catch(() => false)) {
    await det.click();
    await page.waitForTimeout(400);
    await shot('details');
  }
  await ctx.close();
}
await browser.close();
process.exit(bad ? 1 : 0);
