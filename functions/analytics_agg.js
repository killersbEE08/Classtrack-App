/**
 * Pure helpers for analytics aggregation (unit-testable).
 *
 * Student engagement is written as append-only `events/{id}` docs; a Firestore
 * trigger folds each into per-resource (`resourceMetrics`) and per-day
 * (`metricsDaily`) counters the CMS can actually query — Firebase Analytics
 * events themselves are NOT queryable from Firestore/CMS.
 */

/** Canonical event → counter field. Unknown events return null (ignored). */
const FIELDS = {
  view: "views",
  click: "clicks",
  apply: "applies",
  save: "saves",
  share: "shares",
};

export const METRIC_FIELDS = ["views", "clicks", "applies", "saves", "shares"];

export function metricField(event) {
  return FIELDS[event] || null;
}

/** UTC day bucket id, e.g. 20260808. */
export function dayId(date) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}
