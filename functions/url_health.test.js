import { test } from "node:test";
import assert from "node:assert/strict";
import { classifyHttpStatus, serializeHealth } from "./url_health.js";

test("classifyHttpStatus maps ranges", () => {
  assert.equal(classifyHttpStatus(200), "ok");
  assert.equal(classifyHttpStatus(301), "ok");
  assert.equal(classifyHttpStatus(399), "ok");
  assert.equal(classifyHttpStatus(404), "broken");
  assert.equal(classifyHttpStatus(500), "broken");
  assert.equal(classifyHttpStatus(100), "unknown");
  assert.equal(classifyHttpStatus(null), "unknown");
  assert.equal(classifyHttpStatus(undefined), "unknown");
});

test("serializeHealth converts timestamps to millis", () => {
  const out = serializeHealth({
    applicationUrl: {
      state: "ok",
      httpStatus: 200,
      checkedAt: { toMillis: () => 1234 },
    },
    officialWebsite: { state: "broken", httpStatus: 404 },
  });
  assert.deepEqual(out.applicationUrl, {
    state: "ok",
    httpStatus: 200,
    checkedAt: 1234,
  });
  assert.deepEqual(out.officialWebsite, {
    state: "broken",
    httpStatus: 404,
    checkedAt: null,
  });
});
