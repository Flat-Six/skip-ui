// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if SKIP
import android.util.Log
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.requiredHeight
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.constrainHeight
import androidx.compose.ui.unit.constrainWidth
import kotlin.math.abs
import androidx.compose.ui.unit.dp

/// Compose a view with the given frame.
@Composable func FrameLayout(content: Renderable, context: ComposeContext, width: CGFloat?, height: CGFloat?, alignment: Alignment) {
    var modifier = context.modifier
    // A frame of zero width or height drew nothing hung outside it on Android; a pixel's does, as SwiftUI's zero frame
    // does (Flat-Six patch: a label centred on a table column's edge)
    let pixel = with(LocalDensity.current) { 1.toDp() }
    if let width {
        modifier = modifier.requiredWidth(width > 0.0 ? width.dp : pixel)
    }
    if let height {
        modifier = modifier.requiredHeight(height > 0.0 ? height.dp : pixel)
    }

    // If our content has a zIndex, we need to pull it into our modifiers so that it applies within the original
    // parent container. Otherwise the Box we use below would hide it
    modifier = ZIndexModifier.consume(for: content, with: modifier)

    ComposeContainer(modifier: modifier, fixedWidth: width != nil, fixedHeight: height != nil) { modifier in
        let contentContext = context.content()
        Box(modifier: modifier, contentAlignment: alignment.asComposeAlignment()) {
            content.Render(context: contentContext)
        }
    }
}

/// Compose a view with the given frame, its width and height (when given) read as it is measured, never while
/// composing: an animated frame re-measures the view on each frame rather than recomposing it and all it holds
/// (Flat-Six patch). Otherwise as the frame above.
@Composable func FrameLayout(content: Renderable, context: ComposeContext, animatedWidth: (() -> Double)?, animatedHeight: (() -> Double)?, alignment: Alignment) {
    var modifier = context.modifier.animatedRequiredSize(width: animatedWidth, height: animatedHeight)
    modifier = ZIndexModifier.consume(for: content, with: modifier)
    ComposeContainer(modifier: modifier, fixedWidth: animatedWidth != nil, fixedHeight: animatedHeight != nil) { modifier in
        let contentContext = context.content()
        Box(modifier: modifier, contentAlignment: alignment.asComposeAlignment()) {
            content.Render(context: contentContext)
        }
    }
}

/// Compose a view with the given frame.
@Composable func FrameLayout(content: Renderable, context: ComposeContext, minWidth: CGFloat?, idealWidth: CGFloat?, maxWidth: CGFloat?, minHeight: CGFloat?, idealHeight: CGFloat?, maxHeight: CGFloat?, alignment: Alignment) {
    ComposeFlexibleContainer(modifier: context.modifier, flexibleWidthIdeal: flexibleLayoutFloat(idealWidth), flexibleWidthMin: flexibleLayoutFloat(minWidth), flexibleWidthMax: flexibleLayoutFloat(maxWidth), flexibleHeightIdeal: flexibleLayoutFloat(idealHeight), flexibleHeightMin: flexibleLayoutFloat(minHeight), flexibleHeightMax: flexibleLayoutFloat(maxHeight)) { modifier in
        let contentContext = context.content()
        Box(modifier: modifier, contentAlignment: alignment.asComposeAlignment()) {
            content.Render(context: contentContext)
        }
    }
}

private func flexibleLayoutFloat(_ value: CGFloat?) -> Float? {
    guard let value else {
        return nil
    }
    return value == Double.infinity ? Float.flexibleFill : Float(value)
}

/// Compose a view with the given background.
@Composable func BackgroundLayout(content: Renderable, context: ComposeContext, background: View, alignment: Alignment) {
    TargetViewLayout(context: context, isOverlay: false, alignment: alignment, target: { content.Render(context: $0) }, dependent: { background.Compose(context: $0) })
}

