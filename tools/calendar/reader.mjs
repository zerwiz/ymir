#!/usr/bin/env node
// reader.mjs — Mánagandr, the reckoning: the ONE reader of the Allfather's calendar.
//
// The subsystem is Mánagandr, the Old Norse month-reckoner. In code the id is
// ASCII (`managandr`); the label keeps the Norse. This module is the single
// implementation behind every door: the mesh face (`tools/calendar/server.mjs`),
// the shell door (`bin/calendar-ask.sh`) and the high seat (the gate API). Any
// second place that talks to Google is a design that has already failed.
//
// READ-ONLY, as a hard boundary. There is no create, update, delete, move or
// invite verb here, and no way to express one: the capability is ABSENT, not
// gated by a flag. A calendar that can rewrite the Allfather's day can lose a
// meeting.
//
// What it does, in order:
//   1. resolve the vault/home through the one resolver's discipline
//   2. refresh the OAuth grant from the vault key (never a build input)
//   3. fetch a bounded window (default ±6 weeks — the month grid's neighbour weeks)
//   4. normalise the events (all-day, multi-day, tz-offset, cancelled)
//   5. write ONE rolling cache under <home>/hodd/state/calendar/cache.json
//   6. return the normalised set, carrying an `as_of` on every path
//
// UNKNOWN IS NOT EMPTY. When the reader cannot produce data it says so with a
// named reason (`no_oauth_grant`, `no_oauth_client`, `fetch_failed`) and an
// explicit `status:"unknown"` — never a silent empty list a caller could mistake
// for a free day. `node --check` clean. Never logs a title, attendee or location.
//
// Env (the snotra shape, one documented default each):
//   PORT                        the mesh door's port (reserved; this reader binds none)
//   MANAGANDR_VAULT             the vault root; else YMIR_HOME; else the recorded
//                               choice (<config>/ymir/home); else ~/Documents/ymirhome
//   MANAGANDR_OAUTH_KEY         the NAME of the vault key holding the refresh token
//                               (default MANAGANDR_OAUTH_REFRESH_TOKEN)
//   MANAGANDR_CALENDAR_ID       which calendar to read (default "primary")
//   MANAGANDR_CLIENT_ID/SECRET  the OAuth app credentials (else HEIMDALL_OAUTH_*)
//   MANAGANDR_CACHE / _CACHE_DIR / _CACHE_TTL_SECONDS
//   MANAGANDR_TZ                the machine's zone for all-day math (else the OS zone)
//   MANAGANDR_FIXTURE           a synthetic Google events.list response (offline tests)
//   MANAGANDR_NOW               fix "now" (deterministic tests)
// Run:  node tools/calendar/reader.mjs --window 6w --json
//       node tools/calendar/reader.mjs --ask busy --fixture <file> --cache <file>

import { z } from "zod";
import { readFileSync, realpathSync } from "node:fs";
import { readFile, writeFile, mkdir, rename } from "node:fs/promises";
import { join, dirname } from "node:path";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";

const DEFAULT_WINDOW = "6w";
const DEFAULT_CALENDAR_ID = "primary";
const DEFAULT_CACHE_TTL_SECONDS = 600;
const DEFAULT_PORT = 8323;
const DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";
const DEFAULT_API_BASE = "https://www.googleapis.com/calendar/v3";
const DEFAULT_REFRESH_TOKEN_KEY = "MANAGANDR_OAUTH_REFRESH_TOKEN";

// The normalised event — what every door consumes. `start_ms`/`end_ms` are the
// absolute instants used for busy math; `start`/`end` keep their original form
// (an all-day date, or an RFC3339 with its offset). Attendees are a COUNT only:
// the list is never read, never cached, never drawn.
export const EventSchema = z.object({
  id: z.string(),
  calendar_id: z.string(),
  status: z.enum(["confirmed", "tentative", "cancelled"]),
  busy: z.boolean(),
  all_day: z.boolean(),
  summary: z.string(),
  location: z.string(),
  attendee_count: z.number().int().nonnegative(),
  start: z.string(),
  end: z.string(),
  start_ms: z.number().int(),
  end_ms: z.number().int(),
  transparency: z.enum(["opaque", "transparent"]),
  html_link: z.string(),
  recurring_id: z.string()
});

