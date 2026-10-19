// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
#if SKIP
import androidx.compose.runtime.Composable
import androidx.compose.ui.geometry.Rect
#elseif canImport(CoreGraphics)
import struct CoreGraphics.CGFloat
#endif

public struct SafeAreaRegions : OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let container = SafeAreaRegions(rawValue: 1)
    public static let keyboard = SafeAreaRegions(rawValue: 2)
    public static let all = SafeAreaRegions(rawValue: 3)
}

#if SKIP
import androidx.compose.ui.geometry.Rect

/// Track safe area.
struct SafeArea: Equatable, CustomStringConvertible {
    /// Total bounds of presentation root.
    let presentationBoundsPx: Rect

    /// Safe bounds of presentation root.
    let safeBoundsPx: Rect

    /// The edges whose safe area is solely due to system bars.
    let absoluteSystemBarEdges: Edge.Set

    /// How far the keyboard reaches below the presentation's bottom (Flat-Six patch): the presentation root is padded up
    /// by the keyboard, so its bounds end at the keyboard's top, and the keyboard is the safe area's below them — as iOS
    /// has it, where the keyboard is a safe-area region and a view's size and its insets add up to the window either way.
    let keyboardPx: Float

    init(presentation: Rect, safe: Rect, absoluteSystemBars: Edge.Set = [], keyboard: Float = Float(0.0)) {
        self.presentationBoundsPx = presentation
        self.safeBoundsPx = safe
        self.absoluteSystemBarEdges = absoluteSystemBars
        self.keyboardPx = keyboard
    }

    /// Update the safe area.
    @Composable func insetting(_ edge: Edge, to value: Float) -> SafeArea {
        guard value > Float(0.0) else {
            return self
        }
        var systemBarEdges = absoluteSystemBarEdges
        var (safeLeft, safeTop, safeRight, safeBottom) = safeBoundsPx
        switch edge {
        case .top:
            safeTop = value
            systemBarEdges.remove(.top)
        case .bottom:
            safeBottom = value
            systemBarEdges.remove(.bottom)
        case .leading:
            safeLeft = value
            systemBarEdges.remove(.leading)
        case .trailing:
            safeRight = value
            systemBarEdges.remove(.trailing)
        }
        return SafeArea(presentation: presentationBoundsPx, safe: Rect(top: safeTop, left: safeLeft, bottom: safeBottom, right: safeRight), absoluteSystemBars: systemBarEdges, keyboard: keyboardPx)
    }

    var description: String {
        "SafeArea(presentationBoundsPx: \(presentationBoundsPx), safeBoundsPx: \(safeBoundsPx), absoluteSystemBarEdges: \(absoluteSystemBarEdges), keyboardPx: \(keyboardPx))"
    }
}
#endif

extension View {
    @available(*, unavailable)
    public func safeAreaInset(edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> any View) -> some View {
        return self
    }

    @available(*, unavailable)
    public func safeAreaInset(edge: HorizontalEdge, alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> any View) -> some View {
        return self
    }

    @available(*, unavailable)
    public func safeAreaPadding(_ insets: EdgeInsets) -> some View {
        return self
    }

    @available(*, unavailable)
    public func safeAreaPadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        return self
    }

    @available(*, unavailable)
    public func safeAreaPadding(_ length: CGFloat) -> some View {
        return self
    }

    @available(*, unavailable)
    public func safeAreaBar(edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> some View) -> some View {
        return self
    }

    @available(*, unavailable)
    public func safeAreaBar(edge: HorizontalEdge, alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> some View) -> some View {
        return self
    }
}

#endif
