// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
#if SKIP
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.boundsInParent
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import skip.model.StateTracking
#endif

// SKIP @bridge
public struct GeometryReader : View, Renderable {
    public let content: (GeometryProxy) -> any View

    // SKIP @bridge
    public init(@ViewBuilder content: @escaping (GeometryProxy) -> any View) {
        self.content = content
    }

    #if SKIP
    @Composable override func Render(context: ComposeContext) {
        let geometry = remember { GeometryReaderState() }
        UpdateGeometryReaderSafeArea(geometry)
        let modifier = context.modifier.fillSize().onGloballyPositioned {
            geometry.update(size: $0.size, frame: $0.boundsInRoot())
        }
        // The content made with the size it is laid out at, in the same frame, as SwiftUI gives a reader its size
        // (Flat-Six patch). Made from the size of the layout before, a resize — a turn, a fold — was drawn first with
        // the old size and the new window, and again a frame later; a reader around the whole app made every turn
        // draw a frame of the wrong layout. GeometryReaderLayout knows the size as it measures. A layout made as it
        // measures can't be asked its intrinsic size, which Skip asks in a scroll direction (ComposeContainer's
        // fills), so there the reader stays a frame behind, as before; and with an unbounded size it waits for its
        // layout, as before.
        let scrollAxes = EnvironmentValues.shared._layoutScrollAxes
        if !scrollAxes.contains(.vertical) && !scrollAxes.contains(.horizontal) {
            GeometryReaderLayout(modifier: modifier) { sizePx in
                if let sizePx {
                    let proxy = GeometryProxy(geometry: geometry, sizePx: sizePx, insetsPx: geometry.composedInsetsPx, density: LocalDensity.current)
                    RenderContent(proxy: proxy, context: context)
                } else if geometry.isPositioned {
                    RenderContent(proxy: GeometryProxy(geometry: geometry, density: LocalDensity.current), context: context)
                }
            }
        } else {
            Box(modifier: modifier) {
                if geometry.isPositioned {
                    // Constructing the proxy must not read its frame or safe area. The content decides
                    // which properties it needs, including across the native Swift bridge.
                    RenderContent(proxy: GeometryProxy(geometry: geometry, density: LocalDensity.current), context: context)
                }
            }
        }
    }

    @Composable private func RenderContent(proxy: GeometryProxy, context: ComposeContext) {
        // The content is made as a body is (Flat-Six patch): an observable made with it — a view's @State
        // initial value, made anew each time — starts tracking once the content is made, as StateTracking.register
        // has one a body makes do. Tracked at once, its own init's writes invalidated this reader, which made the
        // content again and the observable with it, every frame (a root view whose tabs each make an observable
        // model)
        StateTracking.pushBody()
        let view = content(proxy)
        StateTracking.popBody()
        view.Compose(context.content())
    }
    #else
    public var body: some View {
        stubView()
    }
    #endif
}

#endif
