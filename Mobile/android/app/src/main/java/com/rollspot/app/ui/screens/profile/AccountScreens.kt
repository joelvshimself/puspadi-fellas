package com.rollspot.app.ui.screens.profile

import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import android.app.LocaleManager
import android.os.Build
import android.os.LocaleList
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Notifications
import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rollspot.shared.auth.AuthRules
import app.rollspot.shared.auth.AuthSession
import app.rollspot.shared.auth.MobilityRole
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.theme.BackCircleButton
import com.rollspot.app.ui.theme.ConfirmButtons
import com.rollspot.app.ui.theme.ContinueButton
import com.rollspot.app.ui.theme.FieldBox
import com.rollspot.app.ui.theme.GlassSheet
import com.rollspot.app.ui.theme.LocalHazeState
import com.rollspot.app.ui.theme.Rollspot
import com.rollspot.app.ui.theme.SheetHeader
import com.rollspot.app.ui.theme.pressScale
import dev.chrisbanes.haze.HazeState
import dev.chrisbanes.haze.hazeSource
import kotlinx.coroutines.launch
import java.util.Locale

// ---------------------------------------------------------------------------------------------
// Settings tab (iOS ProfileSettingsView)
// ---------------------------------------------------------------------------------------------

@Composable
internal fun SettingsTab(onOpenMyAccount: () -> Unit, onOpenLanguage: () -> Unit, onOpenAbout: () -> Unit, onSignOut: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 28.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            SettingsCard { SettingsRow(Icons.Default.Person, "My Account", onClick = onOpenMyAccount) }
            SettingsCard {
                // Per-app language needs Android 13; older phones follow the system language.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    SettingsRow(Icons.Default.Language, "Language", value = currentLanguage().label, onClick = onOpenLanguage)
                    HorizontalDivider(Modifier.padding(start = 52.dp), color = Color(0x1F3C3C43))
                }
                NotificationsRow()
                HorizontalDivider(Modifier.padding(start = 52.dp), color = Color(0x1F3C3C43))
                SettingsRow(Icons.Default.Info, "About App", onClick = onOpenAbout)
            }
        }
        val interaction = remember { MutableInteractionSource() }
        Box(
            Modifier.padding(horizontal = 20.dp).padding(bottom = 12.dp).navigationBarsPadding().fillMaxWidth().height(52.dp)
                .pressScale(interaction).clip(RoundedCornerShape(16.dp)).background(Color.White)
                .clickable(interactionSource = interaction, indication = null, onClick = onSignOut),
            contentAlignment = Alignment.Center,
        ) { Text("Sign Out", style = Rollspot.Body.copy(fontWeight = FontWeight.Bold), color = Rollspot.Danger) }
    }
}

/** Whether Android lets Rollspot notify; tapping opens the app's system notification settings. */
@Composable
private fun NotificationsRow() {
    val context = LocalContext.current
    var enabled by remember { mutableStateOf(NotificationManagerCompat.from(context).areNotificationsEnabled()) }
    // Re-read when the user comes back from system settings.
    LifecycleResumeEffect(Unit) {
        enabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        onPauseOrDispose {}
    }
    SettingsRow(Icons.Default.Notifications, "Notifications", value = if (enabled) "On" else "Off") {
        context.startActivity(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
        )
    }
}

@Composable
private fun SettingsCard(content: @Composable ColumnScope.() -> Unit) {
    val shape = RoundedCornerShape(20.dp)
    Column(Modifier.fillMaxWidth().shadow(8.dp, shape, ambientColor = Color(0x0D000000), spotColor = Color(0x0D000000)).clip(shape).background(Color.White), content = content)
}

@Composable
private fun SettingsRow(icon: ImageVector, title: String, value: String? = null, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, Modifier.size(22.dp), tint = Rollspot.BrandBlue)
        Spacer(Modifier.width(14.dp))
        Text(title, Modifier.weight(1f), style = Rollspot.Body, color = Color.Black)
        value?.let { Text(it, style = Rollspot.Subheadline, color = Rollspot.Secondary) }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, Modifier.size(20.dp), tint = Rollspot.Tertiary)
    }
}

// ---------------------------------------------------------------------------------------------
// Language (per-app locale, Android 13+)
// ---------------------------------------------------------------------------------------------

