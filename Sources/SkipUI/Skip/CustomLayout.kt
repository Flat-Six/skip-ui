// Copyright 2026 Kyle Cronin
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.constrainWidth
import kotlin.math.roundToInt

/// The largest size a subview is proposed in pixels: Compose's constraints pack both dimensions into one value, and an
/// unreasonably large finite proposal would not fit.
private const val largestProposalPx = 16383

/// SwiftUI's custom `Layout` (SkipSwiftUI's, Flat-Six patch). The layout itself — its `sizeThatFits` and
/// `placeSubviews` — runs in Swift: `swiftLayout` is called on each layout pass with the subviews' natural sizes (their
/// intrinsic ones, in points) and answers the layout's size, then the frame of each subview. Here the subviews are
/// measured within those frames and placed at their points. `progress` is the layout's animatable data, read as the
/// layout measures: a frame of its animation re-lays the subviews and composes nothing.
///
/// `swiftLayout`'s arguments: `[0, proposed width, proposed height, progress, sizes…]` for the size, answered `[width,
/// height]`; `[1, width, height, proposed width, proposed height, progress, sizes…]` for the frames, answered `[x, y,
/// proposed width, proposed height, anchor x, anchor y]` for each subview. A proposed dimension below zero is
/// unspecified (nil).
@Composable
internal fun CustomLayoutContent(modifier: Modifier, renderables: kotlin.collections.List<Renderable>, context: ComposeContext,
                                 progress: Animatable<Float, AnimationVector1D>, swiftLayout: (skip.lib.Array<Double>) -> skip.lib.Array<Double>) {
    Layout(modifier = modifier, content = {
        renderables.forEachIndexed { index, renderable ->
            key(index) { renderable.Render(context) }
        }
    }) { measurables, constraints ->
        val scale = density.toDouble()
        val natural = DoubleArray(measurables.size * 2)
        measurables.forEachIndexed { i, measurable ->
            val width = measurable.maxIntrinsicWidth(Constraints.Infinity)
            natural[2 * i] = width / scale
            natural[2 * i + 1] = measurable.maxIntrinsicHeight(width) / scale
        }
        val proposedWidth = if (constraints.hasBoundedWidth) constraints.maxWidth / scale else -1.0
        val proposedHeight = if (constraints.hasBoundedHeight) constraints.maxHeight / scale else -1.0
        val dial = progress.value.toDouble()

        val sizeArgs = skip.lib.Array<Double>()
        for (value in doubleArrayOf(0.0, proposedWidth, proposedHeight, dial)) sizeArgs.append(value)
        for (value in natural) sizeArgs.append(value)
        val size = swiftLayout(sizeArgs)
        val width = constraints.constrainWidth(pixels(size[0], scale, constraints.maxWidth))
        val height = constraints.constrainHeight(pixels(size[1], scale, constraints.maxHeight))

        val frameArgs = skip.lib.Array<Double>()
        for (value in doubleArrayOf(1.0, width / scale, height / scale, proposedWidth, proposedHeight, dial)) frameArgs.append(value)
        for (value in natural) frameArgs.append(value)
        val frames = swiftLayout(frameArgs)

        val placeables = measurables.mapIndexed { i, measurable ->
            measurable.measure(Constraints(maxWidth = proposal(frames[6 * i + 2], scale), maxHeight = proposal(frames[6 * i + 3], scale)))
        }
        layout(width, height) {
            placeables.forEachIndexed { i, placeable ->
                val x = frames[6 * i] * scale - frames[6 * i + 4] * placeable.width
                val y = frames[6 * i + 1] * scale - frames[6 * i + 5] * placeable.height
                placeable.place(x.roundToInt(), y.roundToInt())
            }
        }
    }
}

/// A subview's proposed dimension in pixels: unspecified (below zero) or infinite, unbounded.
private fun proposal(points: Double, scale: Double): Int {
    if (points < 0.0 || points.isInfinite() || points.isNaN()) return Constraints.Infinity
    return (points * scale).roundToInt().coerceIn(0, largestProposalPx)
}

/// The layout's own dimension in pixels, an infinite or unspecified answer taking what was offered.
private fun pixels(points: Double, scale: Double, offered: Int): Int {
    if (points.isInfinite() || points.isNaN()) return if (offered == Constraints.Infinity) 0 else offered
    return (points * scale).roundToInt().coerceIn(0, largestProposalPx)
}
