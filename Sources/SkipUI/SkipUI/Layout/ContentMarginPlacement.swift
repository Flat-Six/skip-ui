// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
#if SKIP
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.ui.unit.dp
#endif

public enum ContentMarginPlacement: Int {
    case automatic = 0
    case scrollContent = 1
    case scrollIndicators = 2
}

/// Holds the content margin values for each placement type.
public struct ContentMargins {
    public var automatic: EdgeInsets?
    public var scrollContent: EdgeInsets?
    public var scrollIndicators: EdgeInsets?

    public init(automatic: EdgeInsets? = nil, scrollContent: EdgeInsets? = nil, scrollIndicators: EdgeInsets? = nil) {
        self.automatic = automatic
        self.scrollContent = scrollContent
        self.scrollIndicators = scrollIndicators
    }

    /// Returns the effective content margin for the given placement.
    /// For `.automatic`, returns `scrollContent` if set, otherwise `automatic`.
    public func effectiveContentMargin(for placement: ContentMarginPlacement) -> EdgeInsets? {
        switch placement {
        case .automatic:
            // For automatic, prefer scrollContent if set, then fall back to automatic
            return scrollContent ?? automatic
        case .scrollContent:
            return scrollContent ?? automatic
        case .scrollIndicators:
            return scrollIndicators ?? automatic
        }
    }

    /// These margins with the given edges of a placement set to the insets', its other edges as they were — how SwiftUI
    /// composes nested `contentMargins`, the innermost winning edge by edge. An automatic margin is every placement's,
    /// so it sets those edges of a placement's own margin too; a placement's own starts from the automatic one.
    public func setting(_ edges: Edge.Set, _ insets: EdgeInsets, for placement: ContentMarginPlacement) -> ContentMargins {
        switch placement {
        case .automatic:
            return ContentMargins(automatic: (automatic ?? EdgeInsets()).replacing(edges, with: insets),
                                  scrollContent: scrollContent?.replacing(edges, with: insets),
                                  scrollIndicators: scrollIndicators?.replacing(edges, with: insets))
        case .scrollContent:
            return ContentMargins(automatic: automatic,
                                  scrollContent: (scrollContent ?? automatic ?? EdgeInsets()).replacing(edges, with: insets),
                                  scrollIndicators: scrollIndicators)
        case .scrollIndicators:
            return ContentMargins(automatic: automatic,
                                  scrollContent: scrollContent,
                                  scrollIndicators: (scrollIndicators ?? automatic ?? EdgeInsets()).replacing(edges, with: insets))
        }
    }

    #if SKIP
    /// Converts the content margins to Compose PaddingValues for the given placement.
    func asComposePaddingValues(for placement: ContentMarginPlacement) -> PaddingValues? {
        guard let insets = effectiveContentMargin(for: placement) else {
            return nil
        }
        return androidx.compose.foundation.layout.PaddingValues(
            start: Double(insets.leading).dp,
            top: Double(insets.top).dp,
            end: Double(insets.trailing).dp,
            bottom: Double(insets.bottom).dp
        )
    }
    #endif
}

extension EdgeInsets {
    /// These insets with the given edges taken from the other's.
    func replacing(_ edges: Edge.Set, with other: EdgeInsets) -> EdgeInsets {
        return EdgeInsets(top: edges.contains(.top) ? other.top : top,
                          leading: edges.contains(.leading) ? other.leading : leading,
                          bottom: edges.contains(.bottom) ? other.bottom : bottom,
                          trailing: edges.contains(.trailing) ? other.trailing : trailing)
    }
}

#endif
