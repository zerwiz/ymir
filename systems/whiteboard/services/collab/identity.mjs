/**
 * Who is asking, and who is not.
 *
 * The whiteboard sits behind the hall's gate. When the gate admits a person it
 * tells the app who that person is, in a header the **proxy** sets — the same
 * shape the gate's own suite uses. That header is the only identity this server
 * accepts:
 *
 *  - a header the CLIENT sends is a claim, not an identity, so it is ignored
 *    unless the request provably came through the proxy (`trustProxy`);
 *  - an empty, anonymous or malformed value is a refusal, never a default;
 *  - the value is verified to be a safe single path segment before it is ever
 *    used to name a directory, so an identity cannot walk the disk.
 *
 * `tickets/open/feature-0036-uw-save-to-server-and-choose-a-session.md`.
 */

/** The gate's header, as the proxy sets it. */
export const DEFAULT_IDENTITY_HEADER = "remote-user";

/**
 * A person's identity must be usable as ONE directory name: no separator, no
 * traversal, no NUL, no whitespace. Nothing else is a person anyway — the gate
 * issues these from its own user store.
 */
export const isPlausibleIdentity = (value) =>
  typeof value === "string" &&
  value.length > 0 &&
  value.length <= 64 &&
  /^[A-Za-z0-9][A-Za-z0-9._@-]*$/.test(value);

/** Values a proxy sometimes substitutes for "nobody" — all of them are nobody. */
const ANONYMOUS = new Set(["", "-", "anonymous", "unknown", "null", "undefined"]);

/**
 * The identity the gate asserts for this request.
 *
 * Returns `{ ok: true, identity }` or `{ ok: false, reason }` where the reason is
 * a sentence the client may show: it never names another person, and it never
 * repeats the header's value.
 */
export const identityFrom = (headers, config) => {
  const raw = headers?.[config.header];
  const value = Array.isArray(raw) ? raw[0] : raw;

  if (typeof value === "undefined" || value === null) {
    return {
      ok: false,
      reason: config.trustProxy
        ? "the gate did not say who you are — sign in again at the hall"
        : `this server is not behind a gate that asserts identity (set ${config.header} via the proxy, or YMIR_WHITEBOARD_TRUST_PROXY=on for a local seat)`,
    };
  }
  if (ANONYMOUS.has(String(value).trim().toLowerCase())) {
    return { ok: false, reason: "an anonymous request cannot own a board" };
  }
  if (!isPlausibleIdentity(String(value).trim())) {
    return { ok: false, reason: "the gate's identity is not a usable name" };
  }
  return { ok: true, identity: String(value).trim() };
};

export const readConfig = (env = process.env) => ({
  header: (env.YMIR_WHITEBOARD_IDENTITY_HEADER ?? DEFAULT_IDENTITY_HEADER).toLowerCase(),
  /**
   * Loopback-only seats have no gate in front of them, so the header is set by
   * the client. That is a deliberate, documented local mode — never the default,
   * because behind a gate a client-set header would let anyone be anyone.
   */
  trustProxy: env.YMIR_WHITEBOARD_TRUST_PROXY === "on",
});
