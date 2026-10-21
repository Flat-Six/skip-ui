// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
#if SKIP
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.IntSize
#elseif canImport(CoreGraphics)
import struct CoreGraphics.CGFloat
import struct CoreGraphics.CGRect
import struct CoreGraphics.CGSize
#endif

// SKIP @bridge
public struct GeometryProxy {
    #if SKIP
    private let fixedGlobalFramePx: Rect
    private let fixedSizePx: IntSize
    let density: Density
    private let safeArea: SafeArea?
    private let geometry: GeometryReaderState?
    private let readerSizePx: IntSize?
    private let readerInsetsPx: GeometryReaderInsets?

    /// Fixed snapshots are still used by onGeometryChange's transform/action contract.
    init(sizePx: IntSize, globalFramePx: Rect, density: Density, safeArea: SafeArea?) {
        self.fixedSizePx = sizePx
        self.fixedGlobalFramePx = globalFramePx
        self.density = density
        self.safeArea = safeArea
        self.geometry = nil
        self.readerSizePx = nil
        self.readerInsetsPx = nil
    }

    /// Reader proxies defer snapshot observation to the properties their content accesses.
    init(geometry: GeometryReaderState, density: Density) {
        self.fixedSizePx = IntSize.Zero
        self.fixedGlobalFramePx = Rect.Zero
        self.density = density
        self.safeArea = nil
        self.geometry = geometry
        self.readerSizePx = nil
        self.readerInsetsPx = nil
    }

    /// A reader made with the size it is laid out at (Flat-Six patch): its size and its insets this frame's, the frame
    /// still the reader's last layout, read as its content asks for it.
    init(geometry: GeometryReaderState, sizePx: IntSize, insetsPx: GeometryReaderInsets, density: Density) {
        self.fixedSizePx = sizePx
        self.fixedGlobalFramePx = Rect.Zero
        self.density = density
        self.safeArea = nil
        self.geometry = geometry
        self.readerSizePx = sizePx
        self.readerInsetsPx = insetsPx
    }

    private var globalFramePx: Rect {
        geometry?.globalFramePx ?? fixedGlobalFramePx
    }
    #endif

    public var size: CGSize {
        #if SKIP
        // Root bounds can be clipped by a scroll viewport; size describes the full layout.
        let size = readerSizePx ?? geometry?.sizePx ?? fixedSizePx
        return with(density) {
            CGSize(width: Double(size.width.toDp().value), height: Double(size.height.toDp().value))
        }
        #else
        return .zero
        #endif
    }

    // SKIP @bridge
    public var bridgedSize: (CGFloat, CGFloat) {
        let size = self.size
        return (size.width, size.height)
    }

    // SKIP @bridge
    public var bridgedSafeAreaInsets: (CGFloat, CGFloat, CGFloat, CGFloat) {
        let insets = self.safeAreaInsets
        return (insets.top, insets.leading, insets.bottom, insets.trailing)
    }

    @available(*, unavailable)
    public subscript<T>(anchor: Any /* Anchor<T> */) -> T {
        fatalError()
    }

    public var safeAreaInsets: EdgeInsets {
        #if SKIP
        if let geometry {
            let insets = readerInsetsPx ?? geometry.insetsPx
            return with(density) {
                EdgeInsets(top: Double(insets.top.toDp().value), leading: Double(insets.left.toDp().value), bottom: Double(insets.bottom.toDp().value), trailing: Double(insets.right.toDp().value))
            }
        }
        guard let safeArea = safeArea else {
            return EdgeInsets()
        }
        return with(density) {
            let presentation = safeArea.presentationBoundsPx
            let safe = safeArea.safeBoundsPx
            return EdgeInsets(
                top: Double((safe.top - presentation.top).toDp().value),
                leading: Double((safe.left - presentation.left).toDp().value),
                bottom: Double((presentation.bottom + safeArea.keyboardPx - safe.bottom).toDp().value),   // the keyboard the safe area's (Flat-Six patch)
                trailing: Double((presentation.right - safe.right).toDp().value)
            )
        }
        #else
        return EdgeInsets()
        #endif
    }

    @available(*, unavailable)
    public func bounds(of coordinateSpace: NamedCoordinateSpace) -> CGRect? {
        fatalError()
    }

    public func frame(in coordinateSpace: some CoordinateSpaceProtocol) -> CGRect {
        #if SKIP
        if coordinateSpace.coordinateSpace.isGlobal {
            return with(density) {
                CGRect(x: Double(globalFramePx.left.toDp().value), y: Double(globalFramePx.top.toDp().value), width: Double(globalFramePx.width.toDp().value), height: Double(globalFramePx.height.toDp().value))
            }
        } else {
            return CGRect(origin: .zero, size: size)
        }
        #else
        return .zero
        #endif
    }

    // SKIP @bridge
    public func frame(bridgedCoordinateSpace: Int, name: Any?) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        let coordinateSpace = CoordinateSpaceProtocolFrom(bridged: bridgedCoordinateSpace, name: name as? AnyHashable)
        let frame = self.frame(in: coordinateSpace)
        return (frame.origin.x, frame.origin.y, frame.width, frame.height)
    }
}

#endif
