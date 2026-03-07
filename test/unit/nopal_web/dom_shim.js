// Minimal DOM shim for running Brr-based tests under Node.js via js_of_ocaml.
//
// Brr expects a browser-like global environment (document, window, Event,
// KeyboardEvent, etc.). This shim provides the subset of DOM APIs that Brr
// and the renderer actually call:
//
//   - document.createElement, createTextNode, createComment
//   - Element: appendChild, removeChild, replaceChild, insertBefore,
//     setAttribute, getAttribute, style (Proxy-based), classList,
//     addEventListener, removeEventListener, dispatchEvent
//   - window.requestAnimationFrame, setTimeout, getComputedStyle
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
// It does NOT provide layout, rendering, or network APIs. Nodes track their
// parent/child relationships in plain JS arrays so that tests can assert on
// DOM structure without a real browser engine.
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
//    - `El.set_at`   -> setAttribute / removeAttribute
//    - `El.set_inline_style` -> style[prop] = value
//    - `Ev.listen`   -> addEventListener
//    - `Ev.unlisten`  -> removeEventListener
//    - `G.document`  -> globalThis.document
//
// 4. After adding new shim APIs, add a corresponding test in
//    test_nopal_web.ml that exercises the new DOM path.

(function () {
  if (typeof globalThis.document !== "undefined") return;

  let idCounter = 0;

  function makeClassList(el) {
    const classes = new Set();
    return {
      add(c) { classes.add(c); },
      remove(c) { classes.delete(c); },
      contains(c) { return classes.has(c); },
      toString() { return [...classes].join(" "); },
    };
  }

  function makeStyle() {
    const props = {};
    return new Proxy(props, {
      get(target, prop) {
        if (prop === "setProperty")
          return (p, v, _prio) => { target[p] = v; };
        if (prop === "removeProperty")
          return (p) => { delete target[p]; };
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
    };

    el.getBoundingClientRect = function () {
      return { x: 0, y: 0, width: 0, height: 0, top: 0, right: 0, bottom: 0, left: 0 };
    };

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
    getElementById: function (_id) { return null; },
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
  globalThis.getComputedStyle = function (el) { return el.style; };
  globalThis.requestAnimationFrame = function (cb) { setTimeout(cb, 0); return 0; };
  globalThis.cancelAnimationFrame = function () {};
  globalThis.navigator = { userAgent: "node" };
})();
