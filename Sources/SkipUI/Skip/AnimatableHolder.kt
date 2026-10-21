// Copyright 2026 Skip
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector

/**
 * The animatable a value animates on, kept across compositions and replaced by one at the new value when the value
 * changes with no animation (Flat-Six patch: toAnimatable) — a snap that lands in the frame of the change, where
 * Animatable.snapTo, a suspend call, landed after the frame's layout.
 */
internal class AnimatableHolder<T, V : AnimationVector>(var animatable: Animatable<T, V>)
