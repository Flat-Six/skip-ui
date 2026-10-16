// Copyright 2026 Kyle Cronin
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
#if SKIP
import SkipModel
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
#endif

/// The body of a SwiftUI animatable modifier whose animatable data is a number, for SkipSwiftUI (Flat-Six patch).
/// SwiftUI animates the data and runs the body at each frame's value of it. Here the body (`body`) runs for the value
/// set, as any modifier's does, and the data is animated as an animatable modifier's value is. Each `opacity` the body
/// sets has a slot, and is drawn at its slot of `sample`: the body's opacities at the frame's value, the body run again
/// in Swift once a frame while the value moves, building no views (Skip/AnimatedModifier.kt). So a crossfade biased
/// toward its ends — `pow(progress, 2.5)` — fades as SwiftUI fades it, where it had run evenly with the spring. The
/// body's other modifiers animate between their values at the two ends, as before.
// SKIP @bridge
public struct AnimatedModifierContent : View {
    let value: Double
    let modified: () -> any View
    let sample: (Double) -> [Double]
    #if SKIP
    let animTx: StateMutationTransaction?
    #endif

    // SKIP @bridge
    public init(animatableValue: Double, body: @escaping () -> any View, sample: @escaping (Double) -> [Double]) {
        #if SKIP
        self.animTx = StateTracking.captureLastReadAndClear()
        #endif
        self.value = animatableValue
        self.modified = body
        self.sample = sample
    }

    #if SKIP
    @Composable override func Evaluate(context: ComposeContext, options: Int) -> kotlin.collections.List<Renderable> {
        let progress = Float(value).asAnimatable(context: context, animTx: animTx)
        let samples = remember { AnimatedModifierSamples() }
        samples.update(progress, Float(value), sample)
        StateTracking.pushBody()
        let renderables = modified().Evaluate(context: context, options: options)
        StateTracking.popBody()
        // Each of the body's renderables drawn with the samples at hand, through a modifier, so that what a parent asks
        // of it — a spacer, an id, a tag — it still answers, as a modifier's body does
        let provider = RenderModifier { renderable, context in
            ProvideAnimatedModifierSamples(samples) {
                renderable.Render(context: context)
            }
        }
        return renderables.map { ModifiedContent(content: $0, modifier: provider) }
    }
    #else
    public var body: some View {
        stubView()
    }
    #endif
}
#endif
