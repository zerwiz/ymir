// The house's own voice, in place of xAI's cloud.
//
//   the ear    whisper.cpp (whisper-cli) on this machine — composer dictation
//   the mouth  Kokoro (kokoro-serve, loopback) — the voice list and the preview
//   the call   Rödd's realtime engine (speech-to-speech, raised by bin/voice/voice-door.sh host), reached
//              through a same-origin WebSocket relay so the browser never needs the engine's loopback port
//
// The road is chosen by BILSKIRNIR_VOICE=house|xai (default house). Every path, port and model below has one
// documented default and is overridable from the environment (Ymir RULES/07). Nothing here starts or stops
// Rödd's engine: raising the pipeline is the voice door's business.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import type { IncomingMessage, Server } from 'node:http';
import { WebSocket, WebSocketServer } from 'ws';
import { db } from './db.js';
import { userFromCookieHeader } from './lib/auth.js';
import type { VoiceOption } from './types.js';

const home = os.homedir();
const trimSlash = (s: string) => s.replace(/\/+$/, '');

export const house = {
  road: (process.env.BILSKIRNIR_VOICE ?? 'house').trim().toLowerCase() === 'xai' ? 'xai' as const : 'house' as const,
  whisperCli: process.env.BILSKIRNIR_WHISPER_CLI ?? path.join(home, 'whisper.cpp.src/build/bin/whisper-cli'),
  whisperModel: process.env.BILSKIRNIR_WHISPER_MODEL ?? path.join(home, 'whisper.cpp/models/ggml-small.en.bin'),
  /** on = whisper may use the GPU (the house's dictation default); off = CPU only. */
  whisperGpu: (process.env.BILSKIRNIR_WHISPER_GPU ?? 'on') !== 'off',
  ffmpeg: process.env.BILSKIRNIR_FFMPEG ?? 'ffmpeg',
  kokoroUrl: trimSlash(process.env.BILSKIRNIR_KOKORO_URL ?? 'http://127.0.0.1:8765'),
  /** The user unit that keeps Kokoro resident; raised on demand when the mouth is asleep. Empty = never start it. */
  kokoroUnit: process.env.BILSKIRNIR_KOKORO_UNIT ?? 'kokoro-serve.service',
  defaultVoice: process.env.BILSKIRNIR_VOICE_DEFAULT ?? 'af_nicole',
  /** Rödd's realtime engine (OpenAI Realtime protocol). */
  realtimeUrl: process.env.BILSKIRNIR_REALTIME_URL ?? `ws://127.0.0.1:${process.env.YMIR_VOICE_PORT ?? 8890}/v1/realtime`,
};

/** The same-origin path the browser opens for a house call. */
export const HOUSE_REALTIME_PATH = '/api/voice/realtime';

// ---------- the mouth: Kokoro ----------

/** The voices Rödd offers Nanna — the fallback list when Kokoro is asleep (af/bf = woman, am/bm = man). */
const RODD_VOICES = ['af_nicole', 'af_sky', 'af_bella', 'am_michael', 'bf_emma'];

const ACCENT: Record<string, string> = { a: 'American', b: 'British', e: 'Spanish', f: 'French', h: 'Hindi', i: 'Italian', j: 'Japanese', p: 'Portuguese', z: 'Chinese' };

export function kokoroVoiceOption(id: string): VoiceOption {
  const m = /^([a-z])([fm])_(.+)$/.exec(id);
  if (!m) return { id, name: id };
  const who = m[2] === 'f' ? 'woman' : 'man';
  const name = m[3][0].toUpperCase() + m[3].slice(1);
  return { id, name: `${name} · ${ACCENT[m[1]] ?? m[1]}, ${who}`, gender: m[2] === 'f' ? 'female' : 'male' };
}

export const isKokoroVoice = (id: unknown) => typeof id === 'string' && /^[a-z][fm]_[a-z0-9]+$/.test(id);

async function kokoroHealthy(): Promise<boolean> {
  try {
    const r = await fetch(`${house.kokoroUrl}/health`, { signal: AbortSignal.timeout(1500) });
    return r.ok && ((await r.json()) as { status?: string }).status === 'ok';
  } catch {
    return false;
  }
}

let waking: Promise<boolean> | null = null;
/** Kokoro answers, raising its user unit once when it is asleep (it idles itself out). */
export async function kokoroAwake(): Promise<boolean> {
  if (await kokoroHealthy()) return true;
  if (!house.kokoroUnit) return false;
  waking ??= (async () => {
    await new Promise<void>((resolve) => {
      const p = spawn('systemctl', ['--user', 'start', house.kokoroUnit], { stdio: 'ignore' });
      p.on('error', () => resolve());
      p.on('exit', () => resolve());
    });
    for (let i = 0; i < 40; i++) {
      if (await kokoroHealthy()) return true;
      await new Promise((r) => setTimeout(r, 500));
    }
    return false;
  })().finally(() => { waking = null; });
  return waking;
}

