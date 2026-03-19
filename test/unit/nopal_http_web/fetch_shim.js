// fetch_shim.js — minimal globalThis.fetch fake for Node.js tests
//
// Requires Node.js >= 18 for native Headers, AbortController, DOMException.
//
// URL patterns:
//   contains "success"       -> 200 OK, body "ok body"
//   contains "404"           -> 404 Not Found, body "not found"
//   contains "network-error" -> reject with TypeError("network failure")
//   contains "body-error"    -> 200 OK, but text() rejects with TypeError("body read failed")
//   contains "delay"         -> delays response (for timeout/abort tests)
//
// POST / request with init:
//   method, headers, and body from the init object are echoed back as JSON
//   in the response body, so tests can verify they were sent correctly.
//
// Response headers (all routes except network-error):
//   content-type: application/json
//   x-request-id: test-123

// Runtime guard: fail fast with a clear message instead of mysterious errors.
if (typeof Headers === "undefined") {
  throw new Error(
    "fetch_shim.js requires Node.js >= 18 (missing Headers global). " +
    "Run 'nvm use' to pick up the .nvmrc version."
  );
}

// setTimeout trampoline: runs callback after macrotask + microtask flush.
// 150ms gives enough time for AbortController timeout tests to complete
// their abort -> reject -> dispatch chain before assertions run.
globalThis._flush = function (cb) { setTimeout(cb, 150); };

// Override FormData so tests control its shape. The polyfill exposes
// _entries for the shim to serialise into the echoed response body.
globalThis.FormData = function () { this._entries = []; };
globalThis.FormData.prototype.append = function (name, value) {
  this._entries.push([name, value]);
};

// Helper: build standard response headers using the native Headers API.
// Uses the same API surface as the browser, so Brr's Headers.to_assoc
// iterates these identically to real fetch responses.
function makeRespHeaders(extra) {
  var h = new Headers();
  h.set("content-type", "application/json");
  h.set("x-request-id", "test-123");
  if (extra) {
    for (var k in extra) {
      if (extra.hasOwnProperty(k)) h.set(k, extra[k]);
    }
  }
  return h;
}

function makeAbortError() {
  return new DOMException("The operation was aborted.", "AbortError");
}

// Always override: Node.js 18+ has native fetch, but tests need the fake.
(function () {
  globalThis.fetch = function (url, init) {
    url = typeof url === "string" ? url : String(url);
    var method = (init && init.method) ? String(init.method) : "GET";
    var rawHeaders = (init && init.headers) ? init.headers : {};

    // Extract request body — handle FormData polyfill and strings.
    var reqBody;
    if (init && init.body != null) {
      if (init.body._entries) {
        // FormData polyfill: serialise entries as JSON array
        reqBody = JSON.stringify(init.body._entries);
      } else {
        reqBody = String(init.body);
      }
    } else {
      reqBody = "";
    }

    // Normalise Headers objects (browser/Node.js native) to a plain object
    // so JSON.stringify can echo them back and hasHeaders detection works.
    var reqHeaders = {};
    if (typeof rawHeaders.forEach === "function") {
      rawHeaders.forEach(function (v, k) { reqHeaders[k] = v; });
    } else if (typeof rawHeaders === "object") {
      reqHeaders = rawHeaders;
    }

    if (url.indexOf("network-error") !== -1) {
      return Promise.reject(new TypeError("network failure"));
    }

    if (url.indexOf("body-error") !== -1) {
      return Promise.resolve({
        status: 200,
        ok: true,
        text: function () {
          return Promise.reject(new TypeError("body read failed"));
        },
        headers: new Headers({ "content-type": "text/plain" }),
      });
    }

    // Delay route: holds the response for 10 seconds. If an AbortSignal
    // is provided, an abort rejects with an AbortError — matching the
    // browser fetch behaviour that nopal_http_web relies on.
    if (url.indexOf("delay") !== -1) {
      var signal = init && init.signal;
      return new Promise(function (resolve, reject) {
        var tid = setTimeout(function () {
          resolve({
            status: 200,
            ok: true,
            text: function () { return Promise.resolve("delayed response"); },
            headers: makeRespHeaders(),
          });
        }, 10000);
        if (signal) {
          if (signal.aborted) {
            clearTimeout(tid);
            reject(makeAbortError());
            return;
          }
          signal.addEventListener("abort", function () {
            clearTimeout(tid);
            reject(makeAbortError());
          });
        }
      });
    }

    var status, ok, body;
    if (url.indexOf("404") !== -1) {
      status = 404;
      ok = false;
      body = "not found";
    } else {
      status = 200;
      ok = true;
      body = "ok body";
    }

    // For non-GET requests or requests with headers, echo request details
    // as JSON so tests can verify method, headers, and body were sent.
    var hasHeaders = false;
    if (typeof reqHeaders === "object") {
      for (var k in reqHeaders) {
        if (reqHeaders.hasOwnProperty(k)) { hasHeaders = true; break; }
      }
    }
    if (method !== "GET" || hasHeaders) {
      body = JSON.stringify({
        method: method,
        headers: reqHeaders,
        body: reqBody,
      });
    }

    return Promise.resolve({
      status: status,
      ok: ok,
      text: function () {
        return Promise.resolve(body);
      },
      headers: makeRespHeaders(),
    });
  };
})();
