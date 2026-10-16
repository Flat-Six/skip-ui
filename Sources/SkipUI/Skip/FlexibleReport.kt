// Copyright 2026 Kyle Cronin
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.IntrinsicMeasurable
import androidx.compose.ui.layout.IntrinsicMeasureScope
import androidx.compose.ui.layout.Measurable
import androidx.compose.ui.layout.MeasureResult
import androidx.compose.ui.layout.MeasureScope
import androidx.compose.ui.node.LayoutModifierNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.node.ParentDataModifierNode
import androidx.compose.ui.platform.InspectorInfo
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density

/**
 * What a container's content says of its flexibility as it composes (Flat-Six patch).
 *
 * `ComposeFlexibleContainer` builds a container's modifier before its content composes, so it learns that the content
 * fills or flexes only in the composition after (its `SideEffect`), and a container around that one a composition later
 * still. A view composed fresh therefore laid out its first frames as though its content were fixed: a row of tiles,
 * each `.frame(maxWidth: .infinity)` under a height and a background, gave the first tile the whole row for two frames —
 * a flash wherever such a view appears, as a list row composed again after a transition does.
 *
 * The report is filled while the content composes, before anything is measured, and goes on to the enclosing
 * container's report as the container's next composition would pass it on; [deferredFlexible] reads it as the parent
 * measures. So a fresh view's first frame is laid out as the compositions after it lay it out, and once the
 * container's own state has caught up the report changes nothing.
 */
class FlexibleReport {
    /** The content's width and height as the container records them: fill, unknown with space, unknown non-expanding. Never lowered, as the container's own record never is. */
    var widthMax: Float? = null
    var heightMax: Float? = null

    /** The enclosing container's report, which this container's width and height go on to when its frame takes its content's. */
    var parent: FlexibleReport? = null
    var forwardsWidth = false
    var forwardsHeight = false

    /** Whether the container has composed once: a fresh container carries the deferred element whatever its content turns out to say. */
    var hasComposed = false

    /** The content's width, as the container's `flexibleWidth` hears it. */
    fun reportWidth(max: Float?) {
        val merged = flexibleMerged(widthMax, flexibleClassified(max))
        if (merged == widthMax) {
            return
        }
        widthMax = merged
        if (forwardsWidth) {
            parent?.reportWidth(merged)
        }
    }

    /** The content's height, as the container's `flexibleHeight` hears it. */
    fun reportHeight(max: Float?) {
        val merged = flexibleMerged(heightMax, flexibleClassified(max))
        if (merged == heightMax) {
            return
        }
        heightMax = merged
        if (forwardsHeight) {
            parent?.reportHeight(merged)
        }
    }
}

/** A content's max as its container records it — `ComposeFlexibleContainer`'s `flexibleWidth` side effects. */
internal fun flexibleClassified(max: Float?): Float? = when {
    max == null -> null
    max == Float.flexibleFill -> Float.flexibleFill
    max.isFlexibleExpanding -> Float.flexibleUnknownWithSpace
    else -> Float.flexibleUnknownNonExpanding
}

/** The container's ranking of expansion: higher is stronger. */
internal fun flexibleRank(value: Float?): Int = when (value) {
    Float.flexibleFill -> 4
    Float.flexibleSpace -> 3
    Float.flexibleUnknownWithSpace -> 2
    Float.flexibleUnknownNonExpanding -> 1
    else -> 0
}

internal fun flexibleMerged(current: Float?, proposed: Float?): Float? =
    if (flexibleRank(proposed) > flexibleRank(current)) proposed else current

/** How the parent lays out what a container passes it: nothing deferred. */
const val FLEXIBLE_DEFERRED_NONE = 0
/** ... as a stack lays out its main axis: by the child's parent data (`HStackRow`, `VStackColumn`). */
const val FLEXIBLE_DEFERRED_STACK = 1
/** ... filled, as `fillMaxWidth` fills, when expanding (inside another container). */
const val FLEXIBLE_DEFERRED_FILL = 2
/** ... filled only for `flexibleFill` (no container around it). */
const val FLEXIBLE_DEFERRED_FILL_ONLY = 3

/**
 * How a container's parent lays out the flexibility the container passes on: `forwards` — the container's frame takes
 * its content's on this axis (not fixed, no max of its own, not a scroll axis); `inContainer` — a container encloses it
 * (the environment's `flexibleWidth`); `inStack` — that container is a stack laying out this axis (its
 * `flexibleWidthModifier`).
 */
fun deferredFlexibleMode(forwards: Boolean, inContainer: Boolean, inStack: Boolean, layoutImplementationVersion: Int): Int = when {
    !forwards -> FLEXIBLE_DEFERRED_NONE
    !inContainer -> FLEXIBLE_DEFERRED_FILL_ONLY
    inStack -> if (layoutImplementationVersion > 0) FLEXIBLE_DEFERRED_STACK else FLEXIBLE_DEFERRED_NONE   // Row's weights are Compose's own
    else -> FLEXIBLE_DEFERRED_FILL
}

/**
 * The flexibility a container's content reports in this composition, applied as the container's parent measures,
 * where the container's own modifier (`composedWidthMax`, `composedHeightMax`: what it was built with) does not yet
 * carry it. Carried while the container is fresh or catching up.
 */