export const WindowSchema = z.object({
  start: z.string(),
  end: z.string(),
  label: z.string(),
  radius_ms: z.number().int()
});

export const ResultSchema = z.object({
  kind: z.literal("managandr"),
  status: z.enum(["ok", "stale", "unknown"]),
  as_of: z.string().nullable(),
  checked_at: z.string().nullable(),
  source: z.enum(["google", "cache", "fixture", "none"]),
  stale: z.boolean(),
  reason: z.string().nullable(),
  missing: z.string().nullable(),
  detail: z.string().nullable(),
  calendar_id: z.string(),
  window: WindowSchema.nullable(),
  count: z.number().int().nonnegative(),
  events: z.array(EventSchema)
});

// --- the resolver, mirrored from bin/hoard-lib.sh ---------------------------
// One resolver, one default. The shell door resolves the home with the bash
// resolver and passes it as MANAGANDR_VAULT; standalone, this mirrors that same
// order so the two can never disagree about where the home is (Rule 07).
export function resolveHome(env = process.env) {
  if (env.MANAGANDR_VAULT) return env.MANAGANDR_VAULT;
  if (env.YMIR_HOME) return env.YMIR_HOME;
  const cfgDir = env.YMIR_CONFIG_DIR || join(env.XDG_CONFIG_HOME || join(homedir(), ".config"), "ymir");
  try {
    const recorded = readFileSync(join(cfgDir, "home"), "utf8").split("\n")[0].trim();
    if (recorded) return recorded;
  } catch { /* no recorded choice */ }
  return join(homedir(), "Documents", "ymirhome"); // the one documented default
}

export function resolveConfig(env = process.env) {
  const home = resolveHome(env);
  const cacheDir = env.MANAGANDR_CACHE_DIR || join(home, "hodd", "state", "calendar");
  const refreshTokenKey = env.MANAGANDR_OAUTH_KEY || DEFAULT_REFRESH_TOKEN_KEY;
  return {
    home,
    cacheDir,
    cachePath: env.MANAGANDR_CACHE || join(cacheDir, "cache.json"),
    // Whether the cache path was NAMED. A named path may hold a fixture; the
    // canonical one may not.
    cacheExplicit: env.MANAGANDR_CACHE != null && env.MANAGANDR_CACHE !== "",
    calendarId: env.MANAGANDR_CALENDAR_ID || DEFAULT_CALENDAR_ID,
    clientId: env.MANAGANDR_CLIENT_ID || env.HEIMDALL_OAUTH_CLIENT_ID || "",
    clientSecret: env.MANAGANDR_CLIENT_SECRET || env.HEIMDALL_OAUTH_CLIENT_SECRET || "",
    refreshTokenKey,
    refreshToken: env[refreshTokenKey] || "",
    tokenUri: env.MANAGANDR_TOKEN_URI || DEFAULT_TOKEN_URI,
    apiBase: env.MANAGANDR_API_BASE || DEFAULT_API_BASE,
    ttlSeconds: Number(env.MANAGANDR_CACHE_TTL_SECONDS || DEFAULT_CACHE_TTL_SECONDS),
    zone: env.MANAGANDR_TZ || Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC",
    fixture: env.MANAGANDR_FIXTURE || "",
    now: env.MANAGANDR_NOW || "",
    port: Number(env.PORT || DEFAULT_PORT)
  };
}