/// Compose a view with the given overlay.
@Composable func OverlayLayout(content: Renderable, context: ComposeContext, overlay: View, alignment: Alignment) {
    TargetViewLayout(context: context, isOverlay: true, alignment: alignment, target: { content.Render(context: $0) }, dependent: { overlay.Compose(context: $0) })
}

/// Compose a view with the given mask.
/// The mask view's alpha channel is used to clip the content.
@Composable func MaskLayout(content: Renderable, context: ComposeContext, mask: View, alignment: Alignment) {
    // We use CompositingStrategy.Offscreen to render content and mask into an offscreen buffer
    // Then apply BlendMode.DstIn which keeps the destination (content) only where the source (mask) has alpha
    ComposeContainer(modifier: context.modifier) { modifier in
        Layout(modifier: modifier.graphicsLayer(compositingStrategy: CompositingStrategy.Offscreen), content: {
            // First render the content
            content.Render(context: context.content())
            // Then render the mask with DstIn blend mode - this will use mask's alpha to clip content
            ComposeContainer(fixedWidth: true, fixedHeight: true) { maskModifier in
                Box(modifier: maskModifier.graphicsLayer(compositingStrategy: CompositingStrategy.Offscreen, blendMode: BlendMode.DstIn)) {
                    mask.Compose(context: context.content())
                }
            }
        }) { measurables, constraints in
            guard !measurables.isEmpty() else {
                return layout(width: 0, height: 0) {}
            }
            // Base layout entirely on the content view size
            let contentPlaceable = measurables[0].measure(constraints)
            let maskConstraints = Constraints(maxWidth: contentPlaceable.width, maxHeight: contentPlaceable.height)
            let maskPlaceables = measurables.drop(1).map { $0.measure(maskConstraints) }
            layout(width: contentPlaceable.width, height: contentPlaceable.height) {
                contentPlaceable.placeRelative(x: 0, y: 0)
                for maskPlaceable in maskPlaceables {
                    let (x, y) = placeContent(width: maskPlaceable.width, height: maskPlaceable.height, inWidth: contentPlaceable.width, inHeight: contentPlaceable.height, alignment: alignment)
                    maskPlaceable.placeRelative(x: x, y: y)
                }
            }
        }
    }
}

@Composable func TargetViewLayout(context: ComposeContext, isOverlay: Bool, alignment: Alignment, target: @Composable (ComposeContext) -> Void, dependent: @Composable (ComposeContext) -> Void) {
    // ComposeContainer is needed to properly handle content that fills width/height
    ComposeContainer(modifier: context.modifier) { modifier in
        Layout(modifier: modifier, content: {
            target(context.content())
            // Dependent view lays out with fixed bounds dictated by the target view size
            ComposeContainer(fixedWidth: true, fixedHeight: true) { modifier in
                dependent(context.content(modifier: modifier))
            }
        }) { measurables, constraints in
            guard !measurables.isEmpty() else {
                return layout(width: 0, height: 0) {}
            }
            // Base layout entirely on the target view size
            let targetPlaceable = measurables[0].measure(constraints)
            let dependentConstraints = Constraints(maxWidth: targetPlaceable.width, maxHeight: targetPlaceable.height)
            let dependentPlaceables = measurables.drop(1).map { $0.measure(dependentConstraints) }
            layout(width: targetPlaceable.width, height: targetPlaceable.height) {
                if !isOverlay {
                    for dependentPlaceable in dependentPlaceables {
                        let (x, y) = placeContent(width: dependentPlaceable.width, height: dependentPlaceable.height, inWidth: targetPlaceable.width, inHeight: targetPlaceable.height, alignment: alignment)
                        dependentPlaceable.placeRelative(x: x, y: y)
                    }
                }
                targetPlaceable.placeRelative(x: 0, y: 0)
                if isOverlay {
                    for dependentPlaceable in dependentPlaceables {
                        let (x, y) = placeContent(width: dependentPlaceable.width, height: dependentPlaceable.height, inWidth: targetPlaceable.width, inHeight: targetPlaceable.height, alignment: alignment)
                        dependentPlaceable.placeRelative(x: x, y: y)
                    }
                }
            }
        }
    }
}

