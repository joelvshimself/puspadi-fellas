package com.rollspot.app.ui.screens.contribute.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.rollspot.shared.reviews.CategorySectionStatus
import app.rollspot.shared.reviews.ContributeCategoryLabels
import app.rollspot.shared.reviews.ContributeReviewCategory
import com.rollspot.app.ui.screens.contribute.categoryMenuIcon
import com.rollspot.app.ui.theme.ContributeColors
import com.rollspot.app.ui.theme.pressScale

/**
 * "Contribute Review Category Menus" (Figma): Not filled → Form in progress (autosave) →
 * Completed form. Same measurements as iOS ContributeReviewCategoryMenusView.
 */
@Composable
fun ContributeCategoryMenuScreen(
    status: Map<ContributeReviewCategory, CategorySectionStatus>,
    submitting: Boolean,
    onBack: () -> Unit,
    onOpen: (ContributeReviewCategory) -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val canSubmit = status.values.any { it == CategorySectionStatus.Complete }
    Column(modifier.fillMaxSize().background(Color.White)) {
        // The menu is the first of four sections: a short fill, as in the design.
        ContributeStepProgressBar(currentStep = 1, subStepProgress = 0.35f)
        ContributeFlowHeader(title = "", onBack = onBack)
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(top = 34.dp),
        ) {
            Text("Help make every visit easier", fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = ContributeColors.Text)
            Spacer(Modifier.height(6.dp))
            Text(
                "Fill in at least one facility to help others know what to expect.",
                Modifier.widthIn(max = 232.dp),
                fontSize = 14.sp, lineHeight = 19.sp, color = ContributeColors.SecondaryText,
            )
            Spacer(Modifier.height(34.dp))
            ContributeCategoryMenusGrid(status = status, onOpen = onOpen)
        }
        // "Continue" (disabled) until a section is complete, then "Submit".
        ContributeContinueButton(
            title = if (canSubmit) "Submit" else "Continue",
            enabled = canSubmit,
            loading = submitting,
            onClick = onSubmit,
        )
    }
}

@Composable
fun ContributeCategoryMenusGrid(
    status: Map<ContributeReviewCategory, CategorySectionStatus>,
    onOpen: (ContributeReviewCategory) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        for (row in ContributeReviewCategory.menuOrder.chunked(2)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { category ->
                    ContributeCategoryCard(category, status[category], { onOpen(category) }, Modifier.weight(1f))
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun ContributeCategoryCard(
    category: ContributeReviewCategory,
    status: CategorySectionStatus?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(14.dp)
    val interaction = remember { MutableInteractionSource() }
    val fill by animateColorAsState(
        if (status == CategorySectionStatus.Complete) ContributeColors.CompleteFill else ContributeColors.Fill, tween(200), label = "card",
    )
    val title = ContributeCategoryLabels.menuTitle(category)
    Box(
        modifier
            .height(115.dp)
            .pressScale(interaction)
            .clip(shape)
            .background(fill)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .semantics {
                contentDescription = title + when (status) {
                    CategorySectionStatus.Complete -> ", completed"
                    CategorySectionStatus.InProgress -> ", in progress"
                    null -> ""
                }
            },
    ) {
        Column(
            Modifier.fillMaxSize().padding(horizontal = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Image(painterResource(categoryMenuIcon(category)), null, Modifier.height(30.dp), contentScale = ContentScale.Fit)
            Spacer(Modifier.height(18.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                Text(
                    title.uppercase(),
                    fontSize = 15.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp, lineHeight = 17.sp,
                    color = ContributeColors.Text, textAlign = TextAlign.Center, maxLines = 2,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Spacer(Modifier.width(4.dp))
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, Modifier.size(16.dp), tint = ContributeColors.Chevron)
            }
        }
        AnimatedContent(
            status,
            Modifier.align(Alignment.TopEnd).padding(8.dp),
            transitionSpec = { (scaleIn(initialScale = 0.6f) + fadeIn()) togetherWith fadeOut() },
            label = "badge",
        ) { current ->
            when (current) {
                CategorySectionStatus.Complete -> Box(
                    Modifier.size(19.dp).background(ContributeColors.Blue, CircleShape),
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Default.Check, null, Modifier.size(12.dp), tint = Color.White) }
                // Autosaved, not finished: a partial ring on a faint track.
                CategorySectionStatus.InProgress -> Canvas(Modifier.padding(1.dp).size(17.dp)) {
                    val stroke = 2.5.dp.toPx()
                    drawCircle(ContributeColors.Blue.copy(alpha = 0.15f), style = Stroke(stroke))
                    drawArc(ContributeColors.Blue, -90f, 252f, false, style = Stroke(stroke, cap = StrokeCap.Round))
                }
                null -> Spacer(Modifier.size(19.dp))
            }
        }
    }
}

@Composable
fun ContributeCategoryPickProgress() = ContributeStepProgressBar(currentStep = 1, subStepProgress = 0.35f)
