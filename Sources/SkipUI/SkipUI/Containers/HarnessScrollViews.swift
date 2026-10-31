// Copyright 2026 Kyle Cronin
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
#if SKIP
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onGloballyPositioned

/// A screenshot tool's reach into the vertical scroll views on screen (Flat-Six patch): it scrolls the largest one
/// that can scroll to its end, as a UIKit screenshot tool can scroll UIKit's largest scroll view, when the app's Kotlin
/// asks. No touch, so nothing under a finger reacts, and content that fits is left where it is. Lists and vertical
/// scroll views take part while they are composed.
public final class HarnessScrollViews {
    public static let shared = HarnessScrollViews()

    final class Entry {
        var area = 0
        let canScroll: () -> Bool
        let canScrollForward: () -> Bool
        let toEnd: () -> Void

        init(canScroll: @escaping () -> Bool, canScrollForward: @escaping () -> Bool, toEnd: @escaping () -> Void) {
            self.canScroll = canScroll
            self.canScrollForward = canScrollForward
            self.toEnd = toEnd
        }
    }

    private var entries: [Entry] = []

    func register(_ entry: Entry) {
        entries.append(entry)
    }

    func unregister(_ entry: Entry) {
        entries.removeAll { $0 === entry }
    }

    /// The largest scroll view that can scroll, to its end — the newest of those near its size, as what is presented over
    /// a page comes after it. False where nothing on screen scrolls.
    public func toFoot() -> Bool {
        return toFootState() != 0
    }

    /// toFoot, saying what it found: 1 where the scroll view chosen as toFoot chooses it was scrolled toward its end, 2
    /// where it was at its end already (nothing scrolled: the tool's look may end at once), 0 where nothing on screen
    /// scrolls. The view is chosen among those that can scroll at all, its end reached or not, so that one at its end is
    /// not passed over for a smaller one.
    public func toFootState() -> Int {
        let scrolling = entries.filter { $0.area > 0 && $0.canScroll() }
        guard let largest = scrolling.max(by: { $0.area < $1.area }) else {
            return 0
        }
        let chosen = scrolling.last(where: { $0.area * 3 >= largest.area * 2 }) ?? largest
        if !chosen.canScrollForward() {
            return 2
        }
        chosen.toEnd()
        return 1
    }
}

/// Takes a vertical scroll view part in the screenshot tool's scroll to its foot while composed, sized as laid out
/// (Flat-Six patch).
@Composable func HarnessScrollRegistration(canScroll: @escaping () -> Bool, canScrollForward: @escaping () -> Bool, toEnd: @escaping () -> Void) -> Modifier {
    let entry = remember { HarnessScrollViews.Entry(canScroll: canScroll, canScrollForward: canScrollForward, toEnd: toEnd) }
    DisposableEffect(entry) {
        HarnessScrollViews.shared.register(entry)
        onDispose { HarnessScrollViews.shared.unregister(entry) }
    }
    return Modifier.onGloballyPositioned { entry.area = $0.size.width * $0.size.height }
}
#endif
#endif