fun Modifier.deferredFlexible(report: FlexibleReport, widthMode: Int, composedWidthMax: Float?, heightMode: Int, composedHeightMax: Float?): Modifier {
    val width = if (widthMode != FLEXIBLE_DEFERRED_NONE && (!report.hasComposed || flexibleRank(report.widthMax) > flexibleRank(composedWidthMax))) widthMode else FLEXIBLE_DEFERRED_NONE
    val height = if (heightMode != FLEXIBLE_DEFERRED_NONE && (!report.hasComposed || flexibleRank(report.heightMax) > flexibleRank(composedHeightMax))) heightMode else FLEXIBLE_DEFERRED_NONE
    if (width == FLEXIBLE_DEFERRED_NONE && height == FLEXIBLE_DEFERRED_NONE) {
        return this
    }
    return this.then(DeferredFlexibleElement(report, width, composedWidthMax, height, composedHeightMax))
}

internal class DeferredFlexibleElement(
    val report: FlexibleReport,
    val widthMode: Int,
    val composedWidthMax: Float?,
    val heightMode: Int,
    val composedHeightMax: Float?,
) : ModifierNodeElement<DeferredFlexibleNode>() {
    override fun create() = DeferredFlexibleNode(report, widthMode, composedWidthMax, heightMode, composedHeightMax)

    override fun update(node: DeferredFlexibleNode) {
        node.report = report
        node.widthMode = widthMode
        node.composedWidthMax = composedWidthMax
        node.heightMode = heightMode
        node.composedHeightMax = composedHeightMax
    }

    override fun InspectorInfo.inspectableProperties() {
        name = "deferredFlexible"
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        val o = other as? DeferredFlexibleElement ?: return false
        return report === o.report && widthMode == o.widthMode && composedWidthMax == o.composedWidthMax && heightMode == o.heightMode && composedHeightMax == o.composedHeightMax
    }

    override fun hashCode(): Int {
        var result = System.identityHashCode(report)
        result = 31 * result + widthMode
        result = 31 * result + composedWidthMax.hashCode()
        result = 31 * result + heightMode
        result = 31 * result + composedHeightMax.hashCode()
        return result
    }
}

internal class DeferredFlexibleNode(
    var report: FlexibleReport,
    var widthMode: Int,
    var composedWidthMax: Float?,
    var heightMode: Int,
    var composedHeightMax: Float?,
) : LayoutModifierNode, ParentDataModifierNode, Modifier.Node() {
    /** What the report says that the container's own modifier does not yet: the value to apply, or null. */
    private fun pending(mode: Int, reported: Float?, composed: Float?): Float? =
        if (mode != FLEXIBLE_DEFERRED_NONE && flexibleRank(reported) > flexibleRank(composed)) reported else null

    private fun fills(mode: Int, reported: Float?, composed: Float?): Boolean {
        val value = pending(mode, reported, composed) ?: return false
        return when (mode) {
            FLEXIBLE_DEFERRED_FILL -> value.isFlexibleExpanding
            FLEXIBLE_DEFERRED_FILL_ONLY -> value == Float.flexibleFill
            else -> false
        }
    }

    // Placed ahead of the container's own flexible modifier, so where both speak this one is applied last and wins
    // (parent data is gathered from the innermost modifier out)
    override fun Density.modifyParentData(parentData: Any?): Any? {
        val width = if (widthMode == FLEXIBLE_DEFERRED_STACK) pending(widthMode, report.widthMax, composedWidthMax) else null
        val height = if (heightMode == FLEXIBLE_DEFERRED_STACK) pending(heightMode, report.heightMax, composedHeightMax) else null
        val max = width ?: height ?: return parentData
        return ((parentData as? RowColumnParentData) ?: RowColumnParentData()).also {
            it.flexibleMax = max
        }
    }

    override fun MeasureScope.measure(measurable: Measurable, constraints: Constraints): MeasureResult {
        var adjusted = constraints
        if (constraints.hasBoundedWidth && fills(widthMode, report.widthMax, composedWidthMax)) {
            adjusted = adjusted.copy(minWidth = constraints.maxWidth)
        }
        if (constraints.hasBoundedHeight && fills(heightMode, report.heightMax, composedHeightMax)) {
            adjusted = adjusted.copy(minHeight = constraints.maxHeight)
        }
        val placeable = measurable.measure(adjusted)
        return layout(placeable.width, placeable.height) {
            placeable.place(0, 0)
        }
    }

    // A fill takes the space offered; it never changes what the content would take of an unbounded offer
    override fun IntrinsicMeasureScope.minIntrinsicWidth(measurable: IntrinsicMeasurable, height: Int) = measurable.minIntrinsicWidth(height)
    override fun IntrinsicMeasureScope.maxIntrinsicWidth(measurable: IntrinsicMeasurable, height: Int) = measurable.maxIntrinsicWidth(height)
    override fun IntrinsicMeasureScope.minIntrinsicHeight(measurable: IntrinsicMeasurable, width: Int) = measurable.minIntrinsicHeight(width)
    override fun IntrinsicMeasureScope.maxIntrinsicHeight(measurable: IntrinsicMeasurable, width: Int) = measurable.maxIntrinsicHeight(width)
}