/// Layout the given view to ignore the given safe areas.
@Composable func IgnoresSafeAreaLayout(content: Renderable, context: ComposeContext, expandInto: Edge.Set, logTag: String = "") {
    ComposeContainer(modifier: context.modifier) { modifier in
        IgnoresSafeAreaLayout(expandInto: expandInto, checkEdges: expandInto, modifier: modifier, logTag: logTag) { _, _ in
            content.Render(context.content())
        }
    }
}

/// Layout the given content ignoring the given safe areas.
///
/// - Parameter expandInto: Which safe area edges to expand into, if adjacent. Any expansion will be passed to
///     the given closure as a pixel rect.
/// - Parameter checkEdges: Which edges to check to see if we're against a safe area. Any matching edges will be
///     passed to the given closure.
/// - Parameter bottomAdjacencyTolerancePx: Distance from the bottom safe boundary still considered adjacent.
/// - Parameter logTag: When non-empty, emits Android ``Log`` lines with tag `SkipUI.ISAL.<logTag>` (e.g. filter logcat `SkipUI.ISAL.List`).
/// - Parameter insetsContentSides: Whether the target keeps its content in from the sides by the inset it is given (a
///     tab view, a navigation stack, a list), so its content's layout box is the safe-clamped one (_layoutBoxPx).
@Composable func IgnoresSafeAreaLayout(expandInto: Edge.Set, checkEdges: Edge.Set = [], modifier: Modifier = Modifier, bottomAdjacencyTolerancePx: Float = Float(0.1), insetsContentSides: Bool = false, logTag: String = "", target: @Composable (IntRect, Edge.Set) -> Void) {
    guard let safeArea = EnvironmentValues.shared._safeArea else {
        if !logTag.isEmpty {
            Log.d("SkipUI.ISAL.\(logTag)", "no SafeArea in environment; skipping expansion")
        }
        target(IntRect.Zero, [])
        return
    }

    let effectiveBottomAdjacencyTolerancePx = max(
        bottomAdjacencyTolerancePx,
        safeArea.presentationBoundsPx.bottom - safeArea.safeBoundsPx.bottom
    )

    if !logTag.isEmpty {
        LaunchedEffect(logTag, expandInto.rawValue, checkEdges.rawValue) {
            Log.d("SkipUI.ISAL.\(logTag)", "init expandInto=\(expandInto) checkEdges=\(checkEdges) edgesState(initial)=\(checkEdges)")
        }
    }

    // Note: We only allow edges we're interested in to affect our internal state and output. This is critical
    // for reducing recompositions, especially during e.g. navigation animations. We also match our internal
    // state to our output to ensure we aren't re-calling the target block when output hasn't changed
    let edgesState = remember { mutableStateOf(checkEdges) }
    let edges = edgesState.value
    // The sides as SwiftUI has them (Flat-Six patch): a view reaches from where its parent put it to the
    // presentation's edge — not the whole inset again from wherever it is, which took a view already at the edge (inside
    // one that ignored the safe area) past it — and the safe area at the sides goes on to its content whole, where Skip
    // had spent it: a container inside keeps its content clear of a cutout however its ancestors were laid out. Where the
    // parent put it is learnt once it is laid out; until then the safe area's edge stands in, as before.
    // The sides kept as where the slot lay in its layout box (Flat-Six patch): the box its container composed it in this
    // frame (_layoutBoxPx) — the presentation's content, or the reach of a view around it that ignores the safe area. Kept
    // as places in the window, the slot was learnt a layout late: a turned phone placed every such view from its portrait
    // slot in the landscape window — the cutout's side not reached and the content kept in from it instead, a strip down
    // the screen's side — and put each right a frame and a level at a time. A view at its box's edge is at the edge after
    // a resize as before it, and only a view at an edge reaches.
    let layoutBox = EnvironmentValues.shared._layoutBoxPx
    let slotState = remember { mutableStateOf<Rect?>(nil) }
    var slotLeft = safeArea.safeBoundsPx.left
    var slotRight = safeArea.safeBoundsPx.right
    if let slot = slotState.value {
        slotLeft = layoutBox != nil ? layoutBox!.left + slot.left : slot.left
        slotRight = layoutBox != nil ? layoutBox!.right - slot.right : slot.right
    }
    // The top and bottom reached from the slot as well (Flat-Six patch): a view the parent had already put up in the
    // status bar's band reached the whole band again above that — a view beside a column on a phone on its side 100 px
    // high, a strip of the stack's ground under it at the foot. Each expansion rounded as Compose rounds the padding it
    // undoes, not truncated (Flat-Six patch): a bar's 257.5 px took 258 of padding and gave back 257, a pixel's line of
    // what is behind at the screen's edge
    // The top and bottom kept as where the slot lay against the safe area's edges (Flat-Six patch): a navigation
    // stack moves its content's box and the safe area it gives it together — a bar shown or hidden, the room reserved for
    // one dropped — so the slot is where it now is in the same pass. Kept as places in the window, the slot was learnt a
    // frame late: a full-screen view ignoring the safe area sat a top bar's height off for the first frames of an
    // animated transition, and jumped back as the slot was learnt again.
    var slotTop = safeArea.safeBoundsPx.top
    var slotBottom = safeArea.safeBoundsPx.bottom
    if let slot = slotState.value {
        slotTop += slot.top
        slotBottom += slot.bottom
    }
    // An adjacent view reaches from its slot all the way to the edge: a slot a pixel under the safe area's edge (whole
    // pixels under a half-pixel inset) left that pixel's line of what was behind
    var expansionTop = 0
    if expandInto.contains(Edge.Set.top) && edges.contains(Edge.Set.top) {
        expansionTop = Int(max(Float(0.0), slotTop - safeArea.presentationBoundsPx.top).rounded())
    }
    var expansionBottom = 0
    if expandInto.contains(Edge.Set.bottom) && edges.contains(Edge.Set.bottom) {
        expansionBottom = Int(max(Float(0.0), safeArea.presentationBoundsPx.bottom - slotBottom).rounded())
    }
    let isRTL = LocalLayoutDirection.current == androidx.compose.ui.unit.LayoutDirection.Rtl
    let leftEdge: Edge.Set = isRTL ? Edge.Set.trailing : Edge.Set.leading
    let rightEdge: Edge.Set = isRTL ? Edge.Set.leading : Edge.Set.trailing
    var expansionLeft = 0
    var expansionRight = 0
    if expandInto.contains(leftEdge) && edges.contains(leftEdge) {
        expansionLeft = Int(max(Float(0.0), min(slotLeft, safeArea.safeBoundsPx.left) - safeArea.presentationBoundsPx.left).rounded())
    }
    if expandInto.contains(rightEdge) && edges.contains(rightEdge) {
        expansionRight = Int(max(Float(0.0), safeArea.presentationBoundsPx.right - max(slotRight, safeArea.safeBoundsPx.right)).rounded())
    }
    // How far the view, so reached, lies in the unsafe sides: what a container keeps its content in by (the target's
    // left and right; its top and bottom stay what it reached into)
    var insetLeft = 0
    var insetRight = 0
    if edges.contains(leftEdge) {
        insetLeft = Int(max(Float(0.0), safeArea.safeBoundsPx.left - (slotLeft - Float(expansionLeft))).rounded())
    }
    if edges.contains(rightEdge) {
        insetRight = Int(max(Float(0.0), (slotRight + Float(expansionRight)) - safeArea.safeBoundsPx.right).rounded())
    }

    var (safeLeft, safeTop, safeRight, safeBottom) = safeArea.safeBoundsPx
    safeTop -= expansionTop
    safeBottom += expansionBottom

    let contentSafeBounds = Rect(top: safeTop, left: safeLeft, bottom: safeBottom, right: safeRight)
    let contentSafeArea = SafeArea(presentation: safeArea.presentationBoundsPx, safe: contentSafeBounds, absoluteSystemBars: safeArea.absoluteSystemBarEdges, keyboard: safeArea.keyboardPx)
    // The box the content takes its place from (Flat-Six patch: _layoutBoxPx): the view as it reaches — its slot out by
    // what it reached — less what its target keeps its content in by at the sides, where it does
    let contentLeft = slotLeft - Float(expansionLeft) + (insetsContentSides ? Float(insetLeft) : Float(0.0))
    let contentRight = slotRight + Float(expansionRight) - (insetsContentSides ? Float(insetRight) : Float(0.0))
    let contentBox = Rect(left: contentLeft, top: Float(0.0), right: contentRight, bottom: Float(0.0))
    EnvironmentValues.shared.setValues {
        $0.set_safeArea(contentSafeArea)
        $0.set_layoutBoxPx(contentBox)
        return ComposeResult.ok
    } in: {
        Layout(modifier: modifier.onGloballyPositionedInWindow {
            // where the parent put the view: across, where it lies in its layout box (above); its top and bottom as where
            // they lie against the safe area's (above)
            let slot = Rect(top: $0.top - safeArea.safeBoundsPx.top, left: layoutBox != nil ? $0.left - layoutBox!.left : $0.left, bottom: $0.bottom - safeArea.safeBoundsPx.bottom, right: layoutBox != nil ? layoutBox!.right - $0.right : $0.right)
            let known = slotState.value
            if known == nil || abs(known!.left - slot.left) > Float(0.5) || abs(known!.right - slot.right) > Float(0.5) || abs(known!.top - slot.top) > Float(0.5) || abs(known!.bottom - slot.bottom) > Float(0.5) {
                slotState.value = slot
            }
            let probeEdges = expandInto.union(checkEdges)
            let newEdges = adjacentSafeAreaEdges(bounds: $0, safeArea: safeArea, isRTL: isRTL, checkEdges: probeEdges, bottomTolerancePx: effectiveBottomAdjacencyTolerancePx)
            if !logTag.isEmpty {
                let previous = edgesState.value
                if newEdges != previous {
                    Log.d("SkipUI.ISAL.\(logTag)", "onGloballyPositionedInWindow adjacentEdges \(previous) -> \(newEdges) (probeEdges=\(probeEdges))")
                }
            }
            edgesState.value = newEdges
        }, content: {
            let expansion = IntRect(top: expansionTop, left: insetLeft, bottom: expansionBottom, right: insetRight)
            target(expansion, edges.intersection(checkEdges))
        }) { measurables, constraints in
            guard !measurables.isEmpty() else {
                return layout(width: 0, height: 0) {}
            }
            // Guard the arithmetic: in an intrinsic measurement pass (e.g. a parent fill in a
            // scroll direction using IntrinsicSize.Max) Compose calls measure with
            // maxHeight == Constraints.Infinity, and adding the expansion overflows Int to a
            // negative value, crashing Constraints.copy. Preserve Infinity and never go below
            // the min constraints
            let updatedConstraints = constraints.copy(maxWidth: constraint(constraints.maxWidth, adding: expansionLeft + expansionRight, atLeast: constraints.minWidth), maxHeight: constraint(constraints.maxHeight, adding: expansionTop + expansionBottom, atLeast: constraints.minHeight))
            let targetPlaceables = measurables.map { $0.measure(updatedConstraints) }
            // Across, the view keeps its parent's slot and draws its content out past it (Flat-Six patch): Skip reported
            // the reached width and left Compose to centre it on the slot, which a parent with room to spare — a row — did
            // not do: the content sat half the reach off (a side column's back button half under the screen's edge) and the
            // row laid its other children out around the reached width. Content that did not take the width offered (a
            // fixed size) stays where it is. The top and bottom as before.
            let first = targetPlaceables[0]
            let reachX = expansionLeft + expansionRight
            let fillsWidth = reachX > 0 && constraints.hasBoundedWidth && first.width >= updatedConstraints.maxWidth
            let width = fillsWidth ? constraints.constrainWidth(first.width - reachX) : first.width
            // Down, likewise (Flat-Six patch): content that took the height offered keeps the slot and runs out past it
            // by what it reached, placed there outright — Skip reported the reached height and left Compose to centre it on
            // the slot, which put it where it belonged only from a slot between the bars. Content that did not take it is
            // placed where Compose's centring of an oversized node put it, the size reported within the constraints: an
            // oversized node is read back where the centring moved it, not where the parent put it, and the reach from that
            // slot shrank, pass on pass, until the content sat a status bar low.
            let reachY = expansionTop + expansionBottom
            let fillsHeight = reachY > 0 && constraints.hasBoundedHeight && first.height >= updatedConstraints.maxHeight
            let height = fillsHeight ? constraints.constrainHeight(first.height - reachY) : constraints.constrainHeight(first.height)
            let centring = fillsHeight ? 0 : (first.height - height) / 2
            layout(width: width, height: height) {
                // Layout will center extra space by default (the top and bottom of content that did not fill)
                let relativeTop = fillsHeight ? expansionTop : centring + expansionTop - ((expansionTop + expansionBottom) / 2)
                let expansionLeading = isRTL ? expansionRight : expansionLeft
                let x = fillsWidth ? -expansionLeading : 0
                for targetPlaceable in targetPlaceables {
                    targetPlaceable.placeRelative(x = x, y = -relativeTop)
                }
            }
        }
    }
}