// --- the window (±6 weeks by default) ---------------------------------------
export function parseWindow(spec, now = new Date()) {
  const raw = String(spec || DEFAULT_WINDOW).trim();
  const ISO = /^(\d{4}-\d{2}-\d{2}T[^\.]*Z?|\d{4}-\d{2}-\d{2})\.\.(\d{4}-\d{2}-\d{2}T[^\.]*Z?|\d{4}-\d{2}-\d{2})$/;
  const m = raw.match(ISO);
  if (m) {
    const start = new Date(m[1]);
    const end = new Date(m[2]);
    return { start, end, label: raw, radius_ms: Math.round((end - start) / 2) };
  }
  const unit = raw.slice(-1).toLowerCase();
  const n = Number(raw.slice(0, -1));
  if (!Number.isFinite(n) || n <= 0) {
    throw new Error(`window: cannot parse "${raw}" (want 6w, 7d, 12h, or ISO..ISO)`);
  }
  const step = unit === "w" ? 7 * 864e5 : unit === "d" ? 864e5 : unit === "h" ? 36e5 : NaN;
  if (!Number.isFinite(step)) throw new Error(`window: unknown unit in "${raw}" (want w, d or h)`);
  const radius = n * step;
  return {
    start: new Date(now.getTime() - radius),
    end: new Date(now.getTime() + radius),
    label: raw,
    radius_ms: radius
  };
}

export function windowMeta(w) {
  return { start: w.start.toISOString(), end: w.end.toISOString(), label: w.label, radius_ms: w.radius_ms };
}

// --- timezone math (the machine's zone, never an assumed UTC) ---------------
function tzOffsetMs(zone, utcMs) {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: zone, hourCycle: "h23",
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit"
  });
  const p = {};
  for (const part of dtf.formatToParts(new Date(utcMs))) p[part.type] = part.value;
  const asUTC = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second);
  return asUTC - utcMs;
}

function zonedToUtc(zone, y, mo, d, h, mi, s) {
  const wall = Date.UTC(y, mo - 1, d, h, mi, s);
  let utc = wall - tzOffsetMs(zone, wall);
  utc = wall - tzOffsetMs(zone, utc);
  return utc;
}

function parseYmd(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s || "");
  if (!m) throw new Error(`bad date "${s}"`);
  return [+m[1], +m[2], +m[3]];
}

function hasOffset(s) {
  return /[zZ]$|[+-]\d{2}:?\d{2}$/.test(s || "");
}

function dateTimeToMs(s, zone) {
  if (hasOffset(s)) {
    const t = Date.parse(s);
    if (!Number.isNaN(t)) return t;
  }
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?/.exec(s || "");
  if (m) return zonedToUtc(zone, +m[1], +m[2], +m[3], +m[4], +m[5], +(m[6] || 0));
  const t = Date.parse(s);
  if (Number.isNaN(t)) throw new Error(`bad dateTime "${s}"`);
  return t;
}

// --- normalisation ----------------------------------------------------------
export function normalizeEvent(raw, calendarId, zone) {
  const allDay = !!(raw.start && raw.start.date);
  let start, end, startMs, endMs;
  if (allDay) {
    start = raw.start.date;
    end = (raw.end && raw.end.date) || raw.start.date;
    const [sy, sm, sd] = parseYmd(start);
    const [ey, em, ed] = parseYmd(end);
    startMs = zonedToUtc(zone, sy, sm, sd, 0, 0, 0);
    endMs = zonedToUtc(zone, ey, em, ed, 0, 0, 0);
  } else {
    start = (raw.start && (raw.start.dateTime || raw.start.date)) || "";
    end = (raw.end && (raw.end.dateTime || raw.end.date)) || start;
    startMs = dateTimeToMs(start, (raw.start && raw.start.timeZone) || zone);
    endMs = dateTimeToMs(end, (raw.end && raw.end.timeZone) || zone);
  }
  const status = raw.status || "confirmed";
  const transparency = raw.transparency === "transparent" ? "transparent" : "opaque";
  const busy = status !== "cancelled" && transparency !== "transparent" && endMs > startMs;
  return {
    id: raw.id || "",
    calendar_id: calendarId,
    status: status === "tentative" || status === "cancelled" ? status : "confirmed",
    busy,
    all_day: allDay,
    summary: raw.summary || "",
    location: raw.location || "",
    attendee_count: Array.isArray(raw.attendees) ? raw.attendees.length : 0,
    start,
    end,
    start_ms: startMs,
    end_ms: endMs,
    transparency,
    html_link: raw.htmlLink || "",
    recurring_id: raw.recurringEventId || ""
  };
}

