#!/usr/bin/env node
/**
 * extract-cloth.mjs — the Hall does not copy the landing's palette by hand.
 *
 * The Hall's cloth (livehall/src/styles/cloth.css) carries a marked region that
 * is *extracted* from the landing's own :root (src/styles/global.css) — the
 * landing is the reference, and the Hall is tethered to it:
 *
 *   node scripts/extract-cloth.mjs          # write the region from the landing
 *   node scripts/extract-cloth.mjs --check  # fail (exit 1) if it has drifted
 *
 * The Hall's own primitives and page chrome live outside the markers and are
 * never touched. If the landing is not present (the Hall standing alone, e.g.
 * split into its own repo), the check warns and passes.
 */
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const repo = new URL('../', import.meta.url);
const landingUrl = new URL('src/styles/global.css', repo);
const loreUrl = new URL('src/lore.html', repo);
const clothUrl = new URL('livehall/src/styles/cloth.css', repo);
const checkOnly = process.argv.includes('--check');

const BEGIN = '/* >>> generated:tokens — extracted from the landing :root (src/styles/global.css) >>> */';
const END = '/* <<< generated:tokens <<< */';

function extractRoot(css) {
  const root = css.match(/:root\{[\s\S]*?\n\}/);
  if (!root) throw new Error('no :root{...} token block found in the landing');
  return root[0];
}

function region(cloth) {
  const from = cloth.indexOf(BEGIN);
  const to = cloth.indexOf(END);
  if (from === -1 || to === -1) throw new Error(`markers missing in ${fileURLToPath(clothUrl)}`);
  return cloth.slice(from + BEGIN.length, to);
}

let landing;
try {
  landing = await readFile(landingUrl, 'utf8');
} catch {
  try {
    landing = await readFile(loreUrl, 'utf8');
  } catch {
    console.warn('cloth: landing tokens not found — the Hall stands alone; token check skipped');
    process.exit(0);
  }
}

let tokens;
try {
  tokens = extractRoot(landing);
} catch (err) {
  console.error('cloth: ' + err.message);
  process.exit(1);
}

const cloth = await readFile(clothUrl, 'utf8');

if (checkOnly) {
  let current;
  try {
    current = region(cloth);
  } catch (err) {
    console.error('cloth: ' + err.message);
    process.exit(1);
  }
  if (current.trim() !== tokens.trim()) {
    console.error('cloth: the Hall\'s tokens have drifted from the landing (src/styles/global.css).');
    console.error('       run `node scripts/extract-cloth.mjs` to re-take them from the landing.');
    const a = current.trim().split('\n');
    const b = tokens.trim().split('\n');
    const n = Math.max(a.length, b.length);
    for (let i = 0; i < n; i++) {
      if (a[i] !== b[i]) {
        if (a[i] !== undefined) console.error('  hall : ' + a[i]);
        if (b[i] !== undefined) console.error('  lore : ' + b[i]);
      }
    }
    process.exit(1);
  }
  console.log('cloth: the Hall\'s tokens match the landing :root');
  process.exit(0);
}

const from = cloth.indexOf(BEGIN);
const to = cloth.indexOf(END);
if (from === -1 || to === -1) {
  console.error('cloth: markers missing in ' + fileURLToPath(clothUrl));
  process.exit(1);
}
const next = cloth.slice(0, from + BEGIN.length) + '\n' + tokens + '\n' + cloth.slice(to);
if (next === cloth) {
  console.log('cloth: already in step with the landing');
} else {
  await writeFile(clothUrl, next);
  console.log('cloth: tokens re-taken from the landing (' + tokens.split('\n').length + ' lines)');
}