private func adjacentSafeAreaEdges(bounds: Rect, safeArea: SafeArea, isRTL: Bool, checkEdges: Edge.Set, bottomTolerancePx: Float = Float(0.1)) -> Edge.Set {
    var edges: Edge.Set = []
    // a few pixels' tolerance at the top (Flat-Six patch): parents place at whole pixels under half-pixel insets, and
    // a view's ground, put at 258 under a safe area's 257.5 — at 259 with the keyboard up — was taken for clear of it
    // and never reached up under the bar above; a view really clear of the edge sits a bar's height lower
    if checkEdges.contains(Edge.Set.top), bounds.top <= safeArea.safeBoundsPx.top + 3.0 {
        edges.insert(Edge.Set.top)
    }
    if checkEdges.contains(Edge.Set.bottom), bounds.bottom >= safeArea.safeBoundsPx.bottom - bottomTolerancePx {
        edges.insert(Edge.Set.bottom)
    }
    if isRTL {
        if checkEdges.contains(Edge.Set.leading), bounds.right >= safeArea.safeBoundsPx.right - 0.1 {
            edges.insert(Edge.Set.leading)
        }
        if checkEdges.contains(Edge.Set.trailing), bounds.left <= safeArea.safeBoundsPx.left + 0.1 {
            edges.insert(Edge.Set.trailing)
        }
    } else {
        if checkEdges.contains(Edge.Set.leading), bounds.left <= safeArea.safeBoundsPx.left + 0.1 {
            edges.insert(Edge.Set.leading)
        }
        if checkEdges.contains(Edge.Set.trailing), bounds.right >= safeArea.safeBoundsPx.right - 0.1 {
            edges.insert(Edge.Set.trailing)
        }
    }
    return edges
}

