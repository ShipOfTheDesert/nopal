package run.nopal.kitchen_sink

import android.os.Bundle
import android.webkit.WebView
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

    // Re-dispatch the current insets once the webview JS and the Tauri event
    // bridge are ready, so the initial safe area reaches the app even when no
    // further inset change occurs after page load.
    webView.postDelayed({ ViewCompat.requestApplyInsets(webView) }, 600)
    webView.postDelayed({ ViewCompat.requestApplyInsets(webView) }, 1800)
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
}
