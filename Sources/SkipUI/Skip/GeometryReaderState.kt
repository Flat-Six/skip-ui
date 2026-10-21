// Copyright 2026 Skip
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.structuralEqualityPolicy
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.unit.Constraints
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

    /**
     * The insets of this composition's safe area, not a state (Flat-Six patch): for a reader made with the size it is
     * laid out at, its size and its insets from the same frame (GeometryReader).
     */
    val composedInsetsPx: GeometryReaderInsets get() = insetsOf(composedArea)

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

/** The size a reader with these constraints is laid out at, where both are bounded (Flat-Six patch: GeometryReader). */
internal fun boundedSizePx(constraints: Constraints): IntSize? {
    return if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) IntSize(constraints.maxWidth, constraints.maxHeight) else null
}

/**
 * A reader's layout (Flat-Six patch: GeometryReader): its content made as it is measured, with the size it is laid out
 * at — a Box's layout otherwise, its content at the top leading corner. Unlike BoxWithConstraints, which hands its slot a
 * new lambda at every measure and so makes its content again at every measure — around the whole app, a layout made
 * anew by every change inside it, which asked for another layout, every frame — the content is made again only for a
 * new size or new content.
 */
@Composable
internal fun GeometryReaderLayout(modifier: Modifier, content: @Composable (IntSize?) -> Unit) {
    val slot = remember { GeometryReaderSlot() }
    SubcomposeLayout(modifier) { constraints ->
        val size = boundedSizePx(constraints)
        val loose = constraints.copy(minWidth = 0, minHeight = 0)
        val placeables = subcompose(Unit, slot.contentFor(size, content)).map { it.measure(loose) }
        val width = (placeables.maxOfOrNull { it.width } ?: 0).coerceIn(constraints.minWidth, constraints.maxWidth)
        val height = (placeables.maxOfOrNull { it.height } ?: 0).coerceIn(constraints.minHeight, constraints.maxHeight)
        layout(width, height) {
            placeables.forEach { it.place(0, 0) }
        }
    }
}

/**
 * onGeometryChange's delivery (Flat-Six patch): a layout's geometry kept as it is positioned, and handed on once that
 * frame's layout is done — the last of the frame's layouts, after the frame, in time for the next frame's composition.
 * Kept as a state instead, it was read by a composition a frame later and its action called after that (SideEffect),
 * the action's state change drawn a frame after that again. Called at each positioning instead, an action saw every
 * layout of a frame: a List laid out at the window's whole width and then within its safe area in one frame set a
 * width that redrew it, at the whole width again, without end.
 */
internal class GeometryChangeDelivery {
    private var latest: Any? = null
    private var deliver: ((Any) -> Unit)? = null
    private var posted = false
    var isActive = true
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    fun offer(value: Any, deliver: (Any) -> Unit) {
        latest = value
        this.deliver = deliver
        if (posted) {
            return
        }
        posted = true
        handler.post {
            posted = false
            val value = latest
            val deliver = this.deliver
            latest = null
            if (isActive && value != null && deliver != null) {
                deliver(value)
            }
        }
    }
}

/** A delivery for one onGeometryChange, stopped as it leaves the composition. */
@Composable
internal fun rememberGeometryChangeDelivery(): GeometryChangeDelivery {
    val delivery = remember { GeometryChangeDelivery() }
    DisposableEffect(delivery) {
        delivery.isActive = true
        onDispose { delivery.isActive = false }
    }
    return delivery
}

/** The lambda a reader's slot was last made with, kept while its size and its content are the same. */
private class GeometryReaderSlot {
    private var size: IntSize? = null
    private var content: (@Composable (IntSize?) -> Unit)? = null
    private var slot: (@Composable () -> Unit)? = null

    fun contentFor(size: IntSize?, content: @Composable (IntSize?) -> Unit): @Composable () -> Unit {
        val current = slot
        if (current != null && size == this.size && content === this.content) {
            return current
        }
        val made: @Composable () -> Unit = { content(size) }
        this.size = size
        this.content = content
        slot = made
        return made
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