/// Layout the given view with the given padding.
@Composable func PaddingLayout(content: Renderable, padding: EdgeInsets, context: ComposeContext) {
    PaddingLayout(padding: padding, context: context) { content.Render($0) }
}

@Composable func PaddingLayout(padding: EdgeInsets, context: ComposeContext, target: @Composable (ComposeContext) -> Void) {
    ComposeContainer(modifier: context.modifier) { modifier in
        let density = LocalDensity.current
        let topPx = with(density) { padding.top.dp.roundToPx() }
        let bottomPx = with(density) { padding.bottom.dp.roundToPx() }
        let leadingPx = with(density) { padding.leading.dp.roundToPx() }
        let trailingPx = with(density) { padding.trailing.dp.roundToPx() }
        Layout(modifier: modifier, content = {
            target(context.content())
        }) { measurables, constraints in
            guard !measurables.isEmpty() else {
                return layout(width: 0, height: 0) {}
            }
            let updatedConstraints = constraints.copy(minWidth: constraint(constraints.minWidth, subtracting: leadingPx + trailingPx), minHeight: constraint(constraints.minHeight, subtracting: topPx + bottomPx), maxWidth: constraint(constraints.maxWidth, subtracting: leadingPx + trailingPx), maxHeight: constraint(constraints.maxHeight, subtracting: topPx + bottomPx))
            let targetPlaceables = measurables.map { $0.measure(updatedConstraints) }
            layout(width: targetPlaceables[0].width + leadingPx + trailingPx, height: targetPlaceables[0].height + topPx + bottomPx) {
                for targetPlaceable in targetPlaceables {
                    targetPlaceable.placeRelative(x: leadingPx, y: topPx)
                }
            }
        }
    }
}