let voiceCache: { at: number; voices: VoiceOption[] } | null = null;
export async function houseVoices(): Promise<VoiceOption[]> {
  if (voiceCache && Date.now() - voiceCache.at < 3600_000) return voiceCache.voices;
  let ids = RODD_VOICES;
  try {
    if (await kokoroHealthy()) {
      const r = await fetch(`${house.kokoroUrl}/voices`, { signal: AbortSignal.timeout(4000) });
      const j = (await r.json()) as { voices?: string[] } | string[];
      const got = (Array.isArray(j) ? j : j.voices ?? []).filter((v) => typeof v === 'string');
      // English voices only: the ear is whisper small.en, so the hall speaks English.
      const english = got.filter((v) => /^[ab][fm]_/.test(v));
      if (english.length) ids = [...RODD_VOICES.filter((v) => english.includes(v)), ...english.filter((v) => !RODD_VOICES.includes(v)).sort()];
      voiceCache = { at: Date.now(), voices: ids.map(kokoroVoiceOption) };
      return voiceCache.voices;
    }
  } catch { /* fall through to Rödd's list */ }
  return ids.map(kokoroVoiceOption); // not cached: the full list appears once Kokoro wakes
}

/** Parse a PCM16 WAV and return mono samples at `rate` Hz (Kokoro speaks 24 kHz; resampled if not). */
export function wavToPcm16(buf: Buffer, rate: number): Buffer {
  if (buf.toString('ascii', 0, 4) !== 'RIFF' || buf.toString('ascii', 8, 12) !== 'WAVE') throw new Error('not a WAV');
  let off = 12; let srcRate = rate; let channels = 1; let bits = 16;
  let data: Buffer | null = null;
  while (off + 8 <= buf.length) {
    const id = buf.toString('ascii', off, off + 4);
    const size = buf.readUInt32LE(off + 4);
    const body = off + 8;
    if (id === 'fmt ') { channels = buf.readUInt16LE(body + 2); srcRate = buf.readUInt32LE(body + 4); bits = buf.readUInt16LE(body + 14); }
    else if (id === 'data') { data = buf.subarray(body, Math.min(buf.length, body + size)); break; }
    off = body + size + (size & 1);
  }
  if (!data || bits !== 16) throw new Error('unsupported WAV');
  const frames = Math.floor(data.length / (2 * channels));
  const mono = new Int16Array(frames);
  for (let i = 0; i < frames; i++) mono[i] = data.readInt16LE(i * 2 * channels);
  if (srcRate === rate) return Buffer.from(mono.buffer, mono.byteOffset, mono.byteLength);
  const outLen = Math.floor((frames * rate) / srcRate);
  const out = new Int16Array(outLen);
  for (let i = 0; i < outLen; i++) {
    const x = (i * srcRate) / rate; const j = Math.floor(x); const f = x - j;
    out[i] = Math.round((mono[j] ?? 0) * (1 - f) + (mono[j + 1] ?? mono[j] ?? 0) * f);
  }
  return Buffer.from(out.buffer, out.byteOffset, out.byteLength);
}

/** Speak `text` in Kokoro's voice; returns PCM16 mono at `rate`. */
export async function kokoroSpeak(text: string, voice: string, speed: number, rate: number): Promise<Buffer> {
  if (!(await kokoroAwake())) throw new Error('The house voice (Kokoro) is not answering');
  const r = await fetch(`${house.kokoroUrl}/v1/audio/speech`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ input: text, voice: isKokoroVoice(voice) ? voice : house.defaultVoice, speed, response_format: 'wav' }),
    signal: AbortSignal.timeout(60_000),
  });
  if (!r.ok) throw new Error(`Kokoro answered ${r.status}: ${(await r.text().catch(() => '')).slice(0, 200)}`);
  return wavToPcm16(Buffer.from(await r.arrayBuffer()), rate);
}

// ---------- the ear: whisper.cpp ----------

function run(cmd: string, args: string[], input?: Buffer, timeoutMs = 90_000): Promise<{ code: number; out: string; err: string }> {
  return new Promise((resolve) => {
    const p = spawn(cmd, args, { stdio: ['pipe', 'pipe', 'pipe'] });
    let out = ''; let err = '';
    const t = setTimeout(() => p.kill('SIGKILL'), timeoutMs);
    p.stdout.on('data', (d) => { out += d; });
    p.stderr.on('data', (d) => { err += d; });
    p.on('error', (e) => { clearTimeout(t); resolve({ code: -1, out, err: String(e.message) }); });
    p.on('exit', (code) => { clearTimeout(t); resolve({ code: code ?? -1, out, err }); });
    p.stdin.on('error', () => {});
    if (input) p.stdin.end(input); else p.stdin.end();
  });
}

