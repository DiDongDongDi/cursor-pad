package com.cursorpad.cursor_pad

import android.os.SystemClock
import android.view.InputDevice
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
    private var mouseDragDownTime: Long = 0
    private var mouseDragActive = false
    private var mouseHoverActive = false
    private var mouseHoverTime: Long = 0

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

                    "dragDown" -> {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x == null || y == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(simulateDragDown(x, y))
                    }

                    "dragMove" -> {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x == null || y == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(simulateDragMove(x, y))
                    }

                    "dragUp" -> {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x == null || y == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(simulateDragUp(x, y))
                    }

                    "mouseDragDown" -> {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x == null || y == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(simulateMouseDragDown(x, y))
                    }

                    "mouseDragMove" -> {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x == null || y == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(simulateMouseDragMove(x, y))
                    }

                    "mouseDragUp" -> {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x == null || y == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(simulateMouseDragUp(x, y))
                    }

                    "mouseHoverMove" -> {
                        val x = call.argument<Double>("x")?.toFloat()
                        val y = call.argument<Double>("y")?.toFloat()
                        if (x == null || y == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(simulateMouseHoverMove(x, y))
                    }

                    "showIme" -> {
                        result.success(showImeForWebView())
                    }

                    "hideIme" -> {
                        result.success(hideImeForWebView())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun simulateClickAt(x: Float, y: Float): Boolean {
        cancelActiveDrag()
        val webView = findVisibleWebView(window.decorView) ?: return false

        val density = webView.resources.displayMetrics.density
        val pxX = x * density
        val pxY = y * density

        val downTime = SystemClock.uptimeMillis()
        val eventTime = downTime + 50

        dispatchTouch(webView, MotionEvent.ACTION_DOWN, pxX, pxY, downTime, downTime)
        dispatchTouch(webView, MotionEvent.ACTION_UP, pxX, pxY, downTime, eventTime)

        return true
    }

    private fun simulateDragDown(x: Float, y: Float): Boolean {
        cancelActiveDrag()
        val webView = findVisibleWebView(window.decorView) ?: return false

        val density = webView.resources.displayMetrics.density
        val pxX = x * density
        val pxY = y * density

        dragDownTime = SystemClock.uptimeMillis()
        dragActive = dispatchTouch(
            webView,
            MotionEvent.ACTION_DOWN,
            pxX,
            pxY,
            dragDownTime,
            dragDownTime,
        )
        return dragActive
    }

    private fun simulateDragMove(x: Float, y: Float): Boolean {
        if (!dragActive) {
            return false
        }
        val webView = findVisibleWebView(window.decorView) ?: return false

        val density = webView.resources.displayMetrics.density
        val pxX = x * density
        val pxY = y * density
        val eventTime = SystemClock.uptimeMillis()

        return dispatchTouch(
            webView,
            MotionEvent.ACTION_MOVE,
            pxX,
            pxY,
            dragDownTime,
            eventTime,
        )
    }

    private fun simulateDragUp(x: Float, y: Float): Boolean {
        if (!dragActive) {
            return false
        }
        val webView = findVisibleWebView(window.decorView) ?: return false

        val density = webView.resources.displayMetrics.density
        val pxX = x * density
        val pxY = y * density
        val eventTime = SystemClock.uptimeMillis()

        val handled = dispatchTouch(
            webView,
            MotionEvent.ACTION_UP,
            pxX,
            pxY,
            dragDownTime,
            eventTime,
        )
        dragActive = false
        return handled
    }

    private fun simulateMouseDragDown(x: Float, y: Float): Boolean {
        cancelActiveMouseHover()
        cancelActiveMouseDrag()
        val webView = findVisibleWebView(window.decorView) ?: return false

        val density = webView.resources.displayMetrics.density
        val pxX = x * density
        val pxY = y * density

        mouseDragDownTime = SystemClock.uptimeMillis()
        webView.requestFocus()
        mouseDragActive = dispatchMouse(
            webView,
            MotionEvent.ACTION_DOWN,
            pxX,
            pxY,
            mouseDragDownTime,
            mouseDragDownTime,
            MotionEvent.BUTTON_PRIMARY,
        )
        return mouseDragActive
    }

    private fun simulateMouseDragMove(x: Float, y: Float): Boolean {
        if (!mouseDragActive) {
            return false
        }
        val webView = findVisibleWebView(window.decorView) ?: return false

        val density = webView.resources.displayMetrics.density
        val pxX = x * density
        val pxY = y * density
        val eventTime = SystemClock.uptimeMillis()

        return dispatchMouse(
            webView,
            MotionEvent.ACTION_MOVE,
            pxX,
            pxY,
            mouseDragDownTime,
            eventTime,
            MotionEvent.BUTTON_PRIMARY,
        )
    }

    private fun simulateMouseDragUp(x: Float, y: Float): Boolean {
        if (!mouseDragActive) {
            return false
        }
        val webView = findVisibleWebView(window.decorView) ?: return false

        val density = webView.resources.displayMetrics.density
        val pxX = x * density
        val pxY = y * density
        val eventTime = SystemClock.uptimeMillis()

        val handled = dispatchMouse(
            webView,
            MotionEvent.ACTION_UP,
            pxX,
            pxY,
            mouseDragDownTime,
            eventTime,
            0,
        )
        mouseDragActive = false
        return handled
    }

    private fun cancelActiveMouseDrag() {
        if (!mouseDragActive) {
            return
        }
        val webView = findVisibleWebView(window.decorView) ?: run {
            mouseDragActive = false
            return
        }
        val eventTime = SystemClock.uptimeMillis()
        dispatchMouse(
            webView,
            MotionEvent.ACTION_CANCEL,
            0f,
            0f,
            mouseDragDownTime,
            eventTime,
            0,
        )
        mouseDragActive = false
    }

    private fun simulateMouseHoverMove(x: Float, y: Float): Boolean {
        if (mouseDragActive) {
            return false
        }
        val webView = findVisibleWebView(window.decorView) ?: return false

        val density = webView.resources.displayMetrics.density
        val pxX = x * density
        val pxY = y * density
        val eventTime = SystemClock.uptimeMillis()

        if (!mouseHoverActive) {
            mouseHoverTime = eventTime
            dispatchHoverEvent(
                webView,
                MotionEvent.ACTION_HOVER_ENTER,
                pxX,
                pxY,
                eventTime,
            )
            mouseHoverActive = true
        }

        return dispatchHoverEvent(
            webView,
            MotionEvent.ACTION_HOVER_MOVE,
            pxX,
            pxY,
            eventTime,
        )
    }

    private fun cancelActiveMouseHover() {
        if (!mouseHoverActive) {
            return
        }
        val webView = findVisibleWebView(window.decorView) ?: run {
            mouseHoverActive = false
            mouseHoverTime = 0
            return
        }
        val eventTime = SystemClock.uptimeMillis()
        dispatchHoverEvent(
            webView,
            MotionEvent.ACTION_HOVER_EXIT,
            0f,
            0f,
            eventTime,
        )
        mouseHoverActive = false
        mouseHoverTime = 0
    }

    private fun dispatchHoverEvent(
        webView: WebView,
        action: Int,
        pxX: Float,
        pxY: Float,
        eventTime: Long,
    ): Boolean {
        val properties = arrayOf(
            MotionEvent.PointerProperties().apply {
                id = 0
                toolType = MotionEvent.TOOL_TYPE_MOUSE
            },
        )
        val coords = arrayOf(
            MotionEvent.PointerCoords().apply {
                this.x = pxX
                this.y = pxY
                pressure = 0f
                size = 1f
            },
        )

        val downTime = if (mouseHoverTime > 0L) mouseHoverTime else eventTime
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
            InputDevice.SOURCE_MOUSE,
            0,
        )
        val handled = webView.dispatchGenericMotionEvent(event)
        event.recycle()
        return handled
    }

    private fun cancelActiveDrag() {
        cancelActiveMouseDrag()
        if (!dragActive) {
            return
        }
        val webView = findVisibleWebView(window.decorView) ?: run {
            dragActive = false
            return
        }
        val eventTime = SystemClock.uptimeMillis()
        dispatchTouch(
            webView,
            MotionEvent.ACTION_CANCEL,
            0f,
            0f,
            dragDownTime,
            eventTime,
        )
        dragActive = false
    }

    private fun dispatchMouse(
        webView: WebView,
        action: Int,
        pxX: Float,
        pxY: Float,
        downTime: Long,
        eventTime: Long,
        buttonState: Int,
    ): Boolean {
        val properties = arrayOf(
            MotionEvent.PointerProperties().apply {
                id = 0
                toolType = MotionEvent.TOOL_TYPE_MOUSE
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
            buttonState,
            1f,
            1f,
            0,
            0,
            InputDevice.SOURCE_MOUSE,
            0,
        )
        var handled = webView.dispatchGenericMotionEvent(event)
        if (!handled) {
            val touchEvent = MotionEvent.obtain(
                downTime,
                eventTime,
                action,
                1,
                properties,
                coords,
                0,
                buttonState,
                1f,
                1f,
                0,
                0,
                InputDevice.SOURCE_MOUSE,
                0,
            )
            handled = webView.dispatchTouchEvent(touchEvent)
            touchEvent.recycle()
        }
        event.recycle()
        return handled
    }

    private fun dispatchTouch(
        webView: WebView,
        action: Int,
        pxX: Float,
        pxY: Float,
        downTime: Long,
        eventTime: Long,
    ): Boolean {
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
        val handled = webView.dispatchTouchEvent(event)
        event.recycle()
        return handled
    }

    private fun showImeForWebView(): Boolean {
        val webView = findVisibleWebView(window.decorView) ?: return false
        webView.requestFocus()
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        return imm.showSoftInput(webView, InputMethodManager.SHOW_IMPLICIT)
    }

    private fun hideImeForWebView(): Boolean {
        val webView = findVisibleWebView(window.decorView)
        val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
        val token = webView?.windowToken ?: currentFocus?.windowToken ?: return false
        return imm.hideSoftInputFromWindow(token, 0)
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
