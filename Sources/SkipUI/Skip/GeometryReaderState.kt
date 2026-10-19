// Copyright 2026 Skip
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.structuralEqualityPolicy
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.unit.IntSize

/**
 * Geometry dependencies belong to the property being read, not to proxy construction.
 * A moving parent changes the global frame without necessarily changing the measured size.
 * Keep one atomic layout sample, then use equality-checked projections so size-only content
 * does not subscribe to that movement. Never suppress the actual coordinate updates.
 */
@Stable
internal class GeometryReaderState {
    private data class Layout(val size: IntSize, val frame: Rect)
    private val layout = mutableStateOf<Layout?>(null)
    private val positioned = derivedStateOf(structuralEqualityPolicy()) { layout.value != null }
    private val size = derivedStateOf(structuralEqualityPolicy()) { layout.value?.size ?: IntSize.Zero }
    private val frame = derivedStateOf(structuralEqualityPolicy()) { layout.value?.frame ?: Rect.Zero }
    private val insets = mutableStateOf(GeometryReaderInsets())

    val isPositioned: Boolean get() = positioned.value
    val sizePx: IntSize get() = size.value
    val globalFramePx: Rect get() = frame.value
    val insetsPx: GeometryReaderInsets get() = insets.value

    /** The latest composition's safe area: the one the next layout is padded by (Flat-Six patch, update). */
    private var composedArea: SafeArea? = null

    /**
     * Measured size remains valid even when an ancestor clips the global bounding rectangle. The insets come with it
     * (Flat-Six patch): the safe area of the composition this layout follows, as iOS gives a reader its size and its
     * insets at once. Taken apart, a size a layout old met the next composition's insets, and while the keyboard slid
     * the window they added up to moved by the slide's step for a frame.
     */
    fun update(size: IntSize, frame: Rect) {
        layout.value = Layout(size, frame)
        insets.value = insetsOf(composedArea)
    }

    /**
     * The composition's safe area, kept for the layout that follows (update) — and the insets at once for a reader not
     * yet laid out. Compare inset distances, while other safe-area consumers retain their absolute bounds.
     */
    fun updateSafeArea(area: SafeArea?) {
        composedArea = area
        if (layout.value == null) {
            insets.value = insetsOf(area)
        }
    }

    /**
     * The bottom is measured from the window's bottom (Flat-Six patch): the keyboard counted as the safe area's, as iOS
     * counts it, so a reader's size and its insets add up to the window with the keyboard up as with it down — they had
     * come to the window less the keyboard, and a window told as tablet-like by its size stopped being so as the
     * keyboard came up, its form made anew and its field's focus lost (an opened Fold could not be typed on).
     */
    private fun insetsOf(area: SafeArea?): GeometryReaderInsets {
        return if (area == null) GeometryReaderInsets() else GeometryReaderInsets(
            top = area.safeBoundsPx.top - area.presentationBoundsPx.top,
            left = area.safeBoundsPx.left - area.presentationBoundsPx.left,
            bottom = area.presentationBoundsPx.bottom + area.keyboardPx - area.safeBoundsPx.bottom,
            right = area.presentationBoundsPx.right - area.safeBoundsPx.right
        )
    }
}

/** Physical inset distances; preserve the existing proxy's leading/left and trailing/right mapping. */
internal data class GeometryReaderInsets(
    val top: Float = 0f,
    val left: Float = 0f,
    val bottom: Float = 0f,
    val right: Float = 0f
)

/**
 * This Unit-returning composable owns the environment subscription independently of the reader
 * content. Like rememberUpdatedState, publish the current value before composing consumers,
 * including on the first pass. An absolute-bounds update with equal insets causes no state write
 * notification, and a real inset change invalidates only content that read safeAreaInsets.
 */
@Composable
internal fun UpdateGeometryReaderSafeArea(geometry: GeometryReaderState) {
    geometry.updateSafeArea(EnvironmentValues.shared._safeArea)
}
