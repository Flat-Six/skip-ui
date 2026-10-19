// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.drawscope.Stroke

/// A border as SwiftUI draws one (Flat-Six patch): a stroke of exactly its width, inside the bounds, over the content,
/// antialiased. Compose's border rounds its width up to whole pixels — a 0.5-point cell border drew 2 px at 2.81 px a
/// point, two cells' side by side a solid 4 px line where iOS's are 3 px with soft edges.
fun Modifier.swiftUIBorder(widthPx: Float, brush: Brush): Modifier = drawWithContent {
    drawContent()
    val inset = widthPx / 2f
    drawRect(brush = brush, topLeft = Offset(inset, inset), size = Size(size.width - widthPx, size.height - widthPx), style = Stroke(width = widthPx))
}
