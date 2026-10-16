// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE

/// Where `containerBackground(_:for:)` puts its background (Flat-Six patch): a navigation stack's page only — the
/// others are accepted and ignored.
public struct ContainerBackgroundPlacement : Hashable {
    let identifier: Int // For bridging

    init(identifier: Int) {
        self.identifier = identifier
    }

    public static let navigation = ContainerBackgroundPlacement(identifier: 1)
    public static let navigationSplitView = ContainerBackgroundPlacement(identifier: 2)
    public static let tabView = ContainerBackgroundPlacement(identifier: 3)
}

#endif
