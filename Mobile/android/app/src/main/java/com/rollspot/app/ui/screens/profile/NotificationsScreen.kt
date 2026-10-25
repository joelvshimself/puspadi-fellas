package com.rollspot.app.ui.screens.profile

import android.content.Intent
import android.provider.Settings
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rollspot.app.R
import com.rollspot.app.notifications.rememberNotificationPermissionRequest
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.theme.BackCircleButton
import com.rollspot.app.ui.theme.Rollspot
import com.rollspot.app.ui.theme.pressScale
import kotlinx.coroutines.launch

/**
 * Notifications (iOS NotificationsSettingsView): three switches saved on the profile by the shared
 * NotificationsModel, and a notice with a way out when the phone blocks Rollspot's notifications.
 */
@Composable
fun NotificationsScreen(onBack: () -> Unit) {
    val sdk = rollspotSdk()
    val notifications = sdk.notifications
    val state by notifications.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val askPermission = rememberNotificationPermissionRequest()

    fun toggle(on: Boolean, save: suspend (Boolean) -> Unit) {
        if (on) askPermission()
        scope.launch { runCatching { save(on) } }
    }

    Column(
        Modifier.fillMaxSize()
            .background(Brush.verticalGradient(0f to Rollspot.GradientTop.copy(alpha = 0.55f), 0.4f to Rollspot.SectionBackground))
            .statusBarsPadding(),
    ) {
        Box(Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) { BackCircleButton(onBack, size = 44.dp) }
        Text(
            stringResource(R.string.notifications_title),
            Modifier.padding(start = 16.dp, top = 8.dp, bottom = 12.dp),
            fontSize = 34.sp, fontWeight = FontWeight.Bold, color = Color.Black,
        )
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 12.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            AnimatedVisibility(
                visible = state.isBlocked,
                enter = fadeIn(tween(200)) + expandVertically(tween(200)),
                exit = fadeOut(tween(150)) + shrinkVertically(tween(150)),
            ) {
                Card {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(stringResource(R.string.notif_blocked), style = Rollspot.Subheadline, color = Color.Black)
                        val interaction = remember { MutableInteractionSource() }
                        Text(
                            stringResource(R.string.notif_open_settings),
                            Modifier.pressScale(interaction).clip(CircleShape).background(Rollspot.BrandBlue)
                                .clickable(interactionSource = interaction, indication = null) {
                                    context.startActivity(
                                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
                                    )
                                }
                                .padding(horizontal = 16.dp, vertical = 8.dp),
                            style = Rollspot.Subheadline.copy(fontWeight = FontWeight.SemiBold), color = Color.White,
                        )
                    }
                }
            }
            Card {
                SwitchRow(
                    stringResource(R.string.notif_saved_title), stringResource(R.string.notif_saved_subtitle),
                    state.settings.savedPlaceReviews,
                ) { toggle(it, notifications::setSavedPlaceReviews) }
                Divider()
                SwitchRow(
                    stringResource(R.string.notif_reminders_title), stringResource(R.string.notif_reminders_subtitle),
                    state.settings.reviewReminders,
                ) { toggle(it, notifications::setReviewReminders) }
                Divider()
                SwitchRow(
                    stringResource(R.string.notif_news_title), stringResource(R.string.notif_news_subtitle),
                    state.settings.announcements,
                ) { toggle(it, notifications::setAnnouncements) }
            }
            state.error?.let { Text(it, Modifier.padding(horizontal = 4.dp), style = Rollspot.Caption, color = Rollspot.ErrorRed) }
        }
    }
}

@Composable
private fun Card(content: @Composable ColumnScope.() -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    Column(
        Modifier.fillMaxWidth().shadow(8.dp, shape, ambientColor = Color(0x0D000000), spotColor = Color(0x0D000000))
            .clip(shape).background(Color.White),
        content = content,
    )
}

@Composable
private fun Divider() = HorizontalDivider(Modifier.padding(start = 16.dp), color = Color(0x1F3C3C43))

@Composable
private fun SwitchRow(title: String, subtitle: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable { onChange(!checked) }.padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = Rollspot.Body, color = Color.Black)
            Text(subtitle, style = Rollspot.Caption.copy(fontSize = 13.sp), color = Rollspot.Secondary)
        }
        Spacer(Modifier.width(12.dp))
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedTrackColor = Rollspot.BrandBlue,
                checkedThumbColor = Color.White,
                checkedBorderColor = Rollspot.BrandBlue,
            ),
        )
    }
}
