/**
 * Pure helpers for URL health checking, unit-testable without network.
 */

/** Maps an HTTP status code to a health state. */
export function classifyHttpStatus(status) {
  if (typeof status !== "number") return "unknown";
  if (status >= 200 && status < 400) return "ok";
  if (status >= 400) return "broken";
  return "unknown";
}

/** The resource URL fields we health-check, in display order. */
export const URL_FIELDS = [
  "applicationUrl",
  "affiliateUrl",
  "redemptionUrl",
  "officialWebsite",
];

/** Serialises a health map (Firestore Timestamps → epoch ms) for a callable. */
export function serializeHealth(health) {
  const out = {};
  for (const [k, v] of Object.entries(health || {})) {
    out[k] = {
      state: v.state,
      httpStatus: v.httpStatus ?? null,
      checkedAt: v.checkedAt?.toMillis ? v.checkedAt.toMillis() : null,
    };
  }
  return out;
}
