/**
 * The wall, said in words a person can act on.
 *
 * The rail is a metered cloud model. When its usage limit is reached it answers
 * `429` and — depending on the rail — says when the meter resets. Until now the
 * bridge passed that through as `Upstream returned 429: {...}`, and the panel
 * showed a bare "error": a person cannot tell a rate limit from a broken service,
 * cannot tell when to try again, and reasonably concludes the board is broken.
 *
 * This module turns that answer into ONE sentence that names the wall and the
 * time it falls. It is a reading of what the rail said, never a guess: when the
 * rail does not say when it resets, the sentence says exactly that.
 *
 * `plan 233 §16 — the wall is shown`.
 */

/** Header names rails actually use for "when may you ask again". */
const RETRY_HEADERS = [
  "retry-after",
  "x-ratelimit-reset-requests",
  "x-ratelimit-reset-tokens",
  "x-ratelimit-reset",
  "ratelimit-reset",
];

/**
 * Reads a duration the way rails write one: `30`, `30s`, `2m`, `1h30m`, `6m0s`,
 * `1.5s`, `2h`, `120ms`. Returns milliseconds, or `null` when it is not a
 * duration at all (a bare big number is an epoch second and is handled by the
 * caller). This is deliberately local parsing: no dependency, no assumption.
 */
export const parseDuration = (value) => {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  const text = String(value ?? "").trim().toLowerCase();
  if (text === "") {
    return null;
  }
  if (/^\d+(\.\d+)?$/.test(text)) {
    // A bare number is seconds in `retry-after`, and an epoch when it is big.
    const n = Number(text);
    return n > 1e9 ? { epochSeconds: n } : n * 1000;
  }
  const units = { ms: 1, s: 1000, m: 60_000, h: 3_600_000, d: 86_400_000 };
  let total = 0;
  let matched = false;
  const pattern = /(\d+(?:\.\d+)?)\s*(ms|s|m|h|d)/g;
  let match;
  while ((match = pattern.exec(text)) !== null) {
    matched = true;
    total += Number(match[1]) * units[match[2]];
  }
  if (!matched) {
    return null;
  }
  return Math.round(total);
};

/** "2 hours 15 minutes", "6 minutes", "under a minute" — spoken, not ISO. */
export const humanDuration = (ms) => {
  if (!Number.isFinite(ms) || ms <= 0) {
    return "under a minute";
  }
  const minutes = Math.round(ms / 60_000);
  if (minutes < 1) {
    return "under a minute";
  }
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  const parts = [];
  if (hours > 0) {
    parts.push(`${hours} hour${hours === 1 ? "" : "s"}`);
  }
  if (rest > 0) {
    parts.push(`${rest} minute${rest === 1 ? "" : "s"}`);
  }
  return parts.join(" ");
};

/** A clock time in the reader's own words, e.g. "02:25". */
export const clockOf = (ms) => {
  const date = new Date(ms);
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
};

/**
 * Whether a rail's answer is the usage wall rather than a fault.
 *
 * A `429` is the wall. A `403`/`400` whose text says quota or credit is the wall
 * wearing another status — several rails do exactly that — so the body is read
 * too, with a narrow vocabulary that will not mistake a validation error for it.
 */
export const isUsageLimit = ({ status, detail } = {}) => {
  if (Number(status) === 429) {
    return true;
  }
  const text = String(detail ?? "").toLowerCase();
  if (text === "") {
    return false;
  }
  return (
    /usage limit|rate limit|quota|too many requests|out of credits|credit balance|insufficient (quota|credit|funds)|limit reached|exceeded your (current )?quota/.test(
      text,
    )
  );
};

/**
 * When the wall falls, from the response's headers or from the rail's own words.
 * Returns epoch milliseconds, or `null` when the rail did not say.
 */
export const resetAt = ({ headers, detail } = {}, now = Date.now()) => {
  const read = (name) => {
    if (!headers) {
      return undefined;
    }
    if (typeof headers.get === "function") {
      return headers.get(name) ?? undefined;
    }
    const key = Object.keys(headers).find((candidate) => candidate.toLowerCase() === name);
    return key ? headers[key] : undefined;
  };

  for (const name of RETRY_HEADERS) {
    const raw = read(name);
    if (raw === undefined || raw === null || String(raw).trim() === "") {
      continue;
    }
    const parsed = parseDuration(raw);
    if (parsed === null) {
      continue;
    }
    if (typeof parsed === "object" && parsed.epochSeconds) {
      return parsed.epochSeconds * 1000;
    }
    if (typeof parsed === "number") {
      return now + parsed;
    }
  }

  // No header: the rail sometimes says it in prose — "try again in 6m0s",
  // "resets at 14:30 UTC", "retry after 30 seconds".
  const text = String(detail ?? "");
  const inDuration = text.match(
    /(?:try again in|retry after|resets? in|available in|back in)\s+([0-9.]+\s*(?:ms|s|m|h|d)(?:\s*[0-9.]+\s*(?:ms|s|m|h|d))?)/i,
  );
  if (inDuration) {
    const parsed = parseDuration(inDuration[1]);
    if (typeof parsed === "number") {
      return now + parsed;
    }
  }
  const atClock = text.match(/resets?\s+at\s+([0-9]{1,2}:[0-9]{2})\s*(utc|z)?/i);
  if (atClock) {
    const [, clock, zone] = atClock;
    const [hours, minutes] = clock.split(":").map(Number);
    const then = new Date(now);
    if (zone) {
      then.setUTCHours(hours, minutes, 0, 0);
    } else {
      then.setHours(hours, minutes, 0, 0);
    }
    let target = then.getTime();
    if (target < now) {
      target += 24 * 60 * 60 * 1000;
    }
    return target;
  }
  return null;
};

/**
 * The sentence. One line, plain, and it always carries the two things a person
 * needs: that this is a limit and not a fault, and when to ask again.
 */
export const usageLimitSentence = ({ status, detail, headers } = {}, now = Date.now()) => {
  const when = resetAt({ headers, detail }, now);
  if (when === null) {
    return (
      "The model's usage limit is reached. It did not say when it resets — " +
      "try again later, or ask the operator to raise the limit."
    );
  }
  const wait = when - now;
  if (wait <= 60_000) {
    return "The model's usage limit is reached, and it resets within a minute — ask again shortly.";
  }
  return `The model's usage limit is reached. It resets in ${humanDuration(
    wait,
  )} (at ${clockOf(when)}) — ask again after that.`;
};

/**
 * The one door the caller uses: a failure becomes either the wall's sentence or
 * the plain fault, never a bare status code on its own.
 */
export const explainFailure = (failure, now = Date.now()) => {
  if (isUsageLimit(failure)) {
    return { kind: "usage-limit", message: usageLimitSentence(failure, now) };
  }
  return { kind: "error", message: failure?.message ?? `Upstream returned ${failure?.status ?? "an error"}` };
};