/// Layout the given view with the given position: `x` and `y` read as it is placed, never while composing, so an
/// animated position re-places the view on each frame rather than recomposing it (Flat-Six patch).
@Composable func PositionLayout(content: Renderable, x: @escaping () -> CGFloat, y: @escaping () -> CGFloat, context: ComposeContext) {
    PositionLayout(x: x, y: y, context: context) { content.Render($0) }
}

@Composable func PositionLayout(x: @escaping () -> CGFloat, y: @escaping () -> CGFloat, context: ComposeContext, target: @Composable (ComposeContext) -> Void) {
    // SwiftUI expands to fill the available space and places within that
    Box(modifier: context.modifier.fillSize()) {
        let density = LocalDensity.current
        Layout(content = {
            target(context.content())
        }) { measurables, constraints in
            guard !measurables.isEmpty() else {
                return layout(width: 0, height: 0) {}
            }
            let targetPlaceables = measurables.map { $0.measure(constraints) }
            layout(width: targetPlaceables[0].width, height: targetPlaceables[0].height) {
                let xPx = with(density) { x().dp.roundToPx() }
                let yPx = with(density) { y().dp.roundToPx() }
                for targetPlaceable in targetPlaceables {
                    targetPlaceable.placeRelative(x: xPx - targetPlaceable.width / 2, y: yPx - targetPlaceable.height / 2)
                }
            }
        }
    }
}

private func constraint(_ value: Int, subtracting: Int) -> Int {
    guard value != Int.MAX_VALUE else {
        return value
    }
    return max(0, value - subtracting)
}

private func constraint(_ value: Int, adding: Int, atLeast: Int) -> Int {
    guard value != Int.MAX_VALUE else {
        return value
    }
    return max(atLeast, value + adding)
}

private func placeContent(width: Int, height: Int, inWidth: Int, inHeight: Int, alignment: Alignment) -> (Int, Int) {
    let centerX = (inWidth - width) / 2
    let centerY = (inHeight - height) / 2
    switch alignment {
    case .leading, .leadingFirstTextBaseline, .leadingLastTextBaseline:
        return (0, centerY)
    case .trailing, .trailingFirstTextBaseline, .trailingLastTextBaseline:
        return (inWidth - width, centerY)
    case .top:
        return (centerX, 0)
    case .bottom:
        return (centerX, inHeight - height)
    case .topLeading:
        return (0, 0)
    case .topTrailing:
        return (inWidth - width, 0)
    case .bottomLeading:
        return (0, inHeight - height)
    case .bottomTrailing:
        return (inWidth - width, inHeight - height)
    default:
        return (centerX, centerY)
    }
}

#endif
