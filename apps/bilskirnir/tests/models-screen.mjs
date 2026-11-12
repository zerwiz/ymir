// models-screen.mjs — photograph Settings > Models at desktop and phone width, in a real Chromium.
//
//   node tests/models-screen.mjs [url] [out-dir] [label]
//     url      the running web face   (default http://localhost:5173)
//     out-dir  where the PNGs land     (default tests/out, git-ignored)
//     label    a prefix for the files  (default "models")
//
// Opens the hall (the local operator is seated by the server), opens Settings with Ctrl+comma, picks the
// Models page, waits for the detection to land, and photographs it. Fails loudly when the page scrolls
// sideways, or when a key-looking string reaches the page.
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { execSync } from 'node:child_process';

const url = process.argv[2] ?? 'http://localhost:5173';
const out = process.argv[3] ?? new URL('./out', import.meta.url).pathname;
const label = process.argv[4] ?? 'models';
mkdirSync(out, { recursive: true });

const probe = () => { for (const b of ['chromium', 'chromium-browser', 'google-chrome-stable']) { try { return execSync(`command -v ${b}`, { shell: '/bin/sh' }).toString().trim(); } catch { /* next */ } } return undefined; };
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM ?? probe() });
const sizes = [
  { name: 'desktop', width: 1280, height: 900, mobile: false },
  { name: 'phone', width: 390, height: 844, mobile: true },
];
let bad = 0;
for (const s of sizes) {
  const ctx = await browser.newContext({ viewport: { width: s.width, height: s.height }, isMobile: s.mobile, hasTouch: s.mobile, deviceScaleFactor: s.mobile ? 2 : 1 });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  await page.keyboard.press('Control+Comma');
  await page.locator('.app-settings').waitFor({ timeout: 8000 });
  await page.getByRole('button', { name: 'Models', exact: true }).click();
  await page.locator('.models-provider').first().waitFor({ timeout: 40000 });
  await page.waitForTimeout(500);
  await page.screenshot({ path: join(out, `${label}-${s.name}-${s.width}x${s.height}.png`) });
  // a provider where the fleet's allow-list greys most rows (when there is a list)
  const refused = page.locator('.models-row.is-refused').first();
  if (await refused.count()) { await refused.scrollIntoViewIfNeeded(); await page.waitForTimeout(200); await page.screenshot({ path: join(out, `${label}-${s.name}-${s.width}x${s.height}-refused.png`) }); }
  // the add form open, with a preset picked
  await page.locator('#mdl-preset').selectOption('openrouter');
  await page.locator('#mdl-key').scrollIntoViewIfNeeded();
  await page.screenshot({ path: join(out, `${label}-${s.name}-${s.width}x${s.height}-add.png`) });
  const m = await page.evaluate(() => ({
    sideways: document.documentElement.scrollWidth > window.innerWidth + 1 || (document.querySelector('.app-settings__main')?.scrollWidth ?? 0) > (document.querySelector('.app-settings__main')?.clientWidth ?? 0) + 1,
    leak: /sk-[A-Za-z0-9_-]{12,}|Bearer\s+\S{12,}/.test(document.body.innerText),
    providers: document.querySelectorAll('.models-provider').length,
    refused: document.querySelectorAll('.models-row.is-refused').length,
  }));
  console.log(`${s.name} ${s.width}x${s.height}: providers=${m.providers} refused-rows=${m.refused} sideways-scroll=${m.sideways ? 'YES' : 'no'} key-on-page=${m.leak ? 'YES' : 'no'}`);
  if (m.sideways || m.leak) bad++;
  await ctx.close();
}
await browser.close();
process.exit(bad ? 1 : 0);
