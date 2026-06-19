import { test, expect } from "@playwright/test";
import { NopalTelemetry, type TelemetryEvent } from "./nopal-telemetry";

// E2E for the Subscriptions section (RFC 0118, REQ-F3): the live [every] timer
// is a real browser `setInterval`, so its ticks dispatch independently of the
// headless rAF stall (RFC Risk). The telemetry contract (ADR 0108) is the
// correctness oracle: each tick is a `Subs:Tick` Message. We assert ticks
// *appear* while enabled and *stop* after the toggle removes the subscription,
// counting over a window rather than asserting an exact cadence.
//
// Headless rAF mitigations (headless-chromium-raf-stall): navigate fresh with
// `goto` (never page.reload), and waitForSelector before interacting.

const SECTION = '[data-testid="subscriptions-section"]';
const TOGGLE = '[data-testid="subs-timer-toggle"]';
const TICK = "Subs:Tick";

// Generous: the first model→DOM frame in a worker can lag while the rAF loop
// warms up on a display-server-less machine.
const SETTLE = 15000;
// At a 500ms timer interval this window spans ~4 ticks; we only require 2, so a
// stalled frame or two cannot flake the "ticks appear" assertion.
const WINDOW = 2500;

async function gotoFresh(page: import("@playwright/test").Page): Promise<void> {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
}

function countTicks(events: TelemetryEvent[]): number {
  return events.filter(
    (e) => e.kind === "message" && e.value.includes(TICK)
  ).length;
}

test("timer ticks appear in telemetry while enabled", async ({ page }) => {
  await gotoFresh(page);
  const telemetry = new NopalTelemetry(page);

  // Arm the wait before enabling so the live stream catches the first fire.
  const firstTick = telemetry.waitForMessage(TICK, SETTLE);
  await page.locator(TOGGLE).click();
  await expect(firstTick).resolves.toBeUndefined();

  // Drain (clears the log), then count over a fresh window to prove the timer
  // keeps firing, not just fired once.
  await telemetry.events();
  await page.waitForTimeout(WINDOW);
  const events = await telemetry.events();
  expect(countTicks(events)).toBeGreaterThanOrEqual(2);
});

test("ticks stop after the timer subscription is removed", async ({ page }) => {
  await gotoFresh(page);
  const telemetry = new NopalTelemetry(page);

  // Enable, confirm at least one tick, then disable.
  const firstTick = telemetry.waitForMessage(TICK, SETTLE);
  await page.locator(TOGGLE).click();
  await expect(firstTick).resolves.toBeUndefined();
  await page.locator(TOGGLE).click();

  // Flush any tick that was already in flight at toggle time, then measure a
  // clean window: with the subscription removed, no further ticks may land.
  await page.waitForTimeout(800);
  await telemetry.events();
  await page.waitForTimeout(WINDOW);
  const events = await telemetry.events();
  expect(countTicks(events)).toBe(0);
});
