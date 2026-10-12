import { $, browser } from "@wdio/globals";
import { Key } from "webdriverio";
import { NopalTelemetryTauri } from "./nopal-telemetry-tauri";

// Link element, Route arm (FR-5): a plain click and a Ctrl-click on the kitchen
// sink's in-app link each dispatch the follow message once, and the webview
// stays on the app. The External arm is not covered (D-19, CONTRIBUTING.md).

const FOLLOWED = "Links:Followed:Target;";

async function followedCount(telemetry: NopalTelemetryTauri): Promise<number> {
  const events = await telemetry.events();
  return events.filter(
    (e) => e.kind === "message" && e.value.includes(FOLLOWED),
  ).length;
}

describe("Tauri Route link", () => {
  it("a plain click and a Ctrl-click each follow once, in-app", async () => {
    const telemetry = new NopalTelemetryTauri();
    const link = '[data-testid="links-route-link"]';
    await $(link).waitForExist({ timeout: 15000 });
    const urlBefore = await browser.getUrl();
    const before = await followedCount(telemetry);

    await $(link).click();
    await browser.waitUntil(
      async () => (await followedCount(telemetry)) === before + 1,
      {
        timeout: 15000,
        timeoutMsg: "plain click did not dispatch Followed once",
      },
    );

    await browser.action("key").down(Key.Ctrl).pause(0).perform();
    await $(link).click();
    await browser.action("key").up(Key.Ctrl).perform();
    await browser.waitUntil(
      async () => (await followedCount(telemetry)) === before + 2,
      {
        timeout: 15000,
        timeoutMsg: "Ctrl-click did not dispatch Followed once",
      },
    );

    // Settle, then confirm neither click dispatched twice or left the app.
    await browser.pause(500);
    if ((await followedCount(telemetry)) !== before + 2) {
      throw new Error("a click dispatched Followed more than once");
    }
    await $('[data-testid="links-current-route"]').waitForExist();
    const urlAfter = new URL(await browser.getUrl());
    if (urlAfter.origin !== new URL(urlBefore).origin) {
      throw new Error(`webview left the app: ${urlAfter.href}`);
    }
  });
});
