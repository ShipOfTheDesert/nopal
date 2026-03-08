// Minimal browser API shim for Node.js testing of Platform_web.
// Provides window.location and window.history with pushState/replaceState.

if (typeof globalThis.window === "undefined") {
  var loc = { pathname: "/", search: "", hash: "" };

  var history_stack = ["/"];
  var history_index = 0;

  globalThis.window = {
    location: loc,
    history: {
      pushState: function (_state, _title, url) {
        var path = url.split("?")[0].split("#")[0];
        history_index++;
        history_stack.splice(history_index, history_stack.length - history_index, path);
        loc.pathname = path;
      },
      replaceState: function (_state, _title, url) {
        var path = url.split("?")[0].split("#")[0];
        history_stack[history_index] = path;
        loc.pathname = path;
      },
      back: function () {
        if (history_index > 0) {
          history_index--;
          loc.pathname = history_stack[history_index];
        }
      },
    },
    _listeners: {},
    addEventListener: function (type, fn) {
      if (!this._listeners[type]) this._listeners[type] = [];
      this._listeners[type].push(fn);
    },
    removeEventListener: function (type, fn) {
      if (!this._listeners[type]) return;
      this._listeners[type] = this._listeners[type].filter(function (f) { return f !== fn; });
    },
    _getListenerCount: function (type) {
      return (this._listeners[type] || []).length;
    },
  };

  globalThis.location = loc;
  globalThis.history = globalThis.window.history;
}
