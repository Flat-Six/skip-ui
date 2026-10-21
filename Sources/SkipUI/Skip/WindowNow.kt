// Copyright 2026 Skip
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper

/**
 * The activity's window as the window manager has it now (Flat-Six patch: PresentationRoot): its size, and the insets of
 * its system bars and display cutout, in pixels. After a resize — a rotation, a fold — the window manager has the new
 * window as the configuration changes, before the views are laid out in it; the insets the views are handed come as
 * they are laid out, and the bounds a presentation learns from its layout a layout after that.
 */
internal data class WindowNow(
    val widthPx: Float,
    val heightPx: Float,
    val leftPx: Float,
    val topPx: Float,
    val rightPx: Float,
    val bottomPx: Float
)

internal fun windowNow(context: Context): WindowNow? {
    var current: Context? = context
    var activity: Activity? = null
    while (current != null) {
        if (current is Activity) {
            activity = current
            break
        }
        current = (current as? ContextWrapper)?.baseContext
    }
    val metrics = activity?.windowManager?.currentWindowMetrics ?: return null
    val bounds = metrics.bounds
    val insets = metrics.windowInsets.getInsets(android.view.WindowInsets.Type.systemBars() or android.view.WindowInsets.Type.displayCutout())
    return WindowNow(
        widthPx = bounds.width().toFloat(),
        heightPx = bounds.height().toFloat(),
        leftPx = insets.left.toFloat(),
        topPx = insets.top.toFloat(),
        rightPx = insets.right.toFloat(),
        bottomPx = insets.bottom.toFloat()
    )
}
