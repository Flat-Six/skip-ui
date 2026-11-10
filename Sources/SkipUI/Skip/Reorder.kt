// Copyright 2026 Kyle Cronin
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.runtime.compositionLocalOf
import org.burnoutcrew.reorderable.ReorderableLazyListState

/// The reorderable state of the list a row is composed in, for a drag handle inside the row (`View.reorderHandle()`):
/// a `List` reorders its rows by a long press on the row, and a handle that starts the drag as soon as it is moved
/// — as a list's edit mode has on iOS — needs the state the row's `ReorderableItem` was given.
internal val LocalReorderableState = compositionLocalOf<ReorderableLazyListState?> { null }