export function normalizeEvents(items, calendarId, zone) {
  return (items || []).map((it) => normalizeEvent(it, calendarId, zone));
}

// --- busy math --------------------------------------------------------------
export function isBusyAt(events, instantMs) {
  return events.some((e) => e.busy && instantMs >= e.start_ms && instantMs < e.end_ms);
}

export function busyInWindow(events, startMs, endMs) {
  return events.some((e) => e.busy && e.start_ms < endMs && e.end_ms > startMs);
}

// --- the grant, the fetch (network; never entered by a test) ----------------
export async function refreshGrant(cfg, fetchImpl = fetch) {
  const body = new URLSearchParams({
    client_id: cfg.clientId,
    client_secret: cfg.clientSecret,
    refresh_token: cfg.refreshToken,
    grant_type: "refresh_token"
  });
  const res = await fetchImpl(cfg.tokenUri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body
  });
  if (!res.ok) throw new Error(`token endpoint refused (HTTP ${res.status})`);
  const json = await res.json();
  if (!json.access_token) throw new Error("token endpoint returned no access_token");
  return json.access_token;
}

export async function fetchEvents(cfg, accessToken, window, fetchImpl = fetch) {
  const url = new URL(`${cfg.apiBase}/calendars/${encodeURIComponent(cfg.calendarId)}/events`);
  url.searchParams.set("timeMin", window.start.toISOString());
  url.searchParams.set("timeMax", window.end.toISOString());
  url.searchParams.set("singleEvents", "true");
  url.searchParams.set("orderBy", "startTime");
  url.searchParams.set("showDeleted", "true");
  url.searchParams.set("maxResults", "2500");
  const res = await fetchImpl(url, { headers: { authorization: `Bearer ${accessToken}` } });
  if (!res.ok) throw new Error(`calendar api refused (HTTP ${res.status})`);
  return await res.json();
}

// --- the cache (the hoard state; never the tree) ----------------------------
export async function readCache(cachePath) {
  try {
    return JSON.parse(await readFile(cachePath, "utf8"));
  } catch {
    return null;
  }
}

export async function writeCache(cachePath, payload) {
  await mkdir(dirname(cachePath), { recursive: true });
  const tmp = `${cachePath}.tmp-${process.pid}`;
  await writeFile(tmp, JSON.stringify(payload, null, 2));
  await rename(tmp, cachePath);
  return cachePath;
}

function cacheIsFresh(cache, now, ttlSeconds) {
  if (!cache || !cache.as_of) return false;
  const age = now.getTime() - Date.parse(cache.as_of);
  return Number.isFinite(age) && age >= 0 && age <= ttlSeconds * 1000;
}

function result(base) {
  return ResultSchema.parse({
    kind: "managandr",
    stale: false,
    reason: null,
    missing: null,
    detail: null,
    checked_at: null,
    window: null,
    count: 0,
    events: [],
    ...base
  });
}

// A payload (cache or fresh fetch) already carries NORMALISED events; parse them
// back through the schema rather than re-normalising a Google shape that is no
// longer there.
function fromPayload(payload, { status, source, reason = null, missing = null, detail = null, checked_at = null }) {
  const events = (payload.events || []).map((e) => EventSchema.parse(e));
  return result({
    status,
    as_of: payload.as_of || null,
    checked_at,
    source,
    stale: status === "stale",
    reason,
    missing,
    detail,
    calendar_id: payload.calendar_id || "",
    window: payload.window || null,
    count: events.length,
    events
  });
}

