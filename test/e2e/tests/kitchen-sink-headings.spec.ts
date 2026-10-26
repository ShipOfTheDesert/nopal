import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { assertNoAxeViolations } from "./axe";

const SECTION = '[data-testid="headings-section"]';
const UNSTYLED = '[data-testid="headings-unstyled"]';
const PLAIN_TEXT = '[data-testid="headings-plain-text"]';
const STYLED = '[data-testid="headings-styled"]';

// The styled heading's declared base font size, in rem.
const STYLED_FONT_SIZE_REM = 1.5;

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("heading levels are found by role", async ({ page }) => {
  const expected: Array<[number, string]> = [
    [1, "Kitchen Sink"],
    [2, "Headings"],
    [3, "Heading level three"],
    [4, "Heading level four"],
    [5, "Heading level five"],
    [6, "Heading level six"],
  ];
  for (const [level, name] of expected) {
    await expect(
      page.getByRole("heading", { level, name, exact: true })
    ).toHaveCount(1);
  }
});

test("unstyled heading matches surrounding text", async ({ page }) => {
  const read = (selector: string) =>
    page.locator(selector).evaluate((el) => {
      const cs = getComputedStyle(el);
      return {
        marginTop: cs.marginTop,
        marginBottom: cs.marginBottom,
        fontSize: cs.fontSize,
        fontWeight: cs.fontWeight,
      };
    });
  const heading = await read(UNSTYLED);
  const plain = await read(PLAIN_TEXT);

  expect(heading).toEqual(plain);
  expect(heading.marginTop).toBe("0px");
  expect(heading.marginBottom).toBe("0px");
});

test("heading style beats the reset", async ({ page }) => {
  const { fontSize, rootFontSize } = await page
    .locator(STYLED)
    .evaluate((el) => ({
      fontSize: parseFloat(getComputedStyle(el).fontSize),
      rootFontSize: parseFloat(
        getComputedStyle(document.documentElement).fontSize
      ),
    }));

  expect(fontSize).toBe(STYLED_FONT_SIZE_REM * rootFontSize);
});

test("host-page heading keeps browser defaults", async ({ page }) => {
  const host = await page.evaluate(() => {
    const h2 = document.createElement("h2");
    h2.textContent = "A heading the host page owns";
    document.body.appendChild(h2);
    const cs = getComputedStyle(h2);
    return {
      marginTop: cs.marginTop,
      fontWeight: cs.fontWeight,
      fontSize: parseFloat(cs.fontSize),
      bodyFontSize: parseFloat(getComputedStyle(document.body).fontSize),
    };
  });

  expect(host.marginTop).not.toBe("0px");
  expect(host.fontWeight).toBe("700");
  expect(host.fontSize).toBeGreaterThan(host.bodyFontSize);
});

test("axe: headings", async ({ page }, testInfo) => {
  const rules = ["heading-order", "empty-heading", "aria-allowed-role"];
  const results = await new AxeBuilder({ page }).withRules(rules).analyze();

  if (results.violations.length > 0) {
    await testInfo.attach("axe-violations", {
      body: JSON.stringify(results.violations, null, 2),
      contentType: "application/json",
    });
  }
  expect(results.violations).toEqual([]);

  // Zero violations is only meaningful if every rule examined the headings,
  // including the redundant role="heading" each one carries.
  const passed = (rule: string) =>
    results.passes
      .filter((r) => r.id === rule)
      .flatMap((r) => r.nodes.map((n) => n.html));
  for (const rule of rules) {
    expect(passed(rule).some((html) => html.includes("data-nopal-heading")))
      .toBe(true);
  }

  await assertNoAxeViolations(page, testInfo, SECTION);
});
