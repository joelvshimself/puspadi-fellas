package com.rollspot.app.ui.screens.account

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.rollspot.shared.auth.AuthSession
import com.rollspot.app.ui.rollspotSdk
import kotlinx.coroutines.launch

// TODO(F5 #36): the full profile (mobility, avatar, my reviews, saved, change password).
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AccountScreen(onSignedOut: () -> Unit, onNavigateBack: () -> Unit) {
    val auth = rollspotSdk().auth
    val session by auth.session.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val signedIn = session as? AuthSession.SignedIn

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("My account") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") }
                },
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(signedIn?.user?.name ?: "", style = MaterialTheme.typography.headlineSmall)
            Text(signedIn?.user?.email ?: "", style = MaterialTheme.typography.bodyLarge)
            OutlinedButton(onClick = { scope.launch { auth.signOut(); onSignedOut() } }) { Text("Sign out") }
        }
    }
}
