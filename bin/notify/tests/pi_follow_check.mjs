// pi_follow_check — the pi extension against a stand-in pi and a stand-in door. Run by test_telegram_reader.sh.
import assert from "node:assert/strict";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [source, tmp] = process.argv.slice(2);
const fake = join(tmp, "fake-root");
mkdirSync(join(fake, "bin", "notify"), { recursive: true });
const answer = (code) => writeFileSync(join(fake, "bin", "notify", "telegram-reader.sh"), `exit ${code}\n`);
const machine = join(tmp, "xdg", "ymir");
mkdirSync(machine, { recursive: true });
const holder = (pid) => writeFileSync(join(machine, "brokk.lock"), `${pid}\n`);

Object.assign(process.env, { YMIR_ROOT: fake, XDG_STATE_HOME: join(tmp, "xdg"), BROKK_MACHINE_STATE_DIR: machine, YMIR_TELEGRAM_FOLLOW_MS: "50" });
const { default: extension } = await import(pathToFileURL(source));

async function run({ owner, code, commands = ["telegram-connect"], idle = true }) {
  answer(code);
  holder(owner);
  const sent = [];
  const on = {};
  extension({
    on: (name, fn) => (on[name] = fn),
    getCommands: () => commands.map((name) => ({ name })),
    sendUserMessage: (text, options) => sent.push([text, options]),
  });
  await on.session_start({}, { isIdle: () => idle });
  await new Promise((done) => setTimeout(done, 400));
  await on.session_shutdown();
  return sent;
}

assert.deepEqual(await run({ owner: process.pid, code: 0 }), [["/telegram-connect", { expandPromptTemplates: true }]]);
assert.deepEqual(await run({ owner: 1, code: 0 }), [], "not the holder");
assert.deepEqual(await run({ owner: process.pid, code: 1 }), [], "the door says no");
assert.deepEqual(await run({ owner: process.pid, code: 0, commands: [] }), [], "no command registered");
assert.deepEqual(await run({ owner: process.pid, code: 0, idle: false }), [], "busy session");
process.exit(0);
