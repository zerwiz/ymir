// The house voice, part by part — no browser, no running hall, no xAI.
//
//   cd apps/bilskirnir && DB_PATH=/tmp/hv-test.db npx tsx tests/house-voice.mts
//
// 1. the voice list is Kokoro's (Rödd's voices first)
// 2. Kokoro speaks a sentence (its unit is woken if it sleeps)
// 3. that speech, encoded as the browser records it (webm/opus), comes back as text through whisper.cpp
// 4. the relay carries realtime frames both ways to an engine stand-in, offering the 'realtime' subprotocol
// 5. realtimeStatus reads the engine's /v1/pool
// 6. with Rödd's engine raised (YMIR_VOICE_PORT, default 8890), a session.update is answered by the real engine
import { spawn } from 'node:child_process';
import http from 'node:http';
import type { AddressInfo } from 'node:net';
import { WebSocket, WebSocketServer } from 'ws';
import { house, houseVoices, kokoroSpeak, realtimeStatus, relayHouseRealtime, whisperTranscribe } from '../server/src/voice-house.js';

let failed = 0;
const ok = (name: string, cond: boolean, detail = '') => {
  console.log(`${cond ? 'ok  ' : 'FAIL'} ${name}${detail ? ` — ${detail}` : ''}`);
  if (!cond) failed++;
};

function toWebm(pcm: Buffer, rate: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const p = spawn('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-f', 's16le', '-ar', String(rate), '-ac', '1', '-i', 'pipe:0', '-c:a', 'libopus', '-f', 'webm', 'pipe:1']);
    const out: Buffer[] = [];
    p.stdout.on('data', (d) => out.push(d));
    p.on('error', reject);
    p.on('exit', (code) => (code === 0 ? resolve(Buffer.concat(out)) : reject(new Error(`ffmpeg ${code}`))));
    p.stdin.end(pcm);
  });
}

// 1
const voices = await houseVoices();
ok('voice list is Kokoro\'s', voices.length > 0 && voices.every((v) => /^[ab][fm]_/.test(v.id)), voices.slice(0, 5).map((v) => v.id).join(', '));
ok('Nanna\'s voice heads the list', voices[0]?.id === house.defaultVoice, voices[0]?.name);

// 2 + 3
const sentence = 'Good evening Allfather, the house voice is answering.';
let pcm: Buffer | null = null;
try {
  const t = Date.now();
  pcm = await kokoroSpeak(sentence, house.defaultVoice, 1, 24000);
  ok('Kokoro speaks', pcm.length > 24000, `${(pcm.length / 48000).toFixed(2)} s of audio in ${Date.now() - t} ms`);
} catch (e) {
  ok('Kokoro speaks', false, (e as Error).message);
}
if (pcm) {
  const webm = await toWebm(pcm, 24000);
  const t = Date.now();
  const text = await whisperTranscribe(webm, 'en').catch((e) => `ERROR ${(e as Error).message}`);
  ok('whisper hears it back', /house voice/i.test(text) && /allfather|all father/i.test(text), `"${text}" in ${Date.now() - t} ms`);
}

// 4 + 5 — an engine stand-in: answers /v1/pool and echoes realtime frames
const fake = http.createServer((req, res) => {
  if (req.url === '/v1/pool') { res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify({ size: 1, in_use: 0, units: [] })); return; }
  res.statusCode = 404; res.end();
});
const fakeWss = new WebSocketServer({ server: fake, path: '/v1/realtime' });
let offered = '';
fakeWss.on('connection', (ws, req) => {
  offered = String(req.headers['sec-websocket-protocol'] ?? '');
  ws.send(JSON.stringify({ type: 'session.created' }));
  ws.on('message', (d) => { const ev = JSON.parse(d.toString()); if (ev.type === 'session.update') ws.send(JSON.stringify({ type: 'session.updated', session: ev.session })); });
});
await new Promise<void>((r) => fake.listen(0, '127.0.0.1', r));
const fakePort = (fake.address() as AddressInfo).port;
const realUrl = house.realtimeUrl;
house.realtimeUrl = `ws://127.0.0.1:${fakePort}/v1/realtime`;

const st = await realtimeStatus();
ok('realtimeStatus reads the pool', st.up && st.total === 1 && st.free === 1, JSON.stringify(st));

const front = new WebSocketServer({ port: 0, host: '127.0.0.1' });
front.on('connection', (c) => relayHouseRealtime(c));
await new Promise<void>((r) => front.once('listening', r));
const frontPort = (front.address() as AddressInfo).port;

async function roundTrip(url: string, session: Record<string, unknown>) {
  const ws = new WebSocket(url);
  const got: string[] = [];
  return await new Promise<string[]>((resolve) => {
    const done = () => { try { ws.close(); } catch { /* ignore */ } resolve(got); };
    const timer = setTimeout(done, 20_000);
    ws.on('open', () => ws.send(JSON.stringify({ type: 'session.update', session })));
    ws.on('message', (d) => {
      const ev = JSON.parse(d.toString());
      got.push(ev.type === 'error' ? `error:${ev.error?.type ?? ''}:${ev.error?.message ?? ''}` : ev.type);
      if (ev.type === 'session.updated' || ev.type === 'error') { clearTimeout(timer); done(); }
    });
    ws.on('error', () => { clearTimeout(timer); done(); });
  });
}
const relayed = await roundTrip(`ws://127.0.0.1:${frontPort}`, { type: 'realtime', instructions: 'test' });
ok('relay carries frames both ways', relayed.includes('session.created') && relayed.includes('session.updated'), relayed.join(' → '));
ok('relay offers the realtime subprotocol', offered.split(',').map((s) => s.trim()).includes('realtime'), offered);

// 6 — the real engine, when it is raised
house.realtimeUrl = realUrl;
const real = await realtimeStatus();
if (!real.up) {
  console.log(`skip the real engine is not raised (${real.detail}); raise it with bin/voice/voice-door.sh host`);
} else if (real.free === 0) {
  console.log('skip the real engine\'s one seat is held (Rödd is in a call)');
} else {
  const events = await roundTrip(`ws://127.0.0.1:${frontPort}`, {
    type: 'realtime',
    instructions: 'You are Nanna. Say hello.',
    audio: { input: { format: { type: 'audio/pcm', rate: 24000 }, turn_detection: { type: 'server_vad', interrupt_response: true } }, output: { format: { type: 'audio/pcm', rate: 24000 }, voice: house.defaultVoice } },
  });
  ok('Rödd\'s engine accepts the hall\'s session', events.includes('session.updated'), events.join(' → '));
}

front.close(); fakeWss.close(); fake.close();
console.log(failed ? `${failed} failed` : 'all passed');
process.exit(failed ? 1 : 0);
