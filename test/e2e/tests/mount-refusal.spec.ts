import { test, expect } from "@playwright/test";

const SETTLE = 15000;

// The kitchen sink mounts a Tauri page through the entry point that supplies an
// opener, so it never refuses. These cases need a mount that does, and depend on
// examples/counter/main.ml mounting through `Nopal_web.mount_with_telemetry`
// with no opener, which is the mount an existing Tauri app would be calling.
test.describe("a Tauri page mounted without an opener", () => {
  const COUNTER_PATH = "/counter/";
  const APP = "#app";
  const INCREMENT = '[data-action="counter-increment"]';
  const REFUSAL =
    "nopal_web refused to mount: this page runs in a Tauri webview and the mount " +
    "was given no ~open_external, so a link would navigate the webview away from " +
    "the app. Mount through Nopal_tauri_mount, which supplies one.";

  test("shows the refusal, reports it, and renders no app", async ({ page }) => {
    const logged: string[] = [];
    page.on("console", (m) => logged.push(m.text()));
    await page.addInitScript(() => {
      (window as unknown as { __TAURI_INTERNALS__: object }).__TAURI_INTERNALS__ =
        {};
    });

    await page.goto(COUNTER_PATH, { waitUntil: "load" });

    await expect(page.locator(APP)).toHaveText(REFUSAL, { timeout: SETTLE });
    expect(logged, "the refusal did not reach on_error").toContain(
      `[nopal_web] ${REFUSAL}`,
    );
    await expect(page.locator(INCREMENT)).toHaveCount(0);
    expect(
      await page.evaluate(
        () => typeof (window as unknown as Record<string, unknown>).__nopal_telemetry__,
      ),
      "a refused mount installed the telemetry bridge",
    ).toBe("undefined");
  });

  test("the same page without the Tauri global mounts the app", async ({
    page,
  }) => {
    await page.goto(COUNTER_PATH, { waitUntil: "load" });

    await expect(page.locator(INCREMENT)).toBeVisible({ timeout: SETTLE });
    await expect(page.locator(APP)).not.toContainText("refused to mount");
  });
});
