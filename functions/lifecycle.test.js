import { test } from "node:test";
import assert from "node:assert/strict";
import { computeLifecycleUpdate } from "./lifecycle.js";

const now = 1_000_000;

test("publishes a draft whose scheduledPublish is due", () => {
  const r = computeLifecycleUpdate({
    status: "draft",
    scheduledPublishMs: now - 1,
    nowMs: now,
  });
  assert.equal(r.status, "active");
  assert.equal(r.setPublishedAt, true);
  assert.equal(r.clearPublish, true);
});

test("does not publish before the scheduled time", () => {
  const r = computeLifecycleUpdate({
    status: "draft",
    scheduledPublishMs: now + 1000,
    nowMs: now,
  });
  assert.equal(r, null);
});

test("does not re-set publishedAt when already published", () => {
  const r = computeLifecycleUpdate({
    status: "draft",
    scheduledPublishMs: now - 1,
    publishedAtMs: now - 5000,
    nowMs: now,
  });
  assert.equal(r.setPublishedAt, false);
});

test("unpublishes a visible resource whose scheduledUnpublish is due", () => {
  const r = computeLifecycleUpdate({
    status: "active",
    scheduledUnpublishMs: now - 1,
    nowMs: now,
  });
  assert.equal(r.status, "hidden");
  assert.equal(r.clearUnpublish, true);
});

test("never unpublishes a draft or an already-hidden doc", () => {
  assert.equal(
    computeLifecycleUpdate({
      status: "draft",
      scheduledUnpublishMs: now - 1,
      nowMs: now,
    }),
    null
  );
  assert.equal(
    computeLifecycleUpdate({
      status: "hidden",
      scheduledUnpublishMs: now - 1,
      nowMs: now,
    }),
    null
  );
});

test("unpublish takes precedence over publish when both are due", () => {
  const r = computeLifecycleUpdate({
    status: "active",
    scheduledPublishMs: now - 10,
    scheduledUnpublishMs: now - 1,
    nowMs: now,
  });
  assert.equal(r.status, "hidden");
});

test("no schedule set → no change", () => {
  assert.equal(
    computeLifecycleUpdate({ status: "active", nowMs: now }),
    null
  );
});
