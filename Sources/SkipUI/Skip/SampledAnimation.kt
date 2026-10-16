// Copyright 2026 Kyle Cronin
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.AnimationVector
import androidx.compose.animation.core.Easing
import androidx.compose.ui.MotionDurationScale
import kotlinx.coroutines.withContext

/// A custom animation's course as SkipSwiftUI samples it (SwiftUI's `CustomAnimation`): its progress for a unit change,
/// `samples[i]` at `i * step` seconds into a course `seconds` long, replayed by a tween of that length — the tween's
/// fraction is the time, the easing the progress there, linear between samples and the last one past them. `holds`: a
/// course that never ends (the tween as long as an Int's milliseconds), kept at its last sample.
internal class SampledEasing(private val seconds: Double, private val step: Double, samples: skip.lib.Array<Double>, val holds: Boolean) : Easing {
    private val values = FloatArray(samples.count) { samples[it].toFloat() }

    override fun transform(fraction: Float): Float {
        if (values.isEmpty()) return fraction
        val at = fraction.toDouble() * seconds / step
        if (at <= 0.0) return values[0]
        val i = at.toInt()
        if (i >= values.size - 1) return values[values.size - 1]
        val f = (at - i).toFloat()
        return values[i] + (values[i + 1] - values[i]) * f
    }
}

/// The duration scale a held animation runs at: a pose kept, not motion, so it is kept whatever the animator duration
/// scale — at 0 (the developer setting, a test device's) Compose runs every animation to its end at once, and a held
/// one would land at the end it never reaches.
internal object HeldMotionDurationScale : MotionDurationScale {
    override val scaleFactor: Float get() = 1f
}

/// `animateTo`, a held animation at duration scale 1 (HeldMotionDurationScale).
internal suspend fun <T, V : AnimationVector> Animatable<T, V>.animateTo(targetValue: T, animationSpec: AnimationSpec<T>, holds: Boolean) {
    if (holds) {
        withContext(HeldMotionDurationScale) { animateTo(targetValue, animationSpec) }
    } else {
        animateTo(targetValue, animationSpec)
    }
}
