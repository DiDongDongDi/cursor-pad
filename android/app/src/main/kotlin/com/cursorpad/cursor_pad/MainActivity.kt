package com.cursorpad.cursor_pad

import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.cursorpad.cursor_pad/webview_touch"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "clickAt" -> {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x == null || y == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(simulateClickAt(x, y))
                    }

                    "showIme" -> {
                        result.success(showImeForWebView())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun simulateClickAt(x: Float, y: Float): Boolean {
        val webView = findWebView(window.decorView) ?: return false

        val downTime = SystemClock.uptimeMillis()
        val eventTime = downTime + 50

        val properties = arrayOf(
            MotionEvent.PointerProperties().apply {
                id = 0
                toolType = MotionEvent.TOOL_TYPE_FINGER
            },
        )
        val coords = arrayOf(
            MotionEvent.PointerCoords().apply {
                this.x = x
                this.y = y
                pressure = 1f
                size = 1f
            },
        )

        val down = MotionEvent.obtain(
            downTime,
            downTime,
            MotionEvent.ACTION_DOWN,
            1,
            properties,
            coords,
            0,
            0,
            1f,
            1f,
            0,
            0,
            0,
            0,
        )
        webView.dispatchTouchEvent(down)
        down.recycle()

        val up = MotionEvent.obtain(
            downTime,
            eventTime,
            MotionEvent.ACTION_UP,
            1,
            properties,
            coords,
            0,
            0,
            1f,
            1f,
            0,
            0,
            0,
            0,
        )
        webView.dispatchTouchEvent(up)
        up.recycle()

        return true
    }

    private fun showImeForWebView(): Boolean {
        val webView = findWebView(window.decorView) ?: return false
        webView.requestFocus()
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        return imm.showSoftInput(webView, InputMethodManager.SHOW_IMPLICIT)
    }

    private fun findWebView(view: View): WebView? {
        if (view is WebView) {
            return view
        }
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                val found = findWebView(view.getChildAt(i))
                if (found != null) {
                    return found
                }
            }
        }
        return null
    }
}
