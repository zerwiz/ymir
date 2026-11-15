// chat-ladder.test.ts — the proof for plan 275 item 23: a chat whose big model cannot load
// falls to one that fits, says which answered, and calls the real fault by its name.
//
// Measured 2026-11-14 03:16: `cudaMalloc of 1,184 MiB` failed while Rödd's voice engine held
// 2,762 MiB, and the operator was shown a bare 500. These are the four things that must now
// be true, proved as pure functions so no server, card or model is needed.
//
//   node --test apps/hlidskjalf/server/chat-ladder.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  answeredNote,
  chatLadder,
  fitsTargets,
  noAnswerMessage,
  vramStarved,
  type CatalogEntry,
} from './chat-ladder.ts';

const big: CatalogEntry = {
  id: 'llama-swap/qwen3.6-35b-a3b',
  name: 'qwen3.6-35b-a3b@q4_k_xl-mtp',
  provider: 'llama-swap',
  base: 'http://127.0.0.1:8080/v1',
  model: 'qwen3.6-35b-a3b@q4_k_xl-mtp',
  label: 'qwen3.6-35b-a3b@q4_k_xl-mtp',
  kind: 'local',
};
const small: CatalogEntry = {
  id: 'llama-swap/qwen3.5-9b',
  name: 'qwen3.5-9b@q4_k_s-summarizer',
  provider: 'llama-swap',
  base: 'http://127.0.0.1:8080/v1',
  model: 'qwen3.5-9b@q4_k_s-summarizer',
  label: 'qwen3.5-9b@q4_k_s-summarizer',
  kind: 'local',
};
const online: CatalogEntry = {
  id: 'opencode-go/deepseek-v4.1-flash',
  name: 'deepseek-v4.1-flash',
  provider: 'opencode-go',
  base: 'http://127.0.0.1:4603/v1',
  model: 'opencode-go/deepseek-v4.1-flash',
  label: 'deepseek-v4.1-flash',
  kind: 'online',
};

describe('the rail says the card is full', () => {
  test('llama.cpp and CUDA out-of-memory words are recognised', () => {
    assert.equal(vramStarved('llama runner: cudaMalloc failed: out of memory'), true);
    assert.equal(vramStarved('CUDA error: out of memory'), true);
    assert.equal(vramStarved('failed to allocate 1184 MiB'), true);
  });
  test('an ordinary provider error is not mistaken for a full card', () => {
    assert.equal(vramStarved('{"error":{"message":"model not found"}}'), false);
    assert.equal(vramStarved('401 Unauthorized'), false);
    assert.equal(vramStarved(''), false);
  });
});

describe('the ladder falls to a model that fits', () => {
  test('the small local preset comes first, then the online road', () => {
    const fits = fitsTargets([big, small, online], {
      fitsModel: 'qwen3.5-9b@q4_k_s-summarizer',
      exclude: [big],
    });
    assert.deepEqual(fits.map((t) => `${t.kind}:${t.model}`), [
      'local:qwen3.5-9b@q4_k_s-summarizer',
      'online:opencode-go/deepseek-v4.1-flash',
    ]);
  });
  test('the model already tried is never retried', () => {
    const fits = fitsTargets([big], { fitsModel: big.model, exclude: [big] });
    assert.deepEqual(fits, []);
  });
  test('a seat with no small preset still has the online road', () => {
    const fits = fitsTargets([online], { fitsModel: 'absent-model' });
    assert.equal(fits.length, 1);
    assert.equal(fits[0].kind, 'online');
  });
  test('the ladder keeps the asked-for model first and repeats nothing', () => {
    const ladder = chatLadder([big], fitsTargets([big, small, online], {
      fitsModel: small.model,
      exclude: [big],
    }));
    assert.deepEqual(ladder.map((t) => t.model), [big.model, small.model, online.model]);
    const twice = chatLadder([big], [{ base: big.base, model: big.model, label: big.label, kind: 'local' }]);
    assert.equal(twice.length, 1);
  });
});

describe('the chat says which model answered, and why', () => {
  test('a fallback answer names the model and the voice holding the card', () => {
    const note = answeredNote(big.model, small, { starved: true, voiceMib: 2762 });
    assert.match(note, /Answered by qwen3\.5-9b@q4_k_s-summarizer/);
    assert.match(note, /qwen3\.6-35b-a3b@q4_k_xl-mtp/);
    assert.match(note, /the card is busy with the voice \(2,762 MiB/);
  });
  test('an online fallback on a full card says the local card could not serve it', () => {
    const note = answeredNote(big.model, online, { starved: false });
    assert.match(note, /deepseek-v4\.1-flash/);
    assert.match(note, /the local card could not serve it/);
  });
});

describe('when nothing can load, the fault is named — never a bare 500', () => {
  test('the voice holding the card is what the operator is told', () => {
    const msg = noAnswerMessage('http://127.0.0.1:8080/v1 → 500 (out of memory on the card)', {
      starved: true,
      voiceMib: 2762,
      totalMib: 16384,
      asked: big.model,
    });
    assert.match(msg, /^The card is busy with the voice/);
    assert.match(msg, /2,762 MiB/);
    assert.match(msg, /of the 16,384 MiB card/);
    assert.match(msg, /voice-idle/);
    assert.doesNotMatch(msg, /no model backend answered/);
  });
  test('a full card with no voice says exactly that', () => {
    const msg = noAnswerMessage('8080 → 500', { starved: true, voiceMib: 0, asked: big.model });
    assert.match(msg, /The card is full/);
    assert.match(msg, /out of memory/);
  });
  test('a real outage keeps the honest message, status and all', () => {
    const msg = noAnswerMessage('http://127.0.0.1:4603/v1 → 500', { starved: false });
    assert.match(msg, /no model backend answered \(http:\/\/127\.0\.0\.1:4603\/v1 → 500\)/);
    assert.doesNotMatch(msg, /busy with the voice/);
  });
});
