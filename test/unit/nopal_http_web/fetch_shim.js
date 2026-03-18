// fetch_shim.js — minimal globalThis.fetch fake for Node.js tests
//
// URL patterns:
//   contains "success"       → 200 OK, body "ok body"
//   contains "404"           → 404 Not Found, body "not found"
//   contains "network-error" → reject with TypeError("network failure")
//   contains "body-error"    → 200 OK, but text() rejects with TypeError("body read failed")
//
// POST / request with init:
//   method, headers, and body from the init object are echoed back as JSON
//   in the response body, so tests can verify they were sent correctly.

// setTimeout(0) trampoline: runs callback after all microtasks have flushed.
// Used by tests to defer assertions until Fetch Promise chains complete.
globalThis._flush = function (cb) { setTimeout(cb, 0); };

// Always override: Node.js 18+ has native fetch, but tests need the fake.
(function () {
  globalThis.fetch = function (url, init) {
    url = typeof url === "string" ? url : String(url);
    var method = (init && init.method) ? String(init.method) : "GET";
    var rawHeaders = (init && init.headers) ? init.headers : {};
    var reqBody = (init && init.body) ? String(init.body) : "";

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
        headers: new Map(),
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
      headers: new Map(),
    });
  };
})();
