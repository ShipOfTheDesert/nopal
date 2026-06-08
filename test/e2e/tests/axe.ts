import { expect, type Page, type TestInfo } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

// Accessibility gate (REQ-F6). A thin wrapper over the already-installed
// @axe-core/playwright builder so every per-component spec asserts a
// zero-violation scan of the component it exercises with a single call. Scoped
// to WCAG 2.0/2.1 Level A + AA — the conformance target named in RFC 0112's
// public interface. On failure the full violation list is attached to the
// report so a red scan is diagnosable without re-running (mirrors the telemetry
// dump-on-failure contract).
//
// `include` scopes the scan to the component's kitchen-sink section, matching
// the established `.include(SECTION)` convention of every existing kitchen-sink
// spec. The shared kitchen-sink route carries pre-existing a11y violations in
// sections Task 5 does not own (RFC 0112 Implementation Decision 2), so a
// per-route scan would assert accessibility this task neither tests nor fixes.
export async function assertNoAxeViolations(
  page: Page,
  testInfo: TestInfo,
  include: string
): Promise<void> {
  const results = await new AxeBuilder({ page })
    .include(include)
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();

  if (results.violations.length > 0) {
    await testInfo.attach("axe-violations", {
      body: JSON.stringify(results.violations, null, 2),
      contentType: "application/json",
    });
  }
  expect(results.violations).toEqual([]);
}
