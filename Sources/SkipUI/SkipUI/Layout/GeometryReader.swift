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
        Box(modifier: context.modifier.fillSize().onGloballyPositioned {
            geometry.update(size: $0.size, frame: $0.boundsInRoot())
        }) {
            if geometry.isPositioned {
                // Constructing the proxy must not read its frame or safe area. The content decides
                // which properties it needs, including across the native Swift bridge.
                let proxy = GeometryProxy(geometry: geometry, density: LocalDensity.current)
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
        }
    }
    #else
    public var body: some View {
        stubView()
    }
    #endif
}

#endif
