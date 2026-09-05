// Minimal DOM shim for running Brr-based tests under Node.js via js_of_ocaml.
//
// Brr expects a browser-like global environment (document, window, Event,
// KeyboardEvent, etc.). This shim provides the subset of DOM APIs that Brr
// and the renderer actually call:
//
//   - document.createElement, createTextNode, createComment
//   - Element: appendChild, removeChild, replaceChild, insertBefore, contains,
//     setAttribute, getAttribute, style (Proxy-based) — see "Inline style and
//     the `style` attribute" below for how the two meet, classList,
//     addEventListener, removeEventListener, dispatchEvent
//   - Element: querySelector / querySelectorAll over a single attribute
//     selector, and the vertical scroll geometry (scrollTop, clientHeight,
//     clientTop, scrollHeight, getBoundingClientRect) — see "Layout" below
//   - document.getElementById — see "Element lookup by id" below
//   - window.requestAnimationFrame, setTimeout, getComputedStyle
//   - CSS.escape
//   - Event, KeyboardEvent, InputEvent constructors
//
// Why this is needed: dune's `(modes js)` test stanza compiles OCaml to
// JavaScript via js_of_ocaml and runs it under Node.js. Node.js has no DOM,
// but Brr calls `document.createElement` etc. at module init time. Without
// this shim, every Brr-based test would require a headless browser (slow,
// heavy dependency). By injecting a lightweight fake DOM before any OCaml
// code runs, we get fast, CI-friendly unit tests that verify renderer logic
// (element creation, reconciliation, event dispatch) without a real browser.
//
// It does NOT provide rendering or network APIs. Nodes track their
// parent/child relationships in plain JS arrays so that tests can assert on
// DOM structure without a real browser engine.
//
// ## Layout
//
// There is no layout engine, but there is a vertical layout *model*, because a
// renderer that brings a child of a scroll container into view has to measure
// one. A test states where a node sits by setting `_layoutTop` (its top edge
// within its parent's content) and, for a leaf, `_layoutHeight`; a container
// states its visible height with `_clientHeight`. Everything a renderer can
// read is then derived rather than supplied:
//
//   - `scrollHeight` is the furthest extent of the element's children, never a
//     test-supplied number, so content and viewport cannot be set to disagree.
//   - `getBoundingClientRect()` walks the ancestors, adding each `_layoutTop`
//     and subtracting each scroll offset, so a child's rect MOVES when its
//     container scrolls — exactly as it does in a browser. A renderer that
//     measures a child without accounting for the container's current offset
//     therefore fails here rather than only on a real page.
//   - A container's `_borderTop` separates the top of its bounding box from the
//     origin its own `scrollTop` counts from, and is reported as `clientTop`.
//     A container with one moves its content without moving itself.
//   - `scrollTop` is writable, starts at 0, and clamps to
//     `[0, scrollHeight - clientHeight]`, which is the platform's own
//     behaviour. `_scrollWrites` counts assignments (mirroring the inline-style
//     and input-value counters below) so a test can tell "wrote the value it
//     already held" from "did not write".
//
// Defaults are the platform's, not the convenient ones: an element nobody has
// laid out has `clientHeight` 0 and a zero-height rect, so a test that forgets
// to lay out its fixture sees nothing move.
//
// ## Element lookup by id
//
// `document.getElementById` resolves in a fixed order, and the order is the
// contract rather than an accident of how it was written:
//
//   1. A registered focus target, if one was registered under that id. These
//      are synthetic objects with a `focus` method and no geometry, created by
//      `_registerFocusTarget` so a test can assert the focus drain's order and
//      its last-wins result. They win, because a test that registered one is
//      asking about the drain, not about a rendered node.
//   2. Otherwise the first created element carrying that id as an attribute.
//      This is what lets a test resolve a container the renderer just built and
//      then measure or scroll it.
//   3. Otherwise `null`, which is what a browser answers for an id nothing
//      carries. An unknown id is never an error here and never a fabricated
//      element.
//
// The scan reads each element's current `id` attribute, so a container the
// renderer renames stops answering to its old id and starts answering to the
// new one, exactly as a live document would.
//
// Three divergences from a browser, stated rather than relied on:
//
//   - The scan covers every element `createElement` has produced, not the
//     document tree, because renderer tests mount into a detached parent that
//     is never appended to `document.body`. A browser would answer `null` for
//     all of them. Restricting the scan to `document.documentElement` would
//     make it useless here, so the wider scan is deliberate.
//   - Creation order therefore stands in for tree order when two elements claim
//     one id, and the first created wins. For anything the renderer produces
//     the two orders coincide, since a parent is created before its children
//     and siblings left to right. The consequence to know about is that an
//     element created, given an id and then discarded still shadows a later one
//     with the same id — within one test executable the registry is never
//     pruned. Give each case its own ids rather than sharing one across cases.
//   - For the same reason an element the renderer has REMOVED still answers to
//     its id, where a browser answers `null` once the node leaves the document.
//     A command naming a container the frame just removed therefore resolves to
//     the stale detached node here and performs a real `scrollTop` write on it,
//     rather than finding nothing. Both outcomes are no-ops on screen, so this
//     costs no fidelity in what a test can observe — but it does mean the
//     "target went away" branch cannot be expressed in this suite at all, and
//     belongs to the browser suites. No Playwright spec covers it yet; it is
//     recorded as an owned deferral, with the party and the moment, under
//     "E2E tests" in CONTRIBUTING.md.
//
// ## Focus
//
// A registered focus target's `focus()` records the call and becomes
// `activeElement`, and nothing else — those objects have no geometry to move.
//
// A real created element's `focus()` also moves a scroll offset, the way a
// browser's does with no options object: after becoming `activeElement` it is
// brought into view inside its nearest scrolling ancestor, which is moved by
// the smallest amount that shows it. "Nearest scrolling ancestor" is read off
// the inline `overflow` property, the same way a browser reads it, so an
// ordinary container between the element and a scroll container is stepped
// over rather than treated as a viewport.
//
// The equivalence stops at that ancestor, and the narrower claim is the one to
// rely on: this shim scrolls the NEAREST scrolling ancestor only, where a
// browser keeps walking outwards and scrolls every enclosing scrolling box up
// to and including the document itself. So a test here pins the innermost
// container's offset and nothing beyond it — a focus that also dragged an
// outer container, or the page, is invisible to this shim. Cover that outer
// movement in the browser suites, which can read `window.scrollY`.
//
// That second half is a platform default, not a convenience: a caller
// suppresses it by passing `{ preventScroll: true }`, and nothing in this repo
// passes any options at all. A shim whose `focus()` only logged would hide the
// fact that focusing an off-screen element overwrites a scroll offset another
// write just set.
//
// ## Inline style and the `style` attribute
//
// An element's inline style is reachable two ways, and in a browser they are
// one thing seen from two sides: `style.setProperty` edits a declaration, and
// the `style` attribute IS that declaration serialised. Writing the attribute
// therefore REPLACES the whole declaration, discarding every property already
// written through the style object.
//
// `setAttribute("style", …)` here routes into the style Proxy's `cssText`,
// which does exactly that — clear, then parse the new value. This is a
// platform default, not a convenience: the renderer writes a scroll
// container's `overflow` through the style object and then applies the
// application's `attrs`, so an application that puts a `style` pair in `attrs`
// silently wipes that overflow and the container stops scrolling.
// `Element.scroll`'s documentation says so; a shim that filed the attribute
// away in the attribute map instead would let a renderer applying `attrs`
// BEFORE the style pass go green against that documented consequence.
// `removeAttribute("style")` empties the declaration for the same reason.
//
// One divergence, in the read direction only: `getAttribute("style")` answers
// what `setAttribute` was given and `null` when it was never called, where a
// browser serialises the live declaration and so reports the renderer's own
// inline writes too. Nothing in this repo reads that attribute — the renderer
// compares attribute lists as OCaml values, never by reading the DOM back — so
// the two directions are not symmetric here and the write direction is the one
// to rely on.
//
// ## Maintenance Checklist (run when upgrading Brr)
//
// When Brr is upgraded to a new version, verify this shim still covers its
// internal DOM calls:
//
// 1. Build the tests: `opam exec -- dune runtest test/unit/nopal_web`
//    If tests pass, the shim is likely still sufficient.
//
// 2. If tests fail with "X is not a function" or "Cannot read property",
//    check which DOM API Brr's new version calls and add it here.
//
// 3. Key Brr entry points that hit the DOM (search brr's .ml files):
//    - `El.v`        -> document.createElement
//    - `El.txt`      -> document.createTextNode
//    - `El.append_children` / `El.set_children` -> appendChild, removeChild
//    - `El.set_at`   -> setAttribute / removeAttribute (a `style` name lands
//                       in the style declaration, not only the attribute map)
//    - `El.set_inline_style` -> style[prop] = value
//    - `Ev.listen`   -> addEventListener
//    - `Ev.unlisten`  -> removeEventListener
//    - `G.document`  -> globalThis.document
//    - `Document.find_el_by_id` -> document.getElementById
//    - `El.set_has_focus` -> element.focus()
//
// 4. After adding new shim APIs, add a corresponding test in
//    test_nopal_web.ml that exercises the new DOM path.

