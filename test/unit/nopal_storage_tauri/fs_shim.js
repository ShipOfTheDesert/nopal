// Minimal tauri-plugin-fs v2 runtime stub for the nopal_storage_tauri backend
// tests (loaded via the test target's (javascript_files)).
//
// The point of this shim is the RESPONSE SHAPE, which is where the backend was
// wrong on real hardware. `plugin:fs|read_text_file` is declared in Rust as
// `CommandResult<tauri::ipc::Response>` — i.e. `InvokeResponseBody::Raw` — so
// tauri never hands JavaScript a string for it. It hands over the file's BYTES:
// an ArrayBuffer on the custom-protocol transport (`response.arrayBuffer()`)
// and on the postMessage/channel transport that Android uses
// (`new Uint8Array([...]).buffer`), and a plain number array on macOS/iOS. This
// shim answers with an ArrayBuffer, the shape the Android handset actually
// delivered; the number-array shape is covered as a decode case.
//
// `plugin:fs|write_text_file` is the raw-body form: the content arrives as the
// second `invoke` argument (a Uint8Array from TextEncoder), with the path and
// options as request headers rather than as args. The shim stores the bytes
// verbatim, so a set/get round-trip proves encode and decode are inverse rather
// than merely both present.
//
// `_flush(cb)` defers assertions until every pending promise has settled — the
// backend resolves through `Fut.of_promise`/`Fut.await`, whose hops are
// microtask-deferred, so nothing here can be observed synchronously.
globalThis._flush = function (cb) {
  setTimeout(cb, 100);
};

(function () {
  // filename -> Uint8Array. One flat map, mirroring the single scoped
  // directory the backend confines itself to.
  var files = {};
  var dirs = {};
  // Which shape `plugin:fs|read_text_file` answers with. "buffer" is the real
  // Android/Linux/Windows shape; "array" is macOS/iOS, where a raw body is
  // serialized as a JSON number array; "bogus" is neither, and exists to prove
  // the decoder resolves Error rather than raising — a decoder that raised
  // would leave the task pending forever, because it runs inside Fut.await,
  // past the point Nopal_mvu.Task.guard can catch anything.
  var readShape = "buffer";

  globalThis.__nopal_fs_files = files;
  globalThis.__nopal_fs_seed = function (name, text) {
    files[name] = new TextEncoder().encode(text);
  };
  globalThis.__nopal_fs_set_read_shape = function (shape) {
    readShape = shape;
  };
  globalThis.__nopal_fs_read = function (name) {
    return new TextDecoder().decode(files[name]);
  };

  function entries() {
    return Object.keys(files).map(function (name) {
      return {
        name: name,
        isDirectory: false,
        isFile: true,
        isSymlink: false,
      };
    });
  }

  function basename(path) {
    var i = path.lastIndexOf("/");
    return i < 0 ? path : path.slice(i + 1);
  }

  globalThis.__TAURI_INTERNALS__ = {
    transformCallback: function (cb) {
      return cb;
    },
    invoke: function (cmd, args, opts) {
      if (cmd === "plugin:fs|mkdir") {
        dirs[args.path] = true;
        return Promise.resolve(null);
      }
      if (cmd === "plugin:fs|read_dir") {
        return Promise.resolve(entries());
      }
      if (cmd === "plugin:fs|write_text_file") {
        // Raw-body contract: `args` IS the body (a Uint8Array), and the path
        // travels percent-encoded in opts.headers.path.
        var path = decodeURIComponent(opts.headers.path);
        files[basename(path)] = new Uint8Array(args);
        return Promise.resolve(null);
      }
      if (cmd === "plugin:fs|read_text_file") {
        var name = basename(args.path);
        if (!Object.prototype.hasOwnProperty.call(files, name)) {
          return Promise.reject(new Error("path not allowed / not found"));
        }
        var bytes = files[name];
        if (readShape === "array") {
          return Promise.resolve(Array.from(bytes));
        }
        if (readShape === "bogus") {
          return Promise.resolve({ not: "bytes" });
        }
        // The shape that broke the app: BYTES, not text.
        return Promise.resolve(bytes.buffer.slice(0));
      }
      if (cmd === "plugin:fs|remove") {
        delete files[basename(args.path)];
        return Promise.resolve(null);
      }
      return Promise.reject(new Error("unstubbed command: " + cmd));
    },
  };
})();
