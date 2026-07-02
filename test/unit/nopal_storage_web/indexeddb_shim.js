// indexeddb_shim.js — minimal in-memory globalThis.indexedDB fake for Node tests.
//
// Mirrors the role fetch_shim.js plays for nopal_http_web: it implements only
// the slice of the IndexedDB API that nopal_storage_web exercises, so the
// backend's request/transaction event wiring can be tested without a browser.
//
// Implemented surface:
//   indexedDB.open(name, version) -> IDBRequest-shaped object that fires
//     onupgradeneeded (new databases only) then onsuccess, with .result = db
//   db.objectStoreNames.contains(name), db.createObjectStore(name),
//     db.transaction(name, mode).objectStore(name)
//   store.get(key) / put(value, key) / delete(key) / getAllKeys() / clear(),
//     each returning an IDBRequest whose onsuccess/onerror fires on a macrotask
//
// Keys are out-of-line strings (put(value, key)). A minimal localStorage shim
// is also provided so the REQ-N3 test can assert clear() leaves localStorage
// untouched.

// Matches fetch_shim.js: runs the callback after the macrotask + microtask
// queues drain, so all chained IndexedDB requests have resolved before
// assertions run.
globalThis._flush = function (cb) { setTimeout(cb, 100); };

// --- minimal localStorage ---
(function () {
  var ls = { _data: {} };
  ls.getItem = function (k) {
    return Object.prototype.hasOwnProperty.call(this._data, k)
      ? this._data[k]
      : null;
  };
  ls.setItem = function (k, v) { this._data[k] = String(v); };
  ls.removeItem = function (k) { delete this._data[k]; };
  globalThis.localStorage = ls;
})();

// --- minimal indexedDB ---
(function () {
  // Persistent store data, keyed by database name. Survives repeated open()
  // calls within a test run, the way a real IndexedDB persists across reopens.
  // Pre-seed the backend's kv store with one non-string value under
  // "__corrupt__" so the "non-string value surfaces as Error" test can exercise
  // get's typeof guard (Store.set only ever writes strings, so it could not
  // produce this value itself).
  var databases = {
    nopal_storage: { stores: { kv: { __corrupt__: 42 } } },
  };

  // Connection lifecycle counters so the "each op closes its handle" test can
  // assert every open() was matched by a db.close(). A real IndexedDB leaks a
  // held-open connection into a versionchange block on the next schema upgrade;
  // these counters make that leak observable in the shim.
  var openCount = 0;
  var closeCount = 0;
  globalThis.__idbOpenCount = function () { return openCount; };
  globalThis.__idbCloseCount = function () { return closeCount; };

  function fireSuccess(req, result) {
    setTimeout(function () {
      req.result = result;
      if (typeof req.onsuccess === "function") req.onsuccess({ target: req });
    }, 0);
  }

  function makeObjectStore(storeData) {
    return {
      get: function (key) {
        var req = {};
        var has = Object.prototype.hasOwnProperty.call(storeData, key);
        fireSuccess(req, has ? storeData[key] : undefined);
        return req;
      },
      put: function (value, key) {
        var req = {};
        storeData[key] = value;
        fireSuccess(req, key);
        return req;
      },
      delete: function (key) {
        var req = {};
        delete storeData[key];
        fireSuccess(req, undefined);
        return req;
      },
      getAllKeys: function () {
        var req = {};
        fireSuccess(req, Object.keys(storeData));
        return req;
      },
      clear: function () {
        var req = {};
        Object.keys(storeData).forEach(function (k) { delete storeData[k]; });
        fireSuccess(req, undefined);
        return req;
      },
    };
  }

  function makeDb(dbRec) {
    return {
      objectStoreNames: {
        contains: function (name) {
          return Object.prototype.hasOwnProperty.call(dbRec.stores, name);
        },
      },
      createObjectStore: function (name) {
        if (!dbRec.stores[name]) dbRec.stores[name] = {};
        return makeObjectStore(dbRec.stores[name]);
      },
      transaction: function (_storeName, _mode) {
        return {
          objectStore: function (name) {
            if (!dbRec.stores[name]) dbRec.stores[name] = {};
            return makeObjectStore(dbRec.stores[name]);
          },
        };
      },
      close: function () { closeCount += 1; },
    };
  }

  globalThis.indexedDB = {
    open: function (name, _version) {
      var req = {};
      var isNew = !databases[name];
      if (isNew) databases[name] = { stores: {} };
      var db = makeDb(databases[name]);
      setTimeout(function () {
        req.result = db;
        openCount += 1;
        if (isNew && typeof req.onupgradeneeded === "function") {
          req.onupgradeneeded({ target: req });
        }
        if (typeof req.onsuccess === "function") req.onsuccess({ target: req });
      }, 0);
      return req;
    },
  };
})();
