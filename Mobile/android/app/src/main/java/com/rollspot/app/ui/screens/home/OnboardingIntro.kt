package com.rollspot.app.ui.screens.home

import android.content.Context
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rollspot.app.R
import com.rollspot.app.ui.theme.ContributeColors
import com.rollspot.app.ui.theme.glass
import com.rollspot.app.ui.theme.pressScale

/** Whether the one-time home intro was dismissed (iOS: @AppStorage "hasSeenOnboardingIntro"). */
object OnboardingIntroPrefs {
    private const val FILE = "rollspot_ui"
    private const val KEY = "hasSeenOnboardingIntro"
    fun hasSeen(context: Context) = context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getBoolean(KEY, false)
    fun markSeen(context: Context) = context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putBoolean(KEY, true).apply()
}

private data class IntroPage(val image: Int, val framed: Boolean, val title: String, val body: String)

private val pages = listOf(
    IntroPage(
        R.drawable.onboarding_map, true, "Know before you go",
        "Find malls you can roll into and see real facilities, checked and confirmed by people who've actually been there.",
    ),
    IntroPage(
        R.drawable.onboarding_contribute, false, "Your visit might be their answer",
        "A photo, a few tags, and a quick note. That's all it takes to help the next person roll everywhere with ease.",
    ),
)

/**
 * The one-time intro over the home map (iOS OnboardingIntroSheet, Figma node 697:10383): a glass
 * sheet at 81% of the screen with two swipeable pages, page dots and "Explore Malls".
 */
@Composable
fun OnboardingIntroSheet(visible: Boolean, onExplore: () -> Unit) {
    val height = LocalConfiguration.current.screenHeightDp.dp * 0.81f
    Box(Modifier.fillMaxSize()) {
        AnimatedVisibility(visible, enter = fadeIn(tween(250)), exit = fadeOut(tween(200))) {
            // Not dismissible by tapping outside, like iOS (interactiveDismissDisabled).
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.12f)).clickable(remember { MutableInteractionSource() }, null) {})
        }
        AnimatedVisibility(
            visible,
            Modifier.align(Alignment.BottomCenter),
            enter = slideInVertically(spring(dampingRatio = 0.8f, stiffness = 440f)) { it },
            exit = slideOutVertically(tween(220)) { it },
        ) {
            val shape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp, bottomStart = 44.dp, bottomEnd = 44.dp)
            val pager = rememberPagerState { pages.size }
            Column(
                Modifier
                    .navigationBarsPadding()
                    .padding(8.dp)
                    .fillMaxWidth()
                    .height(height)
                    .shadow(24.dp, shape, ambientColor = Color(0x33000000))
                    .glass(shape, tint = 0.8f, blur = 30.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                HorizontalPager(pager, Modifier.weight(1f)) { index ->
                    val page = pages[index]
                    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
                        val imageShape = RoundedCornerShape(16.dp)
                        Image(
                            painterResource(page.image), null,
                            Modifier.padding(start = 20.dp, end = 20.dp, top = 20.dp).fillMaxWidth().aspectRatio(1f)
                                .clip(imageShape)
                                .then(if (page.framed) Modifier.border(1.5.dp, Color(0xFF3B3B3B), imageShape) else Modifier),
                            contentScale = ContentScale.Crop,
                        )
                        Spacer(Modifier.weight(1f).heightIn(min = 20.dp))
                        Text(page.title, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color(0xFF2D2D2D), letterSpacing = (-0.26).sp)
                        Text(
                            page.body,
                            Modifier.padding(start = 22.dp, end = 22.dp, top = 10.dp),
                            fontSize = 17.sp, lineHeight = 22.sp, color = Color(0xFF5F5F5F), textAlign = TextAlign.Center,
                        )
                    }
                }
                Row(Modifier.padding(top = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    repeat(pages.size) { index ->
                        val dot by animateColorAsState(if (pager.currentPage == index) Color(0xFF1C1C1E) else Color(0x598E8E93), tween(200), label = "dot")
                        Box(Modifier.size(7.dp).background(dot, CircleShape))
                    }
                }
                val interaction = remember { MutableInteractionSource() }
                Box(
                    Modifier.padding(top = 20.dp, bottom = 32.dp).size(244.dp, 50.dp).pressScale(interaction).clip(CircleShape)
                        .background(ContributeColors.Blue).clickable(interaction, null, onClick = onExplore),
                    contentAlignment = Alignment.Center,
                ) { Text("Explore Malls", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Color.White, letterSpacing = (-0.43).sp) }
            }
        }
    }
}
