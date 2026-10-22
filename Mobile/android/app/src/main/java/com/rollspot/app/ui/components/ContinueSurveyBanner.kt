package com.rollspot.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.rollspot.shared.drafts.WaitingContribution
import com.rollspot.app.ui.theme.Rollspot
import com.rollspot.app.ui.theme.pressScale

/**
 * "Your contribution is waiting · <place> · In progress" (Figma Home "Continue Survey", iOS
 * ContinueSurveyBanner). The caller supplies the surface: glass on Home, a white card on Profile.
 */
@Composable
fun ContinueSurveyBanner(contribution: WaitingContribution, onOpen: () -> Unit, modifier: Modifier = Modifier) {
    val interaction = remember { MutableInteractionSource() }
    Row(
        modifier
            .pressScale(interaction)
            .clickable(interactionSource = interaction, indication = null, onClick = onOpen)
            .padding(horizontal = 14.dp, vertical = 12.dp)
            .semantics { contentDescription = "Continue your review of ${contribution.placeName}" },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Blue disc with the design's dotted ring: a survey that's part-way done.
        Canvas(Modifier.size(34.dp)) {
            drawCircle(Rollspot.BrandBlue)
            drawCircle(
                Color.White,
                radius = size.minDimension / 2 - 6.dp.toPx(),
                style = Stroke(2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.5.dp.toPx(), 2.5.dp.toPx()))),
            )
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text("Your contribution is waiting", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.Black, maxLines = 1)
            Text(
                "${contribution.placeName} · In progress", fontSize = 12.sp, color = Rollspot.Secondary,
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, Modifier.size(20.dp), tint = Rollspot.Tertiary)
    }
}
