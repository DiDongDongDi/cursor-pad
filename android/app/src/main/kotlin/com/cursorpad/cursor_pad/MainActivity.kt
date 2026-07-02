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

    private var dragDownTime: Long = 0
    private var dragActive = false

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

                    "touchDownAt" -> {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x == null || y == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(simulateTouchDownAt(x, y))
                    }

                    "touchMoveTo" -> {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x == null || y == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(simulateTouchMoveTo(x, y))
                    }

                    "touchUpAt" -> {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x == null || y == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(simulateTouchUpAt(x, y))
                    }

                    "showIme" -> {
                        result.success(showImeForWebView())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun simulateClickAt(x: Float, y: Float): Boolean {
        val webView = findVisibleWebView(window.decorView) ?: return false
        val (pxX, pxY) = toViewPixels(webView, x, y)

        val downTime = SystemClock.uptimeMillis()
        val eventTime = downTime + 50

        dispatchTouchEvent(webView, MotionEvent.ACTION_DOWN, downTime, downTime, pxX, pxY)
        dispatchTouchEvent(webView, MotionEvent.ACTION_UP, downTime, eventTime, pxX, pxY)

        return true
    }

    private fun simulateTouchDownAt(x: Float, y: Float): Boolean {
        val webView = findVisibleWebView(window.decorView) ?: return false
        val (pxX, pxY) = toViewPixels(webView, x, y)

        dragDownTime = SystemClock.uptimeMillis()
        dragActive = true
        dispatchTouchEvent(webView, MotionEvent.ACTION_DOWN, dragDownTime, dragDownTime, pxX, pxY)

        return true
    }

    private fun simulateTouchMoveTo(x: Float, y: Float): Boolean {
        if (!dragActive) {
            return false
        }
        val webView = findVisibleWebView(window.decorView) ?: return false
        val (pxX, pxY) = toViewPixels(webView, x, y)

        val eventTime = SystemClock.uptimeMillis()
        dispatchTouchEvent(webView, MotionEvent.ACTION_MOVE, dragDownTime, eventTime, pxX, pxY)

        return true
    }

    private fun simulateTouchUpAt(x: Float, y: Float): Boolean {
        if (!dragActive) {
            return false
        }
        val webView = findVisibleWebView(window.decorView) ?: return false
        val (pxX, pxY) = toViewPixels(webView, x, y)

        val eventTime = SystemClock.uptimeMillis()
        dispatchTouchEvent(webView, MotionEvent.ACTION_UP, dragDownTime, eventTime, pxX, pxY)
        dragActive = false

        return true
    }

    private fun toViewPixels(webView: WebView, x: Float, y: Float): Pair<Float, Float> {
        val density = webView.resources.displayMetrics.density
        return Pair(x * density, y * density)
    }

    private fun dispatchTouchEvent(
        webView: WebView,
        action: Int,
        downTime: Long,
        eventTime: Long,
        pxX: Float,
        pxY: Float,
    ) {
        val properties = arrayOf(
            MotionEvent.PointerProperties().apply {
                id = 0
                toolType = MotionEvent.TOOL_TYPE_FINGER
            },
        )
        val coords = arrayOf(
            MotionEvent.PointerCoords().apply {
                this.x = pxX
                this.y = pxY
                pressure = if (action == MotionEvent.ACTION_UP) 0f else 1f
                size = 1f
            },
        )

        val event = MotionEvent.obtain(
            downTime,
            eventTime,
            action,
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
        webView.dispatchTouchEvent(event)
        event.recycle()
    }

    private fun showImeForWebView(): Boolean {
        val webView = findVisibleWebView(window.decorView) ?: return false
        webView.requestFocus()
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        return imm.showSoftInput(webView, InputMethodManager.SHOW_IMPLICIT)
    }

    private fun isVisibleWebView(view: View): Boolean {
        return view is WebView &&
            view.visibility == View.VISIBLE &&
            view.isShown &&
            view.width > 0 &&
            view.height > 0
    }

    private fun findVisibleWebView(view: View): WebView? {
        if (isVisibleWebView(view)) {
            return view as WebView
        }
        if (view is ViewGroup) {
            for (i in view.childCount - 1 downTo 0) {
                val found = findVisibleWebView(view.getChildAt(i))
                if (found != null) {
                    return found
                }
            }
        }
        return null
    }
}
