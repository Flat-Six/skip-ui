// Copyright 2026 Kyle Cronin
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.AnimationVector2D
import androidx.compose.foundation.layout.offset
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import skip.lib.Tuple2

// Animated values read where they are used — while placing, measuring or drawing the layer — never while composing: a
// value read in composition recomposed its view, and everything the view holds, on every frame of an animation (a
// large animated view spent 60–220 ms a frame recomposing through the Swift bridge). Read here, a frame of an
// animation re-places, re-measures or redraws the view, and composes nothing.

/// `offset(x:y:)`: the offset read as the view is placed.
internal fun Modifier.animatedOffset(offset: Animatable<Tuple2<Float, Float>, AnimationVector2D>): Modifier =
    this.offset { IntOffset(offset.value.element0.dp.roundToPx(), offset.value.element1.dp.roundToPx()) }

/// `rotationEffect`: the angle read as the layer is drawn.
internal fun Modifier.animatedRotation(degrees: Animatable<Float, AnimationVector1D>, pivotX: Float, pivotY: Float): Modifier =
    this.graphicsLayer {
        transformOrigin = TransformOrigin(pivotX, pivotY)
        rotationZ = degrees.value
    }

/// `scaleEffect`: the scales read as the layer is drawn.
internal fun Modifier.animatedScale(scale: Animatable<Tuple2<Float, Float>, AnimationVector2D>, pivotX: Float, pivotY: Float): Modifier =
    this.graphicsLayer {
        transformOrigin = TransformOrigin(pivotX, pivotY)
        scaleX = scale.value.element0
        scaleY = scale.value.element1
    }

/// `compositorTransform`: the scales and the translation read as the layer is drawn.
internal fun Modifier.animatedCompositorTransform(scale: Animatable<Tuple2<Float, Float>, AnimationVector2D>, translation: Animatable<Tuple2<Float, Float>, AnimationVector2D>, pivotX: Float, pivotY: Float): Modifier =
    this.graphicsLayer {
        transformOrigin = TransformOrigin(pivotX, pivotY)
        scaleX = scale.value.element0
        scaleY = scale.value.element1
        translationX = translation.value.element0.dp.toPx()
        translationY = translation.value.element1.dp.toPx()
    }

/// `requiredWidth` and `requiredHeight` with their sizes (in points) read as the view is measured: the content measured
/// at exactly those, whatever its parent offers, the size reported as measured (Compose centres it in the parent's
/// constraints where it is larger, as it does `requiredWidth`'s). A zero size is a pixel, as FrameLayout's is: a frame
/// of zero width or height draws what hangs outside it, as SwiftUI's does.
internal fun Modifier.animatedRequiredSize(width: (() -> Double)?, height: (() -> Double)?): Modifier =
    this.layout { measurable, constraints ->
        val widthPx = width?.let { val points = it(); if (points > 0.0) points.dp.roundToPx() else 1 }
        val heightPx = height?.let { val points = it(); if (points > 0.0) points.dp.roundToPx() else 1 }
        val placeable = measurable.measure(Constraints(
            minWidth = widthPx ?: constraints.minWidth,
            maxWidth = widthPx ?: constraints.maxWidth,
            minHeight = heightPx ?: constraints.minHeight,
            maxHeight = heightPx ?: constraints.maxHeight
        ))
        layout(placeable.width, placeable.height) { placeable.place(0, 0) }
    }
