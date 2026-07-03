package run.nopal.kitchen_sink

import android.os.Bundle
import android.webkit.WebView
import androidx.activity.OnBackPressedCallback
import androidx.activity.enableEdgeToEdge
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

class MainActivity : TauriActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)
  }

  // Source the real Android safe-area insets and soft-keyboard height for the
  // Nopal mobile signals (RFC 0116, REQ-F4/F5/N2). Tauri/Rust expose no API for
  // any of these, so we read WindowInsets natively and re-emit the documented
  // Tauri events the OCaml Platform_tauri subscriptions already listen for
  // (`nopal:safe-area` / `nopal:keyboard-height`). The event names and payload
  // grammar are the stable contract established in lib.rs `mobile_signals`;
  // only the value source moves from the zero stub to these real reads.
  override fun onWebViewCreate(webView: WebView) {
    val density = resources.displayMetrics.density
    fun px2dp(px: Int): Int = (px / density).toInt()

    ViewCompat.setOnApplyWindowInsetsListener(webView) { _, insets ->
      // Safe area = system bars (status / navigation) unioned with any display
      // cutout, in logical px (CSS px == dp on Android). Excludes the IME so the
      // safe area does not jump when the keyboard appears.
      val bars =
        insets.getInsets(
          WindowInsetsCompat.Type.systemBars() or
            WindowInsetsCompat.Type.displayCutout()
        )
      report(
        webView,
        "report_safe_area",
        "top=${px2dp(bars.top)};right=${px2dp(bars.right)};" +
          "bottom=${px2dp(bars.bottom)};left=${px2dp(bars.left)};"
      )

      // Soft-keyboard height: the IME bottom inset, logical px, 0 when hidden.
      val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
      report(webView, "report_keyboard_height", "${px2dp(ime.bottom)}")

      insets
    }

    // Re-dispatch the current insets once the webview's Tauri bridge is actually
    // ready, so the initial safe area reaches the app even when no further inset
    // change occurs after page load. A fixed delay window (formerly 600/1800 ms)
    // can fire before `window.__TAURI_INTERNALS__` exists on a slow first load —
    // `report()` is a no-op until then, so the first insets are silently dropped.
    // Instead poll for bridge readiness and request insets the moment it appears,
    // bounded so a bridge that never comes up cannot spin forever.
    redispatchInsetsWhenBridgeReady(webView, BRIDGE_READY_MAX_ATTEMPTS)

    // Route the Android hardware back button through the same nopal:back-pressed
    // event `simulate_back_pressed` uses, so `Platform_tauri.enable_hardware_back`
    // handles the real button and the debug IPC identically (RFC 0116, REQ-F3).
    // The callback invokes the payload-less `notify_back_pressed` Rust command —
    // which re-emits via `app.emit` — because a JS-side event would not echo back
    // to this webview (same round-trip constraint as `report`). The real-button
    // path has no automated OS-level test; it is verified manually on the Pixel 7
    // emulator (recorded in the PR).
    // Phase 3: replace the manual-emulator check with an Appium-driven OS event.
    onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
      override fun handleOnBackPressed() {
        webView.post {
          webView.evaluateJavascript(
            "window.__TAURI_INTERNALS__ && " +
              "window.__TAURI_INTERNALS__.invoke('notify_back_pressed')",
            null
          )
        }
      }
    })
  }

  // Request the OnApplyWindowInsets listener re-run once the Tauri bridge is
  // ready to receive the report, retrying on a short interval until then. Gating
  // the re-dispatch on the actual readiness signal (rather than a fixed delay)
  // keeps the initial safe area from being lost on a slow first load. Bounded by
  // `attemptsLeft` so a webview whose bridge never initializes stops cleanly.
  private fun redispatchInsetsWhenBridgeReady(webView: WebView, attemptsLeft: Int) {
    if (attemptsLeft <= 0) return
    webView.evaluateJavascript("!!(window.__TAURI_INTERNALS__)") { ready ->
      if (ready == "true") {
        ViewCompat.requestApplyInsets(webView)
      } else {
        webView.postDelayed(
          { redispatchInsetsWhenBridgeReady(webView, attemptsLeft - 1) },
          BRIDGE_READY_POLL_MS
        )
      }
    }
  }

  // Deliver a native mobile signal by invoking a Rust bridge command through the
  // webview IPC. The command re-emits via `app.emit`, which reaches the
  // in-webview `plugin:event|listen` handlers the OCaml subscriptions register —
  // a JS-side `plugin:event|emit` does NOT echo back to the same webview, so the
  // round-trip must go through Rust. Runs on the UI thread; guarded so it is
  // inert before the Tauri internals are injected.
  private fun report(webView: WebView, command: String, payload: String) {
    val js =
      "window.__TAURI_INTERNALS__ && window.__TAURI_INTERNALS__.invoke(" +
        "'$command', { payload: '$payload' })"
    webView.post { webView.evaluateJavascript(js, null) }
  }

  companion object {
    // Bridge-readiness poll for the initial inset re-dispatch: up to
    // MAX_ATTEMPTS probes at POLL_MS spacing (~10 s ceiling) before giving up.
    private const val BRIDGE_READY_MAX_ATTEMPTS = 100
    private const val BRIDGE_READY_POLL_MS = 100L
  }
}
