import { test, expect } from "@playwright/test";

const SECTION = '[data-section="typography"]';

test.beforeEach(async ({ page }) => {
  await page.goto("/kitchen_sink/");
  await page.waitForFunction(
    (sel) => document.querySelector(sel) !== null,
    SECTION,
    { timeout: 10000 }
  );
});

test("typography section renders", async ({ page }) => {
  const section = page.locator(SECTION);
  await expect(section).toBeVisible();

  // Heading scale: h1–h4 with decreasing font sizes
  const h1 = section.locator('[data-testid="heading-h1"] span');
  const h4 = section.locator('[data-testid="heading-h4"] span');
  await expect(h1).toBeVisible();
  await expect(h4).toBeVisible();
  const h1Size = await h1.evaluate(
    (el) => parseFloat(getComputedStyle(el).fontSize)
  );
  const h4Size = await h4.evaluate(
    (el) => parseFloat(getComputedStyle(el).fontSize)
  );
  expect(h1Size).toBeGreaterThan(h4Size);

  // Body copy with line height
  const body = section.locator('[data-testid="body-copy"] span');
  await expect(body).toBeVisible();
  const lineHeight = await body.evaluate(
    (el) => getComputedStyle(el).lineHeight
  );
  expect(lineHeight).not.toBe("normal");

  // Monospace block
  const mono = section.locator('[data-testid="monospace-block"] span');
  await expect(mono).toBeVisible();
  const fontFamily = await mono.evaluate(
    (el) => getComputedStyle(el).fontFamily
  );
  expect(fontFamily).toContain("monospace");

  // Weight scale: all 9 weights present
  for (const weight of [
    "100", "200", "300", "400", "500", "600", "700", "800", "900",
  ]) {
    const weightEl = section.locator(`[data-testid="weight-${weight}"] span`);
    await expect(weightEl).toBeVisible();
    const fw = await weightEl.evaluate(
      (el) => getComputedStyle(el).fontWeight
    );
    expect(fw).toBe(weight);
  }

  // Ellipsis truncation — check the container which has overflow/text-overflow
  const ellipsis = section.locator('[data-testid="ellipsis-text"] span');
  await expect(ellipsis).toBeVisible();
  const overflow = await ellipsis.evaluate(
    (el) => getComputedStyle(el).textOverflow
  );
  expect(overflow).toBe("ellipsis");

  // Text alignment — text-align is on the container div, not the span
  for (const align of ["left", "center", "right", "justify"]) {
    const alignContainer = section.locator(`[data-testid="align-${align}"]`);
    await expect(alignContainer).toBeVisible();
    const ta = await alignContainer.evaluate(
      (el) => getComputedStyle(el).textAlign
    );
    expect(ta).toBe(align === "justify" ? "justify" : align);
  }

  // Italic text
  const italicEl = section.locator('[data-testid="italic-text"] span');
  await expect(italicEl).toBeVisible();
  const fontStyle = await italicEl.evaluate(
    (el) => getComputedStyle(el).fontStyle
  );
  expect(fontStyle).toBe("italic");

  // Text transforms
  for (const transform of ["uppercase", "lowercase", "capitalize"]) {
    const transformEl = section.locator(
      `[data-testid="transform-${transform}"] span`
    );
    await expect(transformEl).toBeVisible();
    const tt = await transformEl.evaluate(
      (el) => getComputedStyle(el).textTransform
    );
    expect(tt).toBe(transform);
  }

  // Text color. Read off the span the color is authored on, never off the
  // container: the container carries only the test anchor, and a color that
  // reached it instead would still cascade down and look identical here.
  const computedTextColor = async (testid: string) => {
    const el = section.locator(`[data-testid="${testid}"] span`);
    await expect(el).toBeVisible();
    return el.evaluate((node) => getComputedStyle(node).color);
  };

  // Asserted in the computed rgb()/rgba() form the browser reports, never the
  // authored "#c0392b" / "rebeccapurple" spelling — the authored string is an
  // input to the style system, not something the rendered page ever shows.
  const hexColor = await computedTextColor("text-color-hex");
  expect(hexColor).toBe("rgb(192, 57, 43)");

  // The fractional alpha is what makes this row a distinct oracle: a
  // translucent color computes to an "rgba(...)" string, where the hex and
  // named rows above both compute to an opaque "rgb(...)". Keep the alpha on an
  // integral 8-bit boundary — 0.6 x 255 is exactly 153, so it round-trips
  // through the browser's 8-bit color storage unchanged. A "nicer" 0.7 is
  // 178.5, and this expectation would no longer be exact.
  const rgbaColor = await computedTextColor("text-color-rgba");
  expect(rgbaColor).toBe("rgba(30, 120, 200, 0.6)");

  const namedColor = await computedTextColor("text-color-named");
  expect(namedColor).toBe("rgb(102, 51, 153)");

  // An unset color is inert: the row that authors none is left at whatever its
  // container inherits. Compared against that container rather than against a
  // literal black, so the assertion states the inheritance relationship instead
  // of pinning the page's current default color.
  const inheritedTestid = "text-color-inherited";
  const inheritedColor = await computedTextColor(inheritedTestid);
  const containerColor = await section
    .locator(`[data-testid="${inheritedTestid}"]`)
    .evaluate((el) => getComputedStyle(el).color);
  expect(inheritedColor).toBe(containerColor);

  // Affirmative arm for the assertion above. The uncolored row is built by the
  // same helper as the three colored ones and differs from them in nothing but
  // whether a color was authored, so "it matches its container" is a real
  // observation only while an authored color does not.
  expect(inheritedColor).not.toBe(hexColor);
  expect(inheritedColor).not.toBe(rgbaColor);
  expect(inheritedColor).not.toBe(namedColor);

  // The color is a property of the text, not of the box around it. Without
  // this line the assertions above would read the same on a page that colored
  // the container and let the cascade carry it into the span, so the anchor
  // container is checked to be left at the same inherited color as the
  // uncolored row's.
  const hexContainerColor = await section
    .locator('[data-testid="text-color-hex"]')
    .evaluate((el) => getComputedStyle(el).color);
  expect(hexContainerColor).toBe(containerColor);

  // Numeric figures. Read off the span the axes are authored on, never off the
  // anchor container: the container carries only the test hook, and this
  // property inherits, so a declaration that landed there instead would cascade
  // into the span and read identically at this line.
  //
  // A DOM assertion rather than an MVU telemetry one, for the reason the
  // testing strategy carves out: these rows are a pure view derivation with no
  // model state, so there is no event for telemetry to report and nothing it
  // could assert.
  //
  // The computed declaration, never a measured width. What the two axes draw
  // depends on whether the rendering face carries the requested figure set, and
  // this example declares no font-family and ships no font, so a width
  // assertion would encode which fonts the runner has installed rather than
  // this framework's behaviour.
  const computedFigures = async (testid: string) => {
    const el = section.locator(`[data-testid="${testid}"] span`);
    await expect(el).toBeVisible();
    return el.evaluate((node) => getComputedStyle(node).fontVariantNumeric);
  };

  // One axis authored alone. The keyword the other axis would have contributed
  // is absent, which is the rendered face of the reset these rows document: the
  // single declaration names every axis it does not mention.
  const tabularFigures = await computedFigures("figures-tabular");
  expect(tabularFigures).toBe("tabular-nums");

  const oldstyleFigures = await computedFigures("figures-oldstyle");
  expect(oldstyleFigures).toBe("oldstyle-nums");

  // Both axes on one element, and the row that carries the reason they are
  // resolved together rather than one per field: two keywords survive here only
  // because they are emitted as a single declaration. Had each axis emitted its
  // own, the later one would have replaced the earlier and exactly one keyword
  // would compute.
  //
  // The order below is the engine's, not the order this framework authors. The
  // style layer writes spacing before style; Chromium normalises the pair to
  // style before spacing, so an authored "tabular-nums lining-nums" computes as
  // written here. Observed on this runner, not assumed. The authored order is
  // pinned one layer down, in the style unit tests — do not "correct" this
  // string back to it, it would simply fail.
  //
  // That string is a property of the engine, not of this framework, and this
  // file is run against Chromium alone. Anyone adding this spec to a WebKit or
  // Tauri project must re-observe the order there rather than carry this one
  // over: a different engine normalising the pair the other way would fail
  // here, and the failure would read as a framework defect when it is an
  // engine difference. Only the composed row is exposed to this — every other
  // assertion below reads a single keyword or "normal".
  const composedFigures = await computedFigures("figures-tabular-lining");
  expect(composedFigures).toBe("lining-nums tabular-nums");

  // A row authoring neither axis is inert, and reports the property's initial
  // value. What a computed read cannot see is the difference between emitting
  // nothing and emitting a declaration that happens to say "normal" — both
  // compute the same. That distinction is pinned in the style unit tests; this
  // line pins that nothing reaches the browser which would change the numerals.
  const unsetTestid = "figures-unset";
  const unsetFigures = await computedFigures(unsetTestid);
  expect(unsetFigures).toBe("normal");

  // Stated as the inheritance relationship as well as the literal: the property
  // inherits, and an unauthored row sits at whatever its ancestors leave it, so
  // this also says that nothing above these rows declares the axes either.
  const unsetContainerFigures = await section
    .locator(`[data-testid="${unsetTestid}"]`)
    .evaluate((el) => getComputedStyle(el).fontVariantNumeric);
  expect(unsetFigures).toBe(unsetContainerFigures);

  // Affirmative arm for the two assertions above, which are assertions of
  // absence and would otherwise go vacuous. The unauthored row is built by the
  // same helper as the three authored ones and differs from them in nothing but
  // whether an axis was set, so "it is left at the initial value" is an
  // observation only while an authored axis is not. Without this, a change that
  // stopped every one of these rows from reaching the text-style path would
  // leave the unset row's expectations green.
  expect(unsetFigures).not.toBe(tabularFigures);
  expect(unsetFigures).not.toBe(oldstyleFigures);
  expect(unsetFigures).not.toBe(composedFigures);

  // The axes are a property of the text, not of the box around it. Without this
  // line the reads above would look the same on a page that declared them on
  // the anchor container and let the cascade carry them into the span, so an
  // authored row's container is checked to be left where the unauthored row's
  // container is.
  const tabularContainerFigures = await section
    .locator('[data-testid="figures-tabular"]')
    .evaluate((el) => getComputedStyle(el).fontVariantNumeric);
  expect(tabularContainerFigures).toBe(unsetContainerFigures);

  // Numeric figures under a container that declares one of the axes. This is
  // the only place on the page where an explicit typeface default is
  // observable at all: everywhere else it computes "normal", which is also
  // what an unauthored row computes, so the two are one value to a computed
  // read. Under an ancestor that asked for old-style forms they separate.
  const declaringContainerFigures = await section
    .locator('[data-testid="figures-oldstyle-container"]')
    .evaluate((el) => getComputedStyle(el).fontVariantNumeric);
  expect(declaringContainerFigures).toBe("oldstyle-nums");

  // The row that authors neither axis, stated as the inheritance relationship
  // and not only as the literal: it emits nothing, so what it computes is
  // whatever the container left it.
  const inheritedFigures = await computedFigures("figures-inherited");
  expect(inheritedFigures).toBe(declaringContainerFigures);

  // The row the explicit typeface default exists for. It sits under the same
  // container as the row above and differs from it in one authored value, so
  // "normal" here can only have come from a declaration this row emitted —
  // emitting nothing would have left it at the inherited "oldstyle-nums", as
  // its sibling shows. That is what makes the explicit default browser-
  // observable rather than a unit-layer claim, and the inequality below is its
  // affirmative arm: the two rows are built by the same helper from the same
  // sample and reach different values.
  const normalStyleFigures = await computedFigures("figures-normal-style");
  expect(normalStyleFigures).toBe("normal");
  expect(normalStyleFigures).not.toBe(inheritedFigures);

  // The trap row: it authors the width axis only, and loses the container's
  // form axis with it, because the single declaration names every axis it does
  // not mention. The keyword the container contributed is absent here — this
  // is that reset observed under an ancestor that really did declare it,
  // rather than inferred from a row with no ancestor to lose.
  const proportionalFigures = await computedFigures(
    "figures-inherited-proportional",
  );
  expect(proportionalFigures).toBe("proportional-nums");
  expect(proportionalFigures).not.toBe(inheritedFigures);

  // And the reason the emit/no-emit distinction stays one layer down: with no
  // ancestor declaring the axes, the explicit default and the unauthored row
  // compute the same string. The style unit tests are where those two are told
  // apart.
  expect(unsetFigures).toBe(normalStyleFigures);
});

