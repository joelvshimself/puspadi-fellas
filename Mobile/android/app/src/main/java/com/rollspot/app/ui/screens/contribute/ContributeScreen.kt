package com.rollspot.app.ui.screens.contribute

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.rollspot.app.R
import com.rollspot.app.ui.screens.contribute.components.ContributeContinueButton
import com.rollspot.app.ui.screens.contribute.components.ContributeFlowHeader

/**
 * Contribute screen for adding accessibility reviews.
 * Landing tab; the review wizard starts after place search.
 */
@Composable
fun ContributeScreen(
    onNavigateBack: () -> Unit,
    onStartReview: () -> Unit,
) {
    Column(Modifier.fillMaxSize()) {
        ContributeFlowHeader(title = "Contribute", onBack = onNavigateBack)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Image(
                painter = painterResource(R.drawable.contribute_onboarding),
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 200.dp),
                contentScale = ContentScale.Fit,
            )
            Spacer(Modifier.height(24.dp))
            Text(
                text = "Help make places more accessible",
                style = MaterialTheme.typography.headlineSmall,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Share your experience and photos so others know what to expect.",
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        ContributeContinueButton(
            title = "Add Accessibility Review",
            enabled = true,
            onClick = onStartReview,
            modifier = Modifier.padding(bottom = 8.dp),
        )
    }
}
