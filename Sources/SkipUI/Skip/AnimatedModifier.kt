// Copyright 2026 Kyle Cronin
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf

/**
 * An animatable modifier's data as it animates, and its body's opacities at the frame's value of it (Flat-Six patch:
 * AnimatedModifierContent). Read as the body's opacities are drawn: at rest each is the one composed, for the value
 * set; while the value moves, the body's opacities at the frame's value, the body run again in Swift (`sample`) once
 * for the value of the frame.
 */
class AnimatedModifierSamples {
    private var progress: Animatable<Float, AnimationVector1D>? = null
    private var target = 0f
    private var sample: ((Double) -> skip.lib.Array<Double>)? = null
    private var sampledAt = Float.NaN
    private var sampled: skip.lib.Array<Double>? = null

    fun update(progress: Animatable<Float, AnimationVector1D>, target: Float, sample: (Double) -> skip.lib.Array<Double>) {
        this.progress = progress
        if (target != this.target || sample !== this.sample) {
            // A new body: what was sampled was the last one's
            sampledAt = Float.NaN
            sampled = null
        }
        this.target = target
        this.sample = sample
    }

    /** The body's opacity in `slot` at the frame's value of the data; `composed`, the body's own for the value set, at rest. */
    fun opacity(slot: Int, composed: Double): Double {
        val progress = progress ?: return composed
        val at = progress.value
        if (at == target) {
            return composed
        }
        if (at != sampledAt) {
            sampled = sample?.invoke(at.toDouble())
            sampledAt = at
        }
        val values = sampled ?: return composed
        return if (slot >= 0 && slot < values.count) values[slot] else composed
    }
}

/** The samples of the animatable modifier whose body is being drawn. */
val LocalAnimatedModifierSamples = compositionLocalOf<AnimatedModifierSamples?> { null }

@Composable
fun ProvideAnimatedModifierSamples(samples: AnimatedModifierSamples, content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalAnimatedModifierSamples provides samples) {
        content()
    }
}
