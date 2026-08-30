import { test } from "node:test";
import assert from "node:assert/strict";
import { metricField, dayId, METRIC_FIELDS } from "./analytics_agg.js";

test("metricField maps canonical events to counter fields", () => {
  assert.equal(metricField("view"), "views");
  assert.equal(metricField("click"), "clicks");
  assert.equal(metricField("apply"), "applies");
  assert.equal(metricField("save"), "saves");
  assert.equal(metricField("share"), "shares");
  assert.equal(metricField("bogus"), null);
  assert.equal(metricField(undefined), null);
});

test("METRIC_FIELDS covers all mapped fields", () => {
  assert.deepEqual(METRIC_FIELDS, ["views", "clicks", "applies", "saves", "shares"]);
});

test("dayId formats a UTC yyyymmdd bucket", () => {
  assert.equal(dayId(new Date(Date.UTC(2026, 7, 8))), "20260808");
  assert.equal(dayId(new Date(Date.UTC(2026, 0, 1))), "20260101");
});