// --- the reader -------------------------------------------------------------
// Returns a Result. Never throws for a missing grant or a vendor failure: those
// are named, returned states, because a door must be able to say "unknown".
export async function readCalendar(opts = {}) {
  const env = opts.env || process.env;
  const cfg = resolveConfig(env);
  const now = opts.now ? new Date(opts.now) : (cfg.now ? new Date(cfg.now) : new Date());
  if (Number.isNaN(now.getTime())) throw new Error(`bad now: ${opts.now || cfg.now}`);
  const window = parseWindow(opts.window || DEFAULT_WINDOW, now);
  const cachePath = opts.cachePath || cfg.cachePath;
  const fixture = opts.fixture != null ? opts.fixture : cfg.fixture;
  const forceRefresh = !!opts.refresh;
  const checkedAt = now.toISOString();

  // Fixture mode: a synthetic Google events.list response, offline, no grant.
  if (fixture) {
    const raw = JSON.parse(await readFile(fixture, "utf8"));
    const events = normalizeEvents(raw.items || [], cfg.calendarId, cfg.zone);
    const payload = {
      as_of: now.toISOString(), window: windowMeta(window),
      calendar_id: cfg.calendarId, zone: cfg.zone, source: "fixture", events
    };
    // A fixture may only ever write a cache the CALLER named. Writing invented
    // events into the hoard's rolling cache makes the control plane serve
    // "Invented All-Day Gathering" as if it were the Allfather's real diary —
    // and it happened (2026-09-30 20:30, from a probe that omitted --cache).
    // The canonical path is the one the HALL reads, so it takes a real read.
    if (opts.cachePath == null && !cfg.cacheExplicit) {
      throw new Error(
        "refusing to write fixture data to the canonical cache " +
          `${cachePath} — pass --cache <path> to write a fixture somewhere private`
      );
    }
    await writeCache(cachePath, payload);
    return fromPayload(payload, { status: "ok", source: "fixture", checked_at: checkedAt });
  }

  const cached = await readCache(cachePath);
  if (!forceRefresh && cacheIsFresh(cached, now, cfg.ttlSeconds)) {
    return fromPayload(cached, { status: "ok", source: "cache", checked_at: checkedAt });
  }

  const missing = [];
  if (!cfg.refreshToken) missing.push(cfg.refreshTokenKey);
  if (!cfg.clientId) missing.push("MANAGANDR_CLIENT_ID");
  if (!cfg.clientSecret) missing.push("MANAGANDR_CLIENT_SECRET");
  if (missing.length) {
    const reason = !cfg.refreshToken ? "no_oauth_grant" : "no_oauth_client";
    if (cached) {
      return fromPayload(cached, { status: "stale", source: "cache", reason, missing: missing.join(","), checked_at: checkedAt });
    }
    return result({
      status: "unknown", as_of: null, checked_at: checkedAt, source: "none", reason,
      missing: missing.join(","), calendar_id: cfg.calendarId, window: windowMeta(window)
    });
  }

  try {
    const token = await refreshGrant(cfg);
    const raw = await fetchEvents(cfg, token, window);
    const events = normalizeEvents(raw.items || [], cfg.calendarId, cfg.zone);
    const payload = {
      as_of: now.toISOString(), window: windowMeta(window),
      calendar_id: cfg.calendarId, zone: cfg.zone, source: "google", events
    };
    await writeCache(cachePath, payload);
    return fromPayload(payload, { status: "ok", source: "google", checked_at: checkedAt });
  } catch (e) {
    const detail = String((e && e.message) || e);
    if (cached) {
      return fromPayload(cached, { status: "stale", source: "cache", reason: "fetch_failed", detail, checked_at: checkedAt });
    }
    return result({
      status: "unknown", as_of: null, checked_at: checkedAt, source: "none", reason: "fetch_failed",
      detail, calendar_id: cfg.calendarId, window: windowMeta(window)
    });
  }
}