(function () {
  if (typeof globalThis.document !== "undefined") return;

  let idCounter = 0;

  // Every element createElement has produced, in creation order, so
  // getElementById can fall back to a scan of them. See "Element lookup by id"
  // in the header block for what this does and does not model.
  const createdElements = [];

  function makeClassList(el) {
    const classes = new Set();
    // _writes counts class assignments (add/remove), mirroring the inline-style
    // _writes counter below. Lets renderer tests assert that an unchanged
    // interactive re-render performs zero classList mutations (FR-2/NFR-1).
    const cl = {
      _writes: 0,
      add(c) { classes.add(c); cl._writes++; },
      remove(c) { classes.delete(c); cl._writes++; },
      contains(c) { return classes.has(c); },
      toString() { return [...classes].join(" "); },
    };
    return cl;
  }

  function makeStyle() {
    const props = {};
    // Inline-style write counter, mirroring the input `_valueWrites` pattern.
    // Lets renderer tests assert that an unchanged-style reconcile performs zero
    // inline-style writes (NFR-1). Brr's set_inline_style always routes through
    // setProperty (even for clears), so counting here covers every renderer
    // write. Kept off `props` so it never leaks into cssText/length.
    let writes = 0;
    return new Proxy(props, {
      get(target, prop) {
        if (prop === "_writes") return writes;
        if (prop === "setProperty")
          return (p, v, _prio) => { writes++; target[p] = v; };
        if (prop === "removeProperty")
          return (p) => { writes++; delete target[p]; };
        if (prop === "getPropertyValue")
          return (p) => target[p] || "";
        if (prop === "cssText") {
          return Object.entries(target)
            .filter(([k]) => typeof k === "string" && !k.startsWith("_"))
            .map(([k, v]) => k + ":" + v)
            .join(";");
        }
        if (prop === "length")
          return Object.keys(target).length;
        return target[prop] || "";
      },
      set(target, prop, value) {
        if (prop === "cssText") {
          // Clear and parse
          for (const k of Object.keys(target)) delete target[k];
          if (value) {
            value.split(";").forEach((part) => {
              const idx = part.indexOf(":");
              if (idx > 0) {
                target[part.slice(0, idx).trim()] = part.slice(idx + 1).trim();
              }
            });
          }
        } else {
          target[prop] = value;
        }
        return true;
      },
    });
  }

  // An element's own height when a test gave it one, and otherwise the extent
  // of whatever it contains — so an intermediate wrapper needs no layout of its
  // own and cannot contradict the rows inside it.
  function layoutHeight(el) {
    return el._layoutHeight !== undefined ? el._layoutHeight : contentExtent(el);
  }

  function contentExtent(el) {
    let extent = 0;
    for (const child of el.childNodes) {
      if (child.nodeType !== 1) continue;
      extent = Math.max(extent, (child._layoutTop || 0) + layoutHeight(child));
    }
    return extent;
  }

  // A scrolling box, read off the inline `overflow` property exactly as a
  // browser reads it. An ordinary container that merely happens to be taller
  // than its children is not one, so a focus walking outwards steps over it.
  function isScrollPort(el) {
    const overflow = el.style.overflow || "";
    return overflow === "auto" || overflow === "scroll";
  }

  // The browser's default when an element is focused with no options object:
  // bring it into view inside its nearest scrolling ancestor, moving that
  // ancestor by the smallest amount that shows it. Already-visible elements
  // move nothing. See "Focus" in the header block for why this is modelled.
  function scrollIntoNearestView(el) {
    let top = 0;
    let node = el;
    let parent = node.parentNode;
    while (parent && parent.nodeType === 1) {
      top += node._layoutTop || 0;
      if (isScrollPort(parent)) {
        const height = layoutHeight(el);
        const view = parent.clientHeight;
        const offset = parent.scrollTop;
        if (top < offset) parent.scrollTop = top;
        else if (top + height > offset + view)
          parent.scrollTop = top + height - view;
        return;
      }
      node = parent;
      parent = node.parentNode;
    }
  }

  // CSS.escape, per the CSSOM spec's serialize-an-identifier algorithm. Real
  // enough that a key escaped here parses as an identifier below, and that a
  // key which was NOT escaped does not.
  function cssEscape(value) {
    const string = String(value);
    const length = string.length;
    const firstCodeUnit = string.charCodeAt(0);
    let result = "";
    let index = -1;
    while (++index < length) {
      const codeUnit = string.charCodeAt(index);
      if (codeUnit === 0x0000) {
        result += "\uFFFD";
      } else if (
        (codeUnit >= 0x0001 && codeUnit <= 0x001f) ||
        codeUnit === 0x007f ||
        (index === 0 && codeUnit >= 0x0030 && codeUnit <= 0x0039) ||
        (index === 1 &&
          codeUnit >= 0x0030 &&
          codeUnit <= 0x0039 &&
          firstCodeUnit === 0x002d)
      ) {
        result += "\\" + codeUnit.toString(16) + " ";
      } else if (index === 0 && length === 1 && codeUnit === 0x002d) {
        result += "\\" + string.charAt(index);
      } else if (
        codeUnit >= 0x0080 ||
        codeUnit === 0x002d ||
        codeUnit === 0x005f ||
        (codeUnit >= 0x0030 && codeUnit <= 0x0039) ||
        (codeUnit >= 0x0041 && codeUnit <= 0x005a) ||
        (codeUnit >= 0x0061 && codeUnit <= 0x007a)
      ) {
        result += string.charAt(index);
      } else {
        result += "\\" + string.charAt(index);
      }
    }
    return result;
  }

  const IDENT_CHAR = /[-_A-Za-z0-9\u00a0-\uffff]/;

  // Read an attribute selector's value back to the string it names. A character
  // that may not appear unescaped in an identifier is a SyntaxError, which is
  // what a browser raises too — so a selector built from a raw consumer key
  // fails loudly here instead of silently matching nothing.
  function unescapeIdent(token, selector) {
    let out = "";
    let i = 0;
    while (i < token.length) {
      const ch = token.charAt(i);
      if (ch === "\\") {
        const rest = token.slice(i + 1);
        const hex = /^([0-9a-fA-F]{1,6}) ?/.exec(rest);
        if (hex) {
          out += String.fromCodePoint(parseInt(hex[1], 16));
          i += 1 + hex[0].length;
        } else if (rest.length > 0) {
          out += rest.charAt(0);
          i += 2;
        } else {
          throw new SyntaxError("dom_shim: trailing '\\' in '" + selector + "'");
        }
        continue;
      }
      if (!IDENT_CHAR.test(ch)) {
        throw new SyntaxError(
          "dom_shim: '" + selector + "' is not a valid selector"
        );
      }
      out += ch;
      i += 1;
    }
    return out;
  }

  const ATTR_SELECTOR = /^\[([A-Za-z_-][A-Za-z0-9_-]*)(?:=([\s\S]+))?\]$/;

  // The one selector shape the renderer builds: [attr] or [attr=value].
  // Anything else is unsupported rather than quietly matching nothing.
  function parseSelector(selector) {
    const parts = ATTR_SELECTOR.exec(String(selector).trim());
    if (parts === null) {
      throw new SyntaxError(
        "dom_shim: unsupported selector '" + selector + "'"
      );
    }
    return {
      name: parts[1],
      value: parts[2] === undefined ? null : unescapeIdent(parts[2], selector),
    };
  }

  function makeNode(nodeType, nodeName) {
    const node = {
      _id: ++idCounter,
      nodeType: nodeType,
      nodeName: nodeName,
      childNodes: [],
      parentNode: null,
      ownerDocument: null,
      _textContent: "",
      _listeners: {},
      _attributes: {},
    };

    Object.defineProperty(node, "textContent", {
      get() {
        if (node.nodeType === 3) return node._textContent;
        return node.childNodes.map((c) => c.textContent || "").join("");
      },
      set(v) {
        node._textContent = v;
      },
    });

    node.appendChild = function (child) {
      if (child.parentNode) child.parentNode.removeChild(child);
      child.parentNode = node;
      node.childNodes.push(child);
      return child;
    };

    node.append = function (...args) {
      for (const a of args) node.appendChild(a);
    };

    node.prepend = function (...args) {
      for (let i = args.length - 1; i >= 0; i--) {
        const child = args[i];
        if (child.parentNode) child.parentNode.removeChild(child);
        child.parentNode = node;
        node.childNodes.unshift(child);
      }
    };

    node.insertBefore = function (newChild, refChild) {
      if (newChild.parentNode) newChild.parentNode.removeChild(newChild);
      newChild.parentNode = node;
      if (refChild === null) {
        node.childNodes.push(newChild);
      } else {
        const idx = node.childNodes.indexOf(refChild);
        if (idx >= 0) node.childNodes.splice(idx, 0, newChild);
        else node.childNodes.push(newChild);
      }
      return newChild;
    };

    node.removeChild = function (child) {
      const idx = node.childNodes.indexOf(child);
      if (idx >= 0) {
        node.childNodes.splice(idx, 1);
        child.parentNode = null;
      }
      return child;
    };

    node.replaceChild = function (newChild, oldChild) {
      const idx = node.childNodes.indexOf(oldChild);
      if (idx >= 0) {
        if (newChild.parentNode) newChild.parentNode.removeChild(newChild);
        node.childNodes[idx] = newChild;
        newChild.parentNode = node;
        oldChild.parentNode = null;
      }
      return oldChild;
    };

    node.replaceWith = function (...args) {
      if (node.parentNode) {
        const parent = node.parentNode;
        const idx = parent.childNodes.indexOf(node);
        if (idx >= 0) {
          parent.childNodes.splice(idx, 1, ...args);
          node.parentNode = null;
          for (const a of args) a.parentNode = parent;
        }
      }
    };

    node.remove = function () {
      if (node.parentNode) node.parentNode.removeChild(node);
    };

    node.before = function (...args) {
      if (node.parentNode) {
        const parent = node.parentNode;
        const idx = parent.childNodes.indexOf(node);
        for (let i = 0; i < args.length; i++) {
          const a = args[i];
          if (a.parentNode) a.parentNode.removeChild(a);
          a.parentNode = parent;
          parent.childNodes.splice(idx + i, 0, a);
        }
      }
    };

    node.after = function (...args) {
      if (node.parentNode) {
        const parent = node.parentNode;
        const idx = parent.childNodes.indexOf(node);
        for (let i = 0; i < args.length; i++) {
          const a = args[i];
          if (a.parentNode) a.parentNode.removeChild(a);
          a.parentNode = parent;
          parent.childNodes.splice(idx + 1 + i, 0, a);
        }
      }
    };

    // Node.contains, self-inclusive: true when `other` is this node or a
    // descendant of it, false for anything else including null. The renderer's
    // focus wiring asks the platform this question about the other end of a
    // focus transition, and answering it from the parent chain is the whole of
    // what the real method does. Modelled here rather than stubbed, because a
    // shim that always answered false would let a renderer with no containment
    // guard pass while reporting every move inside a container as a departure.
    node.contains = function (other) {
      let n = other;
      while (n) {
        if (n === node) return true;
        n = n.parentNode;
      }
      return false;
    };

    node.addEventListener = function (type, fn, _opts) {
      if (!node._listeners[type]) node._listeners[type] = [];
      node._listeners[type].push(fn);
    };

    node.removeEventListener = function (type, fn, _opts) {
      const arr = node._listeners[type];
      if (arr) {
        const idx = arr.indexOf(fn);
        if (idx >= 0) arr.splice(idx, 1);
      }
    };

    node.dispatchEvent = function (ev) {
      ev.target = node;
      ev.currentTarget = node;
      const arr = node._listeners[ev.type];
      if (arr) {
        for (const fn of [...arr]) fn(ev);
      }
      return !ev.defaultPrevented;
    };

    Object.defineProperty(node, "firstChild", {
      get() {
        return node.childNodes.length > 0 ? node.childNodes[0] : null;
      },
    });

    Object.defineProperty(node, "nextSibling", {
      get() {
        if (!node.parentNode) return null;
        const sibs = node.parentNode.childNodes;
        const idx = sibs.indexOf(node);
        return idx >= 0 && idx + 1 < sibs.length ? sibs[idx + 1] : null;
      },
    });

    Object.defineProperty(node, "children", {
      get() {
        return node.childNodes.filter((c) => c.nodeType === 1);
      },
    });

    Object.defineProperty(node, "previousElementSibling", {
      get() {
        if (!node.parentNode) return null;
        const sibs = node.parentNode.childNodes;
        const idx = sibs.indexOf(node);
        for (let i = idx - 1; i >= 0; i--) {
          if (sibs[i].nodeType === 1) return sibs[i];
        }
        return null;
      },
    });

    // Descendants matching one attribute selector, in document order (a node is
    // visited before the subtree below it). Elements only: a text or comment
    // node carries no attributes.
    node.querySelectorAll = function (selector) {
      const spec = parseSelector(selector);
      const found = [];
      const walk = function (parent) {
        for (const child of parent.childNodes) {
          if (child.nodeType !== 1) continue;
          const value = child.getAttribute(spec.name);
          if (value !== null && (spec.value === null || value === spec.value)) {
            found.push(child);
          }
          walk(child);
        }
      };
      walk(node);
      return found;
    };

    node.querySelector = function (selector) {
      const found = node.querySelectorAll(selector);
      return found.length > 0 ? found[0] : null;
    };

    Object.defineProperty(node, "nextElementSibling", {
      get() {
        if (!node.parentNode) return null;
        const sibs = node.parentNode.childNodes;
        const idx = sibs.indexOf(node);
        for (let i = idx + 1; i < sibs.length; i++) {
          if (sibs[i].nodeType === 1) return sibs[i];
        }
        return null;
      },
    });

    return node;
  }

  function createElement(tag) {
    const el = makeNode(1, tag.toUpperCase());
    el.tagName = tag.toUpperCase();
    el.style = makeStyle();
    el.classList = makeClassList(el);

    el.setAttribute = function (name, value) {
      el._attributes[name] = String(value);
      // The `style` attribute IS the element's inline style declaration, so a
      // write to it replaces the declaration wholesale rather than sitting
      // beside it. Routed through the Proxy's `cssText` for exactly that
      // reason — see "Inline style and the `style` attribute" in the header.
      if (name === "style") el.style.cssText = String(value);
      if (name === "value") el.value = String(value);
    };
    el.getAttribute = function (name) {
      return el._attributes[name] !== undefined
        ? el._attributes[name]
        : null;
    };
    el.hasAttribute = function (name) {
      return name in el._attributes;
    };
    el.removeAttribute = function (name) {
      delete el._attributes[name];
      // Removing the attribute empties the declaration it stood for, so a
      // dropped `style` pair does not leave a phantom inline style behind.
      if (name === "style") el.style.cssText = "";
    };

    // Vertical layout. `_layoutTop` is where a test put this element inside its
    // parent's content and `_clientHeight` how much of its own content is
    // visible; both start at the platform's value for an element nobody has
    // laid out. `_layoutHeight` stays undefined so an un-laid-out element takes
    // the extent of its children rather than a fabricated zero.
    el._layoutTop = 0;
    el._borderTop = 0;
    el._clientHeight = 0;
    el._scrollTop = 0;
    el._scrollWrites = 0;

    Object.defineProperty(el, "clientHeight", {
      get() { return el._clientHeight; },
      configurable: true,
    });

    // The width of the top border, which is what separates the top of an
    // element's bounding box from the origin its own scroll offset counts from.
    // A test that gives a container a border therefore moves its content
    // without moving the container, which is a distinction a renderer
    // computing a content-relative position has to make.
    Object.defineProperty(el, "clientTop", {
      get() { return el._borderTop; },
      configurable: true,
    });

    Object.defineProperty(el, "scrollHeight", {
      get() { return Math.max(el._clientHeight, contentExtent(el)); },
      configurable: true,
    });

    Object.defineProperty(el, "scrollTop", {
      get() { return el._scrollTop; },
      set(v) {
        const max = Math.max(0, el.scrollHeight - el.clientHeight);
        el._scrollTop = Math.max(0, Math.min(Number(v), max));
        el._scrollWrites++;
      },
      configurable: true,
    });

    // Viewport-relative, so every ancestor's position adds and every ancestor's
    // scroll offset subtracts. This is what makes a child's rect move when the
    // container it lives in scrolls.
    el.getBoundingClientRect = function () {
      const height = layoutHeight(el);
      let top = 0;
      let node = el;
      while (node && node.nodeType === 1) {
        top += node._layoutTop || 0;
        const parent = node.parentNode;
        if (parent && parent.nodeType === 1) {
          top -= parent._scrollTop || 0;
          top += parent._borderTop || 0;
        }
        node = parent;
      }
      return {
        x: 0, y: top, width: 0, height: height,
        top: top, right: 0, bottom: top + height, left: 0,
      };
    };

    // See "Focus" in the header block: activeElement, the same log a
    // registered target writes, and the platform's own scroll-into-view.
    el.focus = function () {
      const doc = globalThis.document;
      doc.activeElement = el;
      doc._focusLog.push(el.getAttribute("id") || "");
      scrollIntoNearestView(el);
    };

    // innerHTML setter: clears all children (write) and serializes (read)
    Object.defineProperty(el, "innerHTML", {
      get() {
        return "";
      },
      set(_v) {
        // Clear all children (the renderer uses innerHTML="" to wipe)
        while (el.childNodes.length > 0) {
          const child = el.childNodes[el.childNodes.length - 1];
          child.parentNode = null;
          el.childNodes.pop();
        }
      },
    });

    // For <select> elements, selection is carried by the option children's
    // `selected` flag. Until selection is set explicitly (via value or
    // selectedIndex), the browser auto-selects the first option
    // (selectedIndex 0) — exactly the default the renderer must override when
    // the model value matches no option (FR-4).
    if (tag.toLowerCase() === "select") {
      el._selectionExplicit = false;
      Object.defineProperty(el, "selectedIndex", {
        get() {
          for (let i = 0; i < el.childNodes.length; i++) {
            if (el.childNodes[i].selected) return i;
          }
          if (el._selectionExplicit) return -1;
          return el.childNodes.length > 0 ? 0 : -1;
        },
        set(i) {
          el._selectionExplicit = true;
          for (let j = 0; j < el.childNodes.length; j++) {
            el.childNodes[j].selected = (j === i);
          }
        },
        configurable: true,
      });
      Object.defineProperty(el, "value", {
        get() {
          const idx = el.selectedIndex;
          if (idx >= 0 && idx < el.childNodes.length)
            return el.childNodes[idx]._attributes["value"] || "";
          return "";
        },
        set(v) {
          el._selectionExplicit = true;
          for (const child of el.childNodes) {
            child.selected = (child._attributes["value"] === v);
          }
        },
        configurable: true,
      });
    } else if (tag.toLowerCase() === "input" || tag.toLowerCase() === "textarea") {
      // Back `value` with a write counter so renderer tests can assert that a
      // controlled input skips the redundant write when the value is unchanged
      // (a no-op write would collapse the caret/selection/IME — NFR-3).
      el._value = "";
      el._valueWrites = 0;
      Object.defineProperty(el, "value", {
        get() { return el._value; },
        set(v) { el._value = String(v); el._valueWrites++; },
        configurable: true,
        enumerable: true,
      });
    }

    createdElements.push(el);
    return el;
  }

  function createTextNode(text) {
    const node = makeNode(3, "#text");
    node.textContent = text;
    node.data = text;
    return node;
  }

  function createComment(text) {
    const node = makeNode(8, "#comment");
    node.textContent = text;
    node.data = text;
    return node;
  }

  function makeEvent(type, opts) {
    return {
      type: type,
      bubbles: (opts && opts.bubbles) || false,
      cancelable: (opts && opts.cancelable) || false,
      composed: (opts && opts.composed) || false,
      defaultPrevented: false,
      isTrusted: false,
      timeStamp: Date.now(),
      target: null,
      currentTarget: null,
      stopPropagation() {},
      stopImmediatePropagation() {},
      preventDefault() {
        this.defaultPrevented = true;
      },
      ...(opts || {}),
    };
  }

  const body = createElement("body");
  const head = createElement("head");
  const documentElement = createElement("html");
  documentElement.appendChild(head);
  documentElement.appendChild(body);

  const doc = {
    nodeType: 9,
    nodeName: "#document",
    documentElement: documentElement,
    body: body,
    head: head,
    activeElement: null,
    visibilityState: "visible",
    createElement: createElement,
    createTextNode: createTextNode,
    createComment: createComment,
    // Focus test support. A registered target records every focus() call in
    // order into _focusLog and updates activeElement, so a test can assert the
    // drain order and the last-wins result of Nopal_web.drain_focus. Registered
    // targets take precedence over the created-element scan in getElementById
    // below; see "Element lookup by id" in the header block for the full order
    // and for what the scan does and does not model.
    _focusLog: [],
    _focusTargets: {},
    _registerFocusTarget: function (id) {
      const self = this;
      const el = {
        id: id,
        focus: function () {
          self._focusLog.push(id);
          self.activeElement = el;
        },
      };
      self._focusTargets[id] = el;
      return el;
    },
    getElementById: function (id) {
      if (Object.prototype.hasOwnProperty.call(this._focusTargets, id))
        return this._focusTargets[id];
      for (const el of createdElements) {
        if (el.getAttribute("id") === id) return el;
      }
      return null;
    },
    getElementsByName: function (_name) { return []; },
  };

  body.ownerDocument = doc;
  head.ownerDocument = doc;
  documentElement.ownerDocument = doc;

  globalThis.document = doc;
  globalThis.window = globalThis;
  globalThis.Event = function (type, opts) { return makeEvent(type, opts); };
  globalThis.KeyboardEvent = function (type, opts) { return makeEvent(type, opts); };
  globalThis.InputEvent = function (type, opts) { return makeEvent(type, opts); };
  globalThis.CSS = { escape: cssEscape };
  globalThis.getComputedStyle = function (el) { return el.style; };
  globalThis.requestAnimationFrame = function (cb) { setTimeout(cb, 0); return 0; };
  globalThis.cancelAnimationFrame = function () {};
  globalThis.navigator = { userAgent: "node" };
})();