private enum class AppLanguage(val tag: String, val label: String) { English("en", "English"), Indonesia("in", "Indonesia") }

private fun currentLanguage(): AppLanguage =
    if (Locale.getDefault().language in setOf("in", "id")) AppLanguage.Indonesia else AppLanguage.English

@Composable
internal fun LanguageSheet(visible: Boolean, onDismiss: () -> Unit) {
    val context = LocalContext.current
    GlassSheet(visible, onDismiss) {
        SheetHeader("Language")
        Spacer(Modifier.height(16.dp))
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            AppLanguage.entries.forEach { language ->
                OptionRow(selected = language == currentLanguage(), onClick = {
                    onDismiss()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && language != currentLanguage()) {
                        context.getSystemService(LocaleManager::class.java).applicationLocales = LocaleList.forLanguageTags(language.tag)
                    }
                }) { selected ->
                    Text(language.label, style = Rollspot.Body.copy(fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal), color = if (selected) Rollspot.BrandBlue else Color.Black)
                }
            }
        }
    }
}

/** Bordered choice row: blue ring, light-blue fill and a filled check when selected (iOS sheets). */
@Composable
private fun OptionRow(selected: Boolean, enabled: Boolean = true, onClick: () -> Unit, content: @Composable RowScope.(Boolean) -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    val interaction = remember { MutableInteractionSource() }
    Row(
        Modifier.fillMaxWidth().pressScale(interaction).clip(shape)
            .background(if (selected) Rollspot.BrandBlue.copy(alpha = 0.08f) else Color.White)
            .border(if (selected) 1.5.dp else 1.dp, if (selected) Rollspot.BrandBlue else Color(0x33808080), shape)
            .clickable(interactionSource = interaction, indication = null, enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(Modifier.weight(1f)) { content(selected) }
        if (selected) Icon(Icons.Default.CheckCircle, null, Modifier.size(20.dp), tint = Rollspot.BrandBlue)
        else Icon(Icons.Outlined.Circle, null, Modifier.size(20.dp), tint = Color(0x8C8E8E93))
    }
}

// ---------------------------------------------------------------------------------------------
// My Account (iOS MyAccountView)
// ---------------------------------------------------------------------------------------------

@Composable
fun MyAccountScreen(onBack: () -> Unit, onAccountDeleted: () -> Unit, review: String? = null) {
    val sdk = rollspotSdk()
    val profile by sdk.profile.state.collectAsStateWithLifecycle()
    val session by sdk.auth.session.collectAsStateWithLifecycle()
    val signedIn = session as? AuthSession.SignedIn
    val scope = rememberCoroutineScope()
    val haze = remember { HazeState() }
    var mobilitySheet by remember { mutableStateOf(review == "mobilityProfile") }
    var passwordSheet by remember { mutableStateOf(false) }
    var deleteSheet by remember { mutableStateOf(review == "deleteAccount") }
    var deleted by remember { mutableStateOf(review == "accountDeleted") }
    var deleting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    // Kept after deletion signs the session out, for the "deleted" screen.
    val email = remember(signedIn) { signedIn?.user?.email }

    LaunchedEffect(Unit) { runCatching { sdk.profile.load() } }

    CompositionLocalProvider(LocalHazeState provides haze) {
        Box(Modifier.fillMaxSize().background(Color.White)) {
            Column(
                Modifier.fillMaxSize().hazeSource(haze)
                    .background(Brush.verticalGradient(0f to Rollspot.GradientTop.copy(alpha = 0.55f), 0.4f to Color.White))
                    .statusBarsPadding(),
            ) {
                Box(Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) { BackCircleButton(onBack, size = 44.dp) }
                Text("My Account", Modifier.padding(start = 16.dp, top = 8.dp, bottom = 12.dp), fontSize = 34.sp, fontWeight = FontWeight.Bold, color = Color.Black)
                Column(
                    Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(22.dp),
                ) {
                    AccountField("Email") { Text(email ?: "—", style = Rollspot.Body, color = Rollspot.Secondary) }
                    if (signedIn?.canChangePassword == true) {
                        AccountField("Password") {
                            Text("••••••••", Modifier.weight(1f), style = Rollspot.Body, color = Rollspot.Secondary)
                            val interaction = remember { MutableInteractionSource() }
                            Text(
                                "Change",
                                Modifier.pressScale(interaction).clip(CircleShape).background(Color.White)
                                    .clickable(interactionSource = interaction, indication = null) { passwordSheet = true }
                                    .padding(horizontal = 12.dp, vertical = 6.dp),
                                style = Rollspot.Caption.copy(fontWeight = FontWeight.Bold), color = Rollspot.BrandBlue,
                            )
                        }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        AccountField("Mobility Profile", onClick = { mobilitySheet = true }) {
                            val role = profile.mobilityRole
                            Text(role?.label ?: "Not set", Modifier.weight(1f), style = Rollspot.Body, color = if (role == null) Rollspot.Tertiary else Rollspot.Secondary)
                            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, Modifier.size(20.dp), tint = Rollspot.Tertiary)
                        }
                        error?.let { Text(it, style = Rollspot.Caption, color = Rollspot.ErrorRed) }
                    }
                }
                val interaction = remember { MutableInteractionSource() }
                Box(
                    Modifier.padding(horizontal = 24.dp).padding(bottom = 12.dp).navigationBarsPadding().fillMaxWidth().height(52.dp)
                        .pressScale(interaction).clip(RoundedCornerShape(16.dp)).background(Rollspot.DangerFill)
                        .clickable(interactionSource = interaction, indication = null) { deleteSheet = true },
                    contentAlignment = Alignment.Center,
                ) { Text("Delete Account", style = Rollspot.Body.copy(fontWeight = FontWeight.Bold), color = Rollspot.Danger) }
            }

            GlassSheet(mobilitySheet, onDismiss = { mobilitySheet = false }) {
                MobilityProfileSheetContent(selected = profile.mobilityRole, saving = profile.isSaving) { role ->
                    scope.launch {
                        runCatching { sdk.profile.updateMobilityRole(role) }
                            .onSuccess { mobilitySheet = false; error = null }
                            .onFailure { error = it.message }
                    }
                }
            }
            GlassSheet(passwordSheet, onDismiss = { passwordSheet = false }) {
                ChangePasswordSheetContent(onDone = { passwordSheet = false })
            }
            GlassSheet(deleteSheet, onDismiss = { if (!deleting) deleteSheet = false }) {
                SheetHeader("Delete Account?", "Deleting your account will permanently remove it along with all your reviews. This action is irreversible.")
                ConfirmButtons("Delete", busy = deleting, onCancel = { deleteSheet = false }, onConfirm = {
                    deleting = true
                    scope.launch {
                        // Really deletes the account, reviews and photos on the server (shared AuthModel).
                        runCatching { sdk.auth.deleteAccount() }
                            .onSuccess { deleteSheet = false; deleted = true }
                            .onFailure { deleteSheet = false; error = it.message }
                        deleting = false
                    }
                })
            }
            AnimatedVisibility(deleted, enter = fadeIn(tween(250)), exit = fadeOut(tween(200))) {
                AccountDeletedScreen(onDone = {
                    scope.launch { runCatching { sdk.auth.signOut() }; onAccountDeleted() }
                })
            }
        }
    }
}

