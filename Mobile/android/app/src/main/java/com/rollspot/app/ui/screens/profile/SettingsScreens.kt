package com.rollspot.app.ui.screens.profile

import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rollspot.shared.auth.AuthRules
import app.rollspot.shared.auth.AuthSession
import app.rollspot.shared.auth.MobilityRole
import app.rollspot.shared.places.PlaceRepository
import com.rollspot.app.BuildConfig
import com.rollspot.app.ui.rollspotSdk
import kotlinx.coroutines.launch

private val Danger = Color(0xFFDB2E2E)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Screen(title: String, onBack: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
            )
        },
    ) { padding -> Column(Modifier.fillMaxSize().padding(padding), content = content) }
}

@Composable
private fun SettingsRow(title: String, value: String? = null, color: Color = Color.Unspecified, onClick: () -> Unit) {
    ListItem(
        headlineContent = { Text(title, color = color) },
        trailingContent = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                value?.let { Text(it, color = Color.Gray) }
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Color.Gray)
            }
        },
        modifier = Modifier.clickable(onClick = onClick),
    )
}

/** Settings (iOS ProfileSettingsView): My Account, Saved places, About App, Sign Out. */
@Composable
fun ProfileSettingsScreen(onBack: () -> Unit, onNavigate: (String) -> Unit, onSignedOut: () -> Unit) {
    val auth = rollspotSdk().auth
    val scope = rememberCoroutineScope()
    Screen("Settings", onBack) {
        SettingsRow("My Account") { onNavigate("my-account") }
        SettingsRow("Saved places") { onNavigate("saved") }
        SettingsRow("About App") { onNavigate("about") }
        HorizontalDivider()
        ListItem(
            headlineContent = { Text("Sign Out", color = Danger) },
            modifier = Modifier.clickable { scope.launch { runCatching { auth.signOut() }; onSignedOut() } },
        )
    }
}

/** My Account (iOS MyAccountView): name, mobility profile, password, delete account. */
@Composable
fun MyAccountScreen(onBack: () -> Unit, onAccountDeleted: () -> Unit) {
    val sdk = rollspotSdk()
    val profile by sdk.profile.state.collectAsStateWithLifecycle()
    val session by sdk.auth.session.collectAsStateWithLifecycle()
    val signedIn = session as? AuthSession.SignedIn
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var name by rememberSaveable(profile.profile?.displayName) { mutableStateOf(profile.profile?.displayName.orEmpty()) }
    var showPassword by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { runCatching { sdk.profile.load() } }
    fun report(result: Result<*>, success: String) {
        Toast.makeText(context, result.exceptionOrNull()?.message ?: success, Toast.LENGTH_SHORT).show()
    }

    Screen("My Account", onBack) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("Email", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            Text(signedIn?.user?.email.orEmpty())

            OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            Button(
                onClick = { scope.launch { report(runCatching { sdk.profile.updateDisplayName(name) }, "Name saved") } },
                enabled = !profile.isSaving && name.trim() != profile.profile?.displayName.orEmpty(),
            ) { Text("Save name") }

            Text("Mobility Profile", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            MobilityRole.entries.forEach { role ->
                Row(
                    Modifier.fillMaxWidth().selectable(selected = profile.mobilityRole == role, enabled = !profile.isSaving) {
                        scope.launch { report(runCatching { sdk.profile.updateMobilityRole(role) }, "Mobility profile saved") }
                    },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(selected = profile.mobilityRole == role, onClick = null)
                    Spacer(Modifier.width(8.dp))
                    Text(role.label)
                }
            }

            if (signedIn?.canChangePassword == true) {
                OutlinedButton(onClick = { showPassword = true }) { Text("Change password") }
            }
            Spacer(Modifier.height(24.dp))
            TextButton(onClick = { confirmDelete = true }, enabled = !deleting) { Text("Delete Account", color = Danger) }
        }
    }

    if (showPassword) ChangePasswordDialog(onDismiss = { showPassword = false }) { current, new ->
        scope.launch {
            val result = runCatching { sdk.auth.changePassword(current, new) }
            report(result, "Password changed")
            if (result.isSuccess) showPassword = false
        }
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete Account?") },
            text = { Text("Deleting your account will permanently remove it along with all your reviews. This action is irreversible.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    deleting = true
                    scope.launch {
                        val result = runCatching { sdk.auth.deleteAccount() }
                        deleting = false
                        if (result.isSuccess) {
                            Toast.makeText(context, "Account deleted", Toast.LENGTH_SHORT).show()
                            onAccountDeleted()
                        } else {
                            report(result, "")
                        }
                    }
                }) { Text("Delete", color = Danger) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun ChangePasswordDialog(onDismiss: () -> Unit, onSubmit: (String, String) -> Unit) {
    var current by remember { mutableStateOf("") }
    var new by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Change password") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(current, { current = it }, label = { Text("Current password") }, singleLine = true,
                    visualTransformation = PasswordVisualTransformation(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password))
                OutlinedTextField(new, { new = it }, label = { Text("New password") }, singleLine = true,
                    visualTransformation = PasswordVisualTransformation(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password))
                Text(AuthRules.PASSWORD_HINT, style = MaterialTheme.typography.bodySmall,
                    color = if (new.isEmpty() || AuthRules.isValidPassword(new)) Color.Gray else Danger)
            }
        },
        confirmButton = {
            TextButton(onClick = { onSubmit(current, new) }, enabled = current.isNotEmpty() && AuthRules.isValidPassword(new)) { Text("Change") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

/** Saved places, A–Z (shared SavedPlacesModel). */
@Composable
fun SavedPlacesScreen(onBack: () -> Unit, onOpenPlace: (String) -> Unit) {
    val saved = rollspotSdk().saved
    val state by saved.state.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { runCatching { saved.load() } }
    Screen("Saved", onBack) {
        when {
            state.isLoading && state.places.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            state.places.isEmpty() -> Column(Modifier.fillMaxSize().padding(32.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                Text("No Saved Places", style = MaterialTheme.typography.titleMedium)
                Text("Bookmark places to easily view them here.", color = Color.Gray)
            }
            else -> LazyColumn {
                items(state.places, key = { it.id }) { place ->
                    ListItem(
                        headlineContent = { Text(place.name, fontWeight = FontWeight.SemiBold) },
                        supportingContent = { Text(place.address ?: place.category.orEmpty()) },
                        modifier = Modifier.clickable { onOpenPlace(place.id) },
                    )
                }
            }
        }
    }
}

@Composable
fun AboutScreen(onBack: () -> Unit) {
    Screen("About App", onBack) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Rollspot", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Text("Version ${BuildConfig.VERSION_NAME}", color = Color.Gray)
            Text("Find out how accessible places are for wheelchair users, and help others by sharing what you see.")
            Text("Place data ${PlaceRepository.ATTRIBUTION}", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
    }
}
