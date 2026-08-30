/**
 * Pure lifecycle-transition logic for scheduled publishing, extracted so it can
 * be unit-tested without the Firestore/scheduler runtime.
 *
 * A background job (see runResourceSchedule in index.js) reads resources whose
 * schedule is due and applies the transition this function computes. Unpublish
 * takes precedence over publish when both are somehow due at once.
 *
 * All time inputs are epoch milliseconds (or null/undefined when unset).
 * Returns null when nothing should change, or an object:
 *   { status, setPublishedAt, clearPublish, clearUnpublish }
 */
export function computeLifecycleUpdate({
  status,
  scheduledPublishMs,
  scheduledUnpublishMs,
  publishedAtMs,
  nowMs,
}) {
  // Due unpublish → hide (never touch drafts or already-hidden docs).
  if (
    scheduledUnpublishMs &&
    scheduledUnpublishMs <= nowMs &&
    status !== "hidden" &&
    status !== "draft"
  ) {
    return { status: "hidden", clearUnpublish: true };
  }

  // Due publish → activate a draft.
  if (
    scheduledPublishMs &&
    scheduledPublishMs <= nowMs &&
    status === "draft"
  ) {
    return {
      status: "active",
      setPublishedAt: !publishedAtMs,
      clearPublish: true,
    };
  }

  return null;
}