@Composable
private fun AccountField(label: String, onClick: (() -> Unit)? = null, content: @Composable RowScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = Rollspot.Subheadline.copy(fontWeight = FontWeight.Medium), color = Rollspot.Secondary)
        Row(
            Modifier.fillMaxWidth().height(54.dp).clip(RoundedCornerShape(16.dp)).background(Rollspot.FieldFill)
                .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
                .padding(start = 16.dp, end = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            content = content,
        )
    }
}

@Composable
private fun MobilityProfileSheetContent(selected: MobilityRole?, saving: Boolean, onSelect: (MobilityRole) -> Unit) {
    var draft by remember { mutableStateOf(selected) }
    SheetHeader("Mobility Profile")
    Spacer(Modifier.height(12.dp))
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        MobilityRole.entries.forEach { role ->
            OptionRow(selected = (draft ?: selected) == role, enabled = !saving, onClick = { draft = role; onSelect(role) }) { isSelected ->
                Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(role.label, style = Rollspot.Subheadline.copy(fontWeight = FontWeight.SemiBold), color = if (isSelected) Rollspot.BrandBlue else Color.Black)
                    val detail = when (role) {
                        MobilityRole.WHEELCHAIR_USER -> "Firsthand experience using a wheelchair"
                        MobilityRole.COMMUNITY_CONTRIBUTOR -> "• User with other mobility aid\n• User with no mobility aid"
                    }
                    Text(detail, fontSize = 13.sp, lineHeight = 17.sp, color = if (isSelected && role == MobilityRole.WHEELCHAIR_USER) Rollspot.BrandBlue.copy(alpha = 0.85f) else Rollspot.Secondary)
                }
            }
        }
    }
}

