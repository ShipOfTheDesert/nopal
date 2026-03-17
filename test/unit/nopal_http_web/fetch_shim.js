// fetch_shim.js — minimal globalThis.fetch fake for Node.js tests
//
// URL patterns:
//   contains "success"       → 200 OK, body "ok body"
//   contains "404"           → 404 Not Found, body "not found"
//   contains "network-error" → reject with TypeError("network failure")
//   contains "body-error"    → 200 OK, but text() rejects with TypeError("body read failed")

// setTimeout(0) trampoline: runs callback after all microtasks have flushed.
// Used by tests to defer assertions until Fetch Promise chains complete.
globalThis._flush = function (cb) { setTimeout(cb, 0); };

// Always override: Node.js 18+ has native fetch, but tests need the fake.
(function () {
  globalThis.fetch = function (url) {
    url = typeof url === "string" ? url : String(url);

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
