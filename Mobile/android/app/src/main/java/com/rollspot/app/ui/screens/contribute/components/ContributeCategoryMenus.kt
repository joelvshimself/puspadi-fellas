package com.rollspot.app.ui.screens.contribute.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.rollspot.shared.reviews.CategorySectionStatus
import app.rollspot.shared.reviews.ContributeCategoryLabels
import app.rollspot.shared.reviews.ContributeReviewCategory
import com.rollspot.app.ui.screens.contribute.categoryMenuIcon
import com.rollspot.app.ui.theme.RollspotBlue

@Composable
fun ContributeCategoryPickProgress() {
    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp)
            .height(4.dp)
            .clip(RoundedCornerShape(2.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Box(
            Modifier
                .fillMaxWidth(0.12f)
                .fillMaxHeight()
                .background(RollspotBlue),
        )
    }
}

@Composable
fun ContributeCategoryMenusGrid(
    status: Map<ContributeReviewCategory, CategorySectionStatus>,
    onOpen: (ContributeReviewCategory) -> Unit,
    modifier: Modifier = Modifier,
) {
    val categories = ContributeReviewCategory.menuOrder
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        for (row in categories.chunked(2)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { category ->
                    ContributeCategoryCard(
                        category = category,
                        status = status[category],
                        onClick = { onOpen(category) },
                        modifier = Modifier.weight(1f),
                    )
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
    val shape = RoundedCornerShape(16.dp)
    val complete = status == CategorySectionStatus.Complete
    val bg = if (complete) RollspotBlue.copy(alpha = 0.12f) else MaterialTheme.colorScheme.surfaceVariant
    Box(
        modifier
            .aspectRatio(171f / 116f)
            .clip(shape)
            .background(bg)
            .clickable(onClick = onClick)
            .padding(horizontal = 8.dp, vertical = 8.dp),
    ) {
        when (status) {
            CategorySectionStatus.Complete -> {
                Box(
                    Modifier
                        .align(Alignment.TopEnd)
                        .size(22.dp)
                        .background(RollspotBlue, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Default.Check, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimary, modifier = Modifier.size(14.dp))
                }
            }
            CategorySectionStatus.InProgress -> {
                Canvas(
                    Modifier
                        .align(Alignment.TopEnd)
                        .size(18.dp),
                ) {
                    drawArc(
                        color = RollspotBlue,
                        startAngle = -90f,
                        sweepAngle = 270f,
                        useCenter = false,
                        style = Stroke(width = 2.5.dp.toPx(), cap = StrokeCap.Round),
                    )
                }
            }
            null -> Unit
        }
        Column(
            Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            CategoryMenuIcon(category, Modifier.size(64.dp))
            Spacer(Modifier.height(8.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
            ) {
                Text(
                    ContributeCategoryLabels.menuTitle(category).uppercase(),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                    lineHeight = 16.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}

@Composable
private fun CategoryMenuIcon(category: ContributeReviewCategory, modifier: Modifier = Modifier) {
    Image(
        painter = painterResource(categoryMenuIcon(category)),
        contentDescription = null,
        modifier = modifier,
        contentScale = ContentScale.Fit,
    )
}