// Whitespace. A separate case because it is the only part of this section that
// needs the browser's layout and not just its computed values: whether runs of
// spaces survive is a question about the ink on the page. DOM assertions rather
// than MVU telemetry are correct here for the reason the testing strategy
// carves out — these rows are a pure view derivation with no model state, so
// there is no event for telemetry to report and nothing it could assert.
test("whitespace preservation keeps real indentation", async ({ page }) => {
  const section = page.locator(SECTION);
  await expect(section).toBeVisible();

  // Every whitespace row's box is the same fixed width, so the box itself
  // discriminates nothing between preserved and collapsed content and a
  // left-offset check reads zero on all of them. A Range over the span's
  // contents measures the text the browser actually laid out, which is the
  // thing that differs. textContent comes back too: it is the source text and
  // is unaffected by the declaration, so it says whether the fixture had any
  // indentation to lose in the first place.
  const measure = async (testid: string) => {
    const el = section.locator(`[data-testid="${testid}"] span`);
    await expect(el).toBeVisible();
    return el.evaluate((node) => {
      const range = document.createRange();
      range.selectNodeContents(node);
      const ink = range.getBoundingClientRect();
      return {
        whiteSpace: getComputedStyle(node).whiteSpace,
        inkWidth: ink.width,
        inkHeight: ink.height,
        text: node.textContent ?? "",
      };
    });
  };

  // One row per reachable combination of the two style axes, with the value
  // each pair resolves to. The last four sit inside a container that declares
  // preservation, so they also cover a descendant opting back out of an
  // inherited one — which is the only situation an explicit collapse exists
  // for, and unobservable outside such a container. The last of them is the
  // trap: an unset whitespace does not survive a set text_overflow, because
  // the emitted shorthand sets both axes, so it resolves to "nowrap" and not
  // to the container's "pre" — pinned here so the reset cannot change silently.
  const rows: Array<[string, string]> = [
    ["whitespace-unset", "normal"],
    ["whitespace-unset-nowrap", "nowrap"],
    ["whitespace-preserve", "pre-wrap"],
    ["whitespace-preserve-nowrap", "pre"],
    ["whitespace-inherited", "pre-wrap"],
    ["whitespace-collapse", "normal"],
    ["whitespace-collapse-nowrap", "nowrap"],
    ["whitespace-inherited-nowrap", "nowrap"],
  ];
  for (const [testid, value] of rows) {
    const row = await measure(testid);
    expect(row.whiteSpace, `${testid} resolved white-space`).toBe(value);
  }

  // The container itself, not just its children: the "inherited" row above
  // computes a preserving value only because something above it declares one,
  // and without this line that row would read the same on a page that authored
  // the value directly on the span.
  const container = section.locator(
    '[data-testid="whitespace-preserving-container"]'
  );
  await expect(container).toBeVisible();
  const containerWhiteSpace = await container.evaluate(
    (el) => getComputedStyle(el).whiteSpace
  );
  expect(containerWhiteSpace).toBe("pre-wrap");

  // The rendered consequence, which a computed-value read cannot see. These two
  // rows render the same string in the same monospace family inside the same
  // box and differ in exactly one authored value, so their ink widths are
  // comparable and the difference between them is the indentation.
  const preserved = await measure("whitespace-preserve-nowrap");
  const collapsed = await measure("whitespace-unset-nowrap");
  expect(preserved.text).toBe(collapsed.text);
  expect(preserved.text.startsWith("    ")).toBe(true);

  // What the document default does to that string, derived from the string
  // itself rather than hardcoded: leading and trailing runs go entirely, and
  // every interior run of spaces or tabs becomes one space. The assertion
  // guards that derivation — a regex that stopped matching would leave the two
  // forms the same length and silently make the character count below trivial.
  // It is a self-check on the spec, not a reading of the page; the rendered
  // premise is measured at the ink-width comparison further down.
  const collapsedForm = preserved.text.trim().replace(/[ \t]+/g, " ");
  expect(collapsedForm.length).toBeLessThan(preserved.text.length);

  // Character counts, never the pixel widths this host happens to produce: the
  // sample is monospace, so one character's advance is the collapsed row's ink
  // over the number of characters it was left with. The preserved row then has
  // to account for every character of the source, including both runs. A
  // browser that collapsed both rows, or preserved both, fails this — the
  // derived advance moves with it and the count does not come out. The divisor
  // assumes Chromium's collapsing, which drops the leading and trailing runs
  // entirely; an engine that renders one leading space, or a "monospace" that
  // is not truly fixed-advance, shifts it by a few percent and the rounded
  // count comes out one short — a failure in the divisor, not in the feature.
  const charWidth = collapsed.inkWidth / collapsedForm.length;
  expect(charWidth).toBeGreaterThan(0);
  expect(Math.round(preserved.inkWidth / charWidth)).toBe(
    preserved.text.length
  );
  expect(preserved.inkWidth).toBeGreaterThan(collapsed.inkWidth);

  // The two axes compose rather than one overriding the other: both of these
  // rows preserve their runs, and only the one that also authored no-wrap keeps
  // the sample on a single line. Heights, because a row that wrapped is bounded
  // by the box it wrapped inside and its width stops meaning anything.
  const preservedWrapping = await measure("whitespace-preserve");
  expect(preservedWrapping.inkHeight).toBeGreaterThan(preserved.inkHeight);
  expect(preserved.inkHeight).toBe(collapsed.inkHeight);

  // An explicit collapse inside the preserving container throws the runs away
  // again, down to the same ink as the row outside it that authored nothing.
  // Exactly equal, not approximately: same string, same family, same size, so
  // any difference at all is a bug worth seeing undamped.
  const collapsedInsideContainer = await measure("whitespace-collapse-nowrap");
  expect(collapsedInsideContainer.inkWidth).toBe(collapsed.inkWidth);
});