@Composable
private fun ChangePasswordSheetContent(onDone: () -> Unit) {
    val auth = rollspotSdk().auth
    val scope = rememberCoroutineScope()
    var current by remember { mutableStateOf("") }
    var new by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val canSave = current.isNotEmpty() && AuthRules.isValidPassword(new) && new == confirm

    SheetHeader("Change Password")
    Spacer(Modifier.height(16.dp))
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        PasswordField("Current Password", current) { current = it }
        PasswordField("New Password", new) { new = it }
        Text(AuthRules.PASSWORD_HINT, style = Rollspot.Caption, color = if (new.isEmpty() || AuthRules.isValidPassword(new)) Rollspot.Secondary else Rollspot.ErrorRed)
        PasswordField("Confirm Password", confirm) { confirm = it }
        error?.let { Text(it, style = Rollspot.Caption, color = Rollspot.ErrorRed) }
        ContinueButton("Save", enabled = canSave, loading = saving) {
            saving = true
            scope.launch {
                runCatching { auth.changePassword(current, new) }
                    .onSuccess { onDone() }
                    .onFailure { error = it.message }
                saving = false
            }
        }
    }
}

@Composable
private fun PasswordField(placeholder: String, value: String, onChange: (String) -> Unit) {
    FieldBox(focused = false, error = false) {
        Box(Modifier.weight(1f)) {
            if (value.isEmpty()) Text(placeholder, style = Rollspot.Body, color = Rollspot.Tertiary)
            BasicTextField(value, onChange, singleLine = true, textStyle = Rollspot.Body, visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth().semantics { contentDescription = placeholder })
        }
    }
}

/** Shown after the account is gone (iOS accountDeletedView). The feedback box is optional. */
@Composable
private fun AccountDeletedScreen(onDone: () -> Unit) {
    var feedback by remember { mutableStateOf("") }
    Column(
        Modifier.fillMaxSize().background(Color.White).clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
            .statusBarsPadding().navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp), contentAlignment = Alignment.CenterEnd) {
            val interaction = remember { MutableInteractionSource() }
            Box(
                Modifier.size(36.dp).pressScale(interaction).clip(CircleShape).background(Rollspot.FieldFill)
                    .clickable(interactionSource = interaction, indication = null, onClick = onDone),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Default.Close, "Close", Modifier.size(18.dp), tint = Rollspot.Secondary) }
        }
        Spacer(Modifier.weight(1f))
        Icon(Icons.Default.CheckCircle, null, Modifier.size(80.dp), tint = Color(0xFF34C759))
        Spacer(Modifier.height(24.dp))
        Text("Account Deleted", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color.Black)
        Spacer(Modifier.height(8.dp))
        Text(
            "We are sorry to hear you go...\nTell us more about your experience for us to improve",
            Modifier.padding(horizontal = 44.dp), style = Rollspot.Subheadline, color = Rollspot.Secondary, textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(24.dp))
        val shape = RoundedCornerShape(16.dp)
        Box(Modifier.padding(horizontal = 24.dp).fillMaxWidth().heightIn(min = 110.dp).clip(shape).background(Color.White).border(1.dp, Color(0x33808080), shape).padding(14.dp)) {
            if (feedback.isEmpty()) Text("Your feedbacks here (Optional)", style = Rollspot.Body, color = Rollspot.Tertiary)
            BasicTextField(feedback, { feedback = it }, textStyle = Rollspot.Body, modifier = Modifier.fillMaxWidth().semantics { contentDescription = "Your feedbacks here (Optional)" })
        }
        Spacer(Modifier.weight(1f))
        ContinueButton("Back to Home", Modifier.padding(horizontal = 24.dp).padding(bottom = 32.dp), onClick = onDone)
    }
}