/** Transcribe a browser recording (webm/ogg/mp4) with the house's whisper.cpp. */
export async function whisperTranscribe(audio: Buffer, language?: string): Promise<string> {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bilskirnir-stt-'));
  const wav = path.join(dir, 'speech.wav');
  try {
    const conv = await run(house.ffmpeg, ['-hide_banner', '-loglevel', 'error', '-i', 'pipe:0', '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', '-y', wav], audio, 30_000);
    if (conv.code !== 0) throw new Error(`ffmpeg could not read the recording: ${conv.err.slice(0, 200)}`);
    const args = ['-m', house.whisperModel, '-f', wav, '-nt', '-np'];
    if (!house.whisperGpu) args.push('-ng');
    // An .en model only hears English; a multilingual model takes the hint.
    if (language && /^[a-z]{2}$/.test(language) && !/\.en\b/.test(house.whisperModel)) args.push('-l', language);
    const r = await run(house.whisperCli, args);
    if (r.code !== 0) throw new Error(`whisper failed: ${r.err.slice(-200)}`);
    return r.out
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l && !/^\[(BLANK_AUDIO|MUSIC|NOISE|SILENCE)\]$/i.test(l))
      .join(' ')
      .replace(/\s+/g, ' ')
      .trim();
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

// ---------- the call: Rödd's realtime engine ----------

const httpBase = () => house.realtimeUrl.replace(/^ws/, 'http').replace(/\/v1\/realtime.*$/, '');

/** Whether Rödd's engine answers, and how many of its session slots are free. */
export async function realtimeStatus(): Promise<{ up: boolean; free?: number; total?: number; detail?: string }> {
  try {
    const r = await fetch(`${httpBase()}/v1/pool`, { signal: AbortSignal.timeout(2000) });
    if (!r.ok) return { up: true, detail: `pool answered ${r.status}` };
    // speech-to-speech v1.1.0: { size, in_use, units: [{ index, state, session_id }] }
    const j = (await r.json()) as { size?: number; in_use?: number };
    const total = Number(j.size ?? 0);
    return { up: true, total, free: Math.max(0, total - Number(j.in_use ?? 0)) };
  } catch (e: any) {
    return { up: false, detail: e?.cause?.code ?? e?.message ?? 'no answer' };
  }
}

export async function houseStatus() {
  const [kokoro, realtime] = await Promise.all([kokoroHealthy(), realtimeStatus()]);
  return {
    road: house.road,
    ear: { whisper: fs.existsSync(house.whisperCli), model: fs.existsSync(house.whisperModel) },
    mouth: { kokoro, url: house.kokoroUrl, unit: house.kokoroUnit || null },
    call: realtime,
  };
}

/** Relay browser <-> Rödd's engine at HOUSE_REALTIME_PATH, for a signed-in user calling their own bot. */
export function attachHouseRealtime(server: Server) {
  const wss = new WebSocketServer({ noServer: true });
  server.on('upgrade', (req: IncomingMessage, socket, head) => {
    const url = new URL(req.url ?? '/', 'http://x');
    if (url.pathname !== HOUSE_REALTIME_PATH) return; // not ours
    const user = userFromCookieHeader(req.headers.cookie);
    const botId = url.searchParams.get('bot') ?? '';
    const bot = user ? db.prepare('SELECT id FROM bots WHERE id=? AND user_id=?').get(botId, user.id) : null;
    if (!user || !bot || house.road !== 'house') {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, (client) => relayHouseRealtime(client));
  });
}

/** Exported for the test (tests/house-voice.mts); the server reaches it only through attachHouseRealtime. */
export function relayHouseRealtime(client: WebSocket) {
  const upstream = new WebSocket(house.realtimeUrl, ['realtime']);
  const early: (string | Buffer)[] = [];
  const closeBoth = (code = 1000, reason = '') => {
    const c = code >= 1000 && code < 5000 && code !== 1005 && code !== 1006 ? code : 1011;
    try { if (client.readyState === WebSocket.OPEN) client.close(c, reason.slice(0, 120)); } catch { /* ignore */ }
    try { if (upstream.readyState === WebSocket.OPEN || upstream.readyState === WebSocket.CONNECTING) upstream.terminate(); } catch { /* ignore */ }
  };
  client.on('message', (data, isBinary) => {
    const msg = isBinary ? (data as Buffer) : data.toString();
    if (upstream.readyState === WebSocket.OPEN) upstream.send(msg);
    else if (early.length < 512) early.push(msg);
  });
  upstream.on('open', () => { for (const m of early.splice(0)) upstream.send(m); });
  upstream.on('message', (data, isBinary) => {
    if (client.readyState === WebSocket.OPEN) client.send(isBinary ? data : data.toString());
  });
  upstream.on('error', (e) => {
    console.warn('[voice] house realtime unreachable:', e.message);
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify({ type: 'error', error: { type: 'house_voice_down', message: 'The house voice is not raised. Run: bin/voice/voice-door.sh host' } }));
    }
    closeBoth(1011, 'house voice unreachable');
  });
  upstream.on('close', (code, reason) => closeBoth(code, reason.toString()));
  client.on('close', () => closeBoth());
  client.on('error', () => closeBoth());
}
