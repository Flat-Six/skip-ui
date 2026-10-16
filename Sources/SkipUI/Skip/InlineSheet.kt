// Copyright 2026 Kyle Cronin
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.roundToInt

/// A sheet that leaves what it is presented over live (Flat-Six patch: SwiftUI's
/// `presentationBackgroundInteraction(.enabled…)`, which Skip had not). Material's ModalBottomSheet opens a window of its
/// own over the whole screen, so a map behind a collapsed sheet took no touches. This one is drawn over
/// its presenter in the presenter's own window — composed after it, in the box the sheet modifier puts around it
/// (`overlay` fills that box) — and stands on the window's foot. Above it the presenter takes touches while the sheet is no
/// higher than `liveUpTo`; higher, a dim covers the presenter, deepening up to the highest detent, and takes them, as iOS's
/// does — a tap on it is `onDimTap`'s.
///
/// The user drags it between its detents (`heights`: for each, the sheet's height above the window's foot, in pixels, in
/// the app's order) by its grabber, its bar or anything else that does not scroll, and by scrolling its content at an edge
/// — up while it can grow grows it, down past the content's top shrinks it (nested scrolling, as UIKit's sheet). It follows
/// the finger, and on release settles on the detent the fling carries it nearest to, which it reports (`onSelect`, that
/// detent's index). The app's selection (`selected`) moves it there, eased. Its content is laid out at the sheet's height as
/// it moves, as UIKit resizes a sheet's content.
@Composable
internal fun InlineSheet(
    overlay: Modifier,
    heights: kotlin.collections.List<Float>,
    selected: Int,
    onSelect: (Int) -> Unit,
    liveUpTo: Float,
    grabber: Boolean,
    cornerRadius: Dp,
    onDimTap: (() -> Unit)?,
    content: @Composable (Modifier) -> Unit,
) {
    if (heights.isEmpty()) return
    val scope = rememberCoroutineScope()
    val windowHeight = LocalWindowInfo.current.containerSize.height.toFloat()
    var overlayTop by remember { mutableFloatStateOf(Float.NaN) }
    val target = heights[selected.coerceIn(heights.indices)]
    // presented, it rises from the window's foot to its detent, as UIKit's sheet does (at once when animations are
    // off)
    var height by remember { mutableFloatStateOf(0f) }
    val motion = remember { arrayOfNulls<Job>(1) }   // a settling, or a move to the app's selection
    val currentHeights by rememberUpdatedState(heights)
    val currentSelected by rememberUpdatedState(selected)
    val currentOnSelect by rememberUpdatedState(onSelect)
    val lowest by rememberUpdatedState(heights.min())
    val highest by rememberUpdatedState(heights.max())
    val currentLiveUpTo by rememberUpdatedState(liveUpTo)

    // the app's selection, eased to — the first, from the foot
    LaunchedEffect(target) {
        if (abs(height - target) < 0.5f) {
            height = target
            return@LaunchedEffect
        }
        motion[0]?.cancel()
        motion[0] = coroutineContext[Job]
        animate(height, target, animationSpec = sheetSpring) { value, _ -> height = value }
    }

    fun atDetent() = currentHeights.any { abs(it - height) < 1f }

    /// On release: the detent nearest where the fling would carry the sheet (`velocity`: the finger's, pixels a second,
    /// down positive), eased to and reported.
    fun settle(velocity: Float) {
        val hs = currentHeights
        val projected = height - velocity * 0.15f
        val index = hs.indices.minByOrNull { abs(hs[it] - projected) } ?: return
        motion[0]?.cancel()
        val to = hs[index]
        motion[0] = scope.launch {
            animate(height, to, initialVelocity = -velocity, animationSpec = sheetSpring) { value, _ -> height = value }
            // the detent by its height in the detents as they are now, should their order have changed meanwhile
            val settled = currentHeights.indexOfFirst { abs(it - to) < 0.5f }
            if (settled >= 0 && settled != currentSelected) currentOnSelect(settled)
        }
    }

    val drag = rememberDraggableState { dy -> height = (height - dy).coerceIn(lowest, highest) }
    val nested = remember {
        object : NestedScrollConnection {
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                val dy = available.y
                if (source != NestedScrollSource.UserInput || dy >= 0f || height >= highest) return Offset.Zero
                motion[0]?.cancel()
                val grown = min(-dy, highest - height)
                height += grown
                return Offset(0f, -grown)
            }

            override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
                val dy = available.y
                if (source != NestedScrollSource.UserInput || dy <= 0f || height <= lowest) return Offset.Zero
                motion[0]?.cancel()
                val shrunk = min(dy, height - lowest)
                height -= shrunk
                return Offset(0f, shrunk)
            }

            override suspend fun onPreFling(available: Velocity): Velocity {
                if (atDetent()) return Velocity.Zero
                settle(available.y)
                return available
            }

            override suspend fun onPostFling(consumed: Velocity, available: Velocity): Velocity {
                if (!atDetent()) settle(available.y)
                return Velocity.Zero
            }
        }
    }
    val live by remember { derivedStateOf { height <= currentLiveUpTo + 0.5f } }

    // The overlay is the presenter's box, which ends at the bars where the presenter's content runs on past it (ignoring
    // the safe area): the dim covers the window, and the sheet stands on the window's foot, below the box's.
    Box(overlay.onGloballyPositioned { overlayTop = it.positionInWindow().y }) {
        if (overlayTop.isNaN()) return@Box
        if (!live) {
            Box(Modifier
                .layout { measurable, constraints ->
                    val placeable = measurable.measure(Constraints.fixed(constraints.maxWidth, windowHeight.roundToInt()))
                    layout(constraints.maxWidth, constraints.maxHeight) { placeable.place(0, -overlayTop.roundToInt()) }
                }
                .drawBehind {
                    val depth = if (highest > currentLiveUpTo) ((height - currentLiveUpTo) / (highest - currentLiveUpTo)).coerceIn(0f, 1f) else 1f
                    drawRect(Color.Black.copy(alpha = 0.28f * depth))   // iOS 17's, measured over the map
                }
                .pointerInput(onDimTap) { detectTapGestures { onDimTap?.invoke() } })
        }
        Box(Modifier
            .offset { IntOffset(0, (windowHeight - overlayTop - height).roundToInt()) }
            .layout { measurable, constraints ->
                // its own height, reported no taller than the box allows: taller, Compose centred it on the box (18 px
                // up at the largest detent); it runs on past the box's foot to the window's
                val h = height.roundToInt().coerceAtLeast(0)
                val placeable = measurable.measure(Constraints.fixed(constraints.maxWidth, h))
                layout(constraints.maxWidth, min(h, constraints.maxHeight)) { placeable.place(0, 0) }
            }
            .nestedScroll(nested)
            .draggable(drag, Orientation.Vertical, onDragStarted = { motion[0]?.cancel() }, onDragStopped = { velocity -> settle(velocity) })
        ) {
            content(Modifier.fillMaxSize().clip(RoundedCornerShape(topStart = cornerRadius, topEnd = cornerRadius)))
            if (grabber) {
                // iOS's grabber: 36 × 5, 5 from the sheet's top, over its content
                Box(Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 5.dp)
                    .size(36.dp, 5.dp)
                    .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.25f), RoundedCornerShape(2.5.dp)))
            }
        }
    }
}

private val sheetSpring = spring<Float>(dampingRatio = Spring.DampingRatioNoBouncy, stiffness = Spring.StiffnessMediumLow)