// --- the CLI ----------------------------------------------------------------
function parseArgs(argv) {
  const out = { window: DEFAULT_WINDOW, windowGiven: false, now: "", refresh: false, fixture: null, cache: null, ask: null, probe: false, titles: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case "--window": case "-w": out.window = argv[++i]; out.windowGiven = true; break;
      case "--now": out.now = argv[++i]; break;
      case "--refresh": case "-r": out.refresh = true; break;
      case "--fixture": out.fixture = argv[++i]; break;
      case "--cache": out.cachePath = argv[++i]; break;
      case "--ask": out.ask = argv[++i]; break;
      case "--probe": out.probe = true; break;
      case "--titles": out.titles = true; break;
      case "--json": break; // default output
      case "--help": case "-h": out.help = true; break;
      default:
        if (a.startsWith("-")) throw new Error(`unknown flag ${a}`);
    }
  }
  return out;
}

const EXIT_FREE = 0;
const EXIT_BUSY = 10;
const EXIT_UNKNOWN = 20;

function probePayload(res, titles) {
  const body = {
    status: res.status,
    as_of: res.as_of,
    checked_at: res.checked_at,
    calendar_id: res.calendar_id,
    source: res.source,
    count: res.count,
    reason: res.reason,
    missing: res.missing,
    window: res.window
  };
  if (titles) {
    body.next = res.events.slice(0, 3).map((e) => ({ title: e.summary, start: e.start }));
  }
  return body;
}

async function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (e) {
    process.stderr.write(`managandr: ${e.message}\n`);
    process.exit(2);
  }
  if (args.help) {
    process.stdout.write("managandr reader — node tools/calendar/reader.mjs [--window 6w] [--refresh] [--fixture FILE] [--cache FILE] [--ask busy|free] [--probe [--titles]] [--json]\n");
    process.exit(0);
  }
  try {
    const res = await readCalendar({
      window: args.window,
      now: args.now || undefined,
      refresh: args.refresh,
      fixture: args.fixture,
      cachePath: args.cachePath || undefined
    });
    if (args.ask) {
      const now = args.now ? new Date(args.now) : new Date();
      // An ask is a POINT at "now" unless a window was named: "am I busy now?"
      const w = args.windowGiven
        ? parseWindow(args.window, now)
        : { start: now, end: now, label: "now", radius_ms: 0 };
      const busy = res.status === "unknown" ? null : busyInWindow(res.events, w.start.getTime(), w.end.getTime());
      const token = busy === null ? "unknown" : busy ? "busy" : "free";
      process.stdout.write(`${token}\n`);
      process.stderr.write(`managandr: ${token} status=${res.status} as_of=${res.as_of || "none"} checked_at=${res.checked_at || "none"}${res.reason ? ` reason=${res.reason}` : ""}\n`);
      process.exit(token === "unknown" ? EXIT_UNKNOWN : token === "busy" ? EXIT_BUSY : EXIT_FREE);
    }
    if (args.probe) {
      process.stdout.write(`${JSON.stringify(probePayload(res, args.titles), null, 2)}\n`);
      process.exit(res.status === "unknown" ? EXIT_UNKNOWN : 0);
    }
    process.stdout.write(`${JSON.stringify(res, null, 2)}\n`);
    process.exit(res.status === "unknown" ? EXIT_UNKNOWN : 0);
  } catch (e) {
    process.stderr.write(`managandr: ${(e && e.message) || e}\n`);
    process.exit(2);
  }
}

let invoked = "";
try { invoked = process.argv[1] ? realpathSync(process.argv[1]) : ""; } catch { invoked = ""; }
if (invoked && invoked === fileURLToPath(import.meta.url)) main();
