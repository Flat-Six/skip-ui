// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if SKIP
import android.content.Context
import android.content.ContextWrapper
import androidx.activity.ComponentActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection

/// The root of a presentation, such as the root presentation or a sheet.
@Composable public func PresentationRoot(defaultColorScheme: ColorScheme? = nil, backgroundColor: Color? = nil, absoluteSystemBarEdges systemBarEdges: Edge.Set = .all, context: ComposeContext, content: @Composable (ComposeContext) -> Void) {
    launchUIApplicationActivity()

    let preferredColorScheme = rememberSaveable(stateSaver: context.stateSaver as! Saver<Preference<PreferredColorScheme>, Any>) { mutableStateOf(Preference<PreferredColorScheme>(key: PreferredColorSchemePreferenceKey.self)) }
    let preferredColorSchemeCollector = PreferenceCollector<PreferredColorScheme>(key: PreferredColorSchemePreferenceKey.self, state: preferredColorScheme)
    PreferenceValues.shared.collectPreferences([preferredColorSchemeCollector]) {
        let materialColorScheme = preferredColorScheme.value.reduced.colorScheme?.asMaterialTheme() ?? defaultColorScheme?.asMaterialTheme() ?? MaterialTheme.colorScheme
        MaterialTheme(colorScheme: materialColorScheme) {
            let presentationBounds = remember { mutableStateOf(Rect.Zero) }
            let density = LocalDensity.current
            let layoutDirection = LocalLayoutDirection.current
            // The side insets — a camera's cutout, a navigation bar on its side — are the safe area's, as the top and bottom
            // are, not padding: iOS runs a page's grounds and bars to the screen's edge under a phone's notch and keeps their
            // content clear of it. Skip padded the whole presentation in from them and painted the padding black, a black
            // strip down the cutout's side of every page in landscape (Flat-Six patch).
            // The ground behind the keyboard the page's, not black: Gboard leaves a cutout's side bare, a black strip beside
            // it in landscape where iOS's keyboard spans the screen (Flat-Six patch)
            // The keyboard's inset, read in this composition (Flat-Six patch): the root's padding and the safe area's keyboard
            // both from it, so the two move in one frame, and a reader's size and insets with them (SafeArea.keyboardPx,
            // GeometryReaderState) — imePadding() read the inset as the layout ran, a frame ahead of the safe area made in
            // composition: an opened Fold8 on its side added up a window 281 tall the frame its keyboard came in, under 600,
            // so no longer tablet-like, its form made anew and its field's focus lost, the keyboard gone again
            let keyboardPx = systemBarEdges.contains(.bottom) ? WindowInsets.ime.getBottom(density) : 0
            var rootModifier = Modifier
                .background(backgroundColor != nil ? androidx.compose.ui.graphics.Color.Transparent : Color.background.colorImpl())
                .fillMaxSize()
            if systemBarEdges.contains(.bottom) {
                rootModifier = rootModifier.padding(bottom: with(density) { keyboardPx.toDp() })
            }
            // Resolve adaptive colors under this presentation's preferred color scheme.
            rootModifier = rootModifier.background((backgroundColor ?? Color.background).colorImpl())
                .onGloballyPositionedInWindow {
                    presentationBounds.value = $0
                }
            Box(modifier: rootModifier) {
                guard presentationBounds.value != Rect.Zero else {
                    return
                }
                // Cannot get accurate WindowInsets until we're in the content box
                var (safeLeft, safeTop, safeRight, safeBottom) = presentationBounds.value
                if systemBarEdges.contains(.top) {
                    safeTop += WindowInsets.safeDrawing.getTop(density)
                }
                if systemBarEdges.contains(.bottom) {
                    safeBottom -= max(0, WindowInsets.safeDrawing.getBottom(density) - keyboardPx)
                }
                let isRTL = layoutDirection == androidx.compose.ui.unit.LayoutDirection.Rtl
                if systemBarEdges.contains(isRTL ? Edge.Set.trailing : Edge.Set.leading) {
                    safeLeft += WindowInsets.safeDrawing.getLeft(density, layoutDirection)
                }
                if systemBarEdges.contains(isRTL ? Edge.Set.leading : Edge.Set.trailing) {
                    safeRight -= WindowInsets.safeDrawing.getRight(density, layoutDirection)
                }
                let safeBounds = Rect(left: safeLeft, top: safeTop, right: safeRight, bottom: safeBottom)
                // How far the keyboard reaches below the presentation (Flat-Six patch): the root's padding, as read above —
                // so the presentation's bounds, a layout behind as the keyboard moves, cancel from what a reader is told
                let safeArea = SafeArea(presentation: presentationBounds.value, safe: safeBounds, absoluteSystemBars: systemBarEdges, keyboard: Float(keyboardPx))
                EnvironmentValues.shared.setValues {
                    // Detect whether the app is edge to edge mode based on whether it has a safe area at any edge
                    if $0._isEdgeToEdge == nil {
                        $0.set_isEdgeToEdge(safeBounds != presentationBounds.value)
                    }
                    $0.set_safeArea(safeArea)
                    // A presentation is a new layout root: scroll axes inherited from the presenting
                    // context (e.g. a sheet presented from a button inside a ScrollView) must not
                    // leak in. Otherwise expanding content in the presentation is sized with
                    // IntrinsicSize as if it were in the presenter's scroll direction, which crashes
                    // when that content contains a lazy container: intrinsic measurement of
                    // SubcomposeLayout-based components is unsupported in Compose
                    $0.set_layoutScrollAxes(Axis.Set(rawValue: 0))
                    $0.set_scrollAxes(Axis.Set(rawValue: 0))
                    return ComposeResult.ok
                } in: {
                    Box(modifier: Modifier.fillMaxSize().padding(safeArea), contentAlignment = androidx.compose.ui.Alignment.Center) {
                        content(context)
                    }
                }
            }
        }
    }
}

@Composable func launchUIApplicationActivity() {
    // Modern Skip projects will set the launch activity in Main.kt. This function exists for older projects
    var context: Context? = LocalContext.current
    var activity: ComponentActivity? = nil
    while context != nil {
        if let a = context as? ComponentActivity {
            activity = a
            break
        } else if let w = context as? ContextWrapper {
            context = w.baseContext
        } else {
            break
        }
    }
    if let activity {
        UIApplication.launch(activity)
    }
}

#endif
