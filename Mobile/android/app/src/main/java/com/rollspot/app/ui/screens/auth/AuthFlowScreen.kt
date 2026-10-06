package com.rollspot.app.ui.screens.auth

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.rollspot.shared.auth.AuthRules
import app.rollspot.shared.auth.AuthStep
import app.rollspot.shared.auth.MobilityAids
import com.rollspot.app.RollspotApplication
import com.rollspot.app.ui.rollspotSdk
import kotlinx.coroutines.launch

private val BrandBlue = Color(0xFF007AFF)
private val FieldFill = Color(0xFFF0F0F0)
private val ErrorRed = Color(0xFFDB2E2E)

/**
 * The sign-in / sign-up flow. Screens mirror iOS (Views/Auth); the order and
 * every rule come from the shared AuthModel.
 */
@Composable
fun AuthFlowScreen(onDone: () -> Unit, onCancel: () -> Unit) {
    val sdk = rollspotSdk()
    val viewModel: AuthViewModel = viewModel { AuthViewModel(sdk.auth) }
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    // Finished, or the verification link brought the user back to the app.
    LaunchedEffect(state.step) { if (state.step is AuthStep.Done) onDone() }
    val callbacks = (context.applicationContext as RollspotApplication).authCallbacks
    LaunchedEffect(Unit) {
        callbacks.collect { if (viewModel.state.value.step is AuthStep.VerifyEmail) viewModel.completeVerifiedSignUp() }
    }
    BackHandler { if (!viewModel.back()) onCancel() }

    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFFB8E0FF), Color.White, Color.White)))
            .systemBarsPadding()
            .imePadding(),
    ) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (state.steps.size > 1) {
                IconButton(onClick = { viewModel.back() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") }
            } else {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onCancel) { Text("Not now", color = Color.Gray) }
                }
            }
            progressFor(state.step)?.let {
                LinearProgressIndicator(progress = { it }, modifier = Modifier.fillMaxWidth(), color = BrandBlue)
            }
            when (val step = state.step) {
                AuthStep.Welcome -> WelcomeStep(state.isBusy, viewModel::continueWithEmail) {
                    GoogleButton(state.isBusy, viewModel)
                }
                is AuthStep.EmailFound -> PasswordStep(step.email, state.isBusy, viewModel::signIn) {
                    GoogleButton(state.isBusy, viewModel)
                }
                is AuthStep.CreatePassword -> CreatePasswordStep(state.isBusy, viewModel::choosePassword)
                is AuthStep.Name -> NameStep(step.suggestedName, state.isBusy, viewModel::chooseName)
                AuthStep.Mobility -> MobilityStep(state.isBusy, viewModel::finishMobility)
                is AuthStep.VerifyEmail -> VerifyEmailStep(
                    step.email, state.isBusy, viewModel::completeVerifiedSignUp, viewModel::resendVerificationEmail,
                )
                AuthStep.Done -> Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            }
            state.error?.let { Text(it, color = ErrorRed, style = MaterialTheme.typography.bodySmall) }
            state.notice?.let { Text(it, color = Color.Gray, style = MaterialTheme.typography.bodySmall) }
        }
    }
}

private fun progressFor(step: AuthStep): Float? = when (step) {
    is AuthStep.Name -> 0.33f
    AuthStep.Mobility -> 0.66f
    is AuthStep.VerifyEmail -> 0.88f
    else -> null
}

@Composable
private fun Title(title: String, subtitle: String? = null) {
    Text(title, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
    subtitle?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = Color.Gray) }
}

@Composable
private fun Field(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    secret: Boolean = false,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        visualTransformation = if (secret) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        colors = OutlinedTextFieldDefaults.colors(
            focusedContainerColor = FieldFill,
            unfocusedContainerColor = FieldFill,
            unfocusedBorderColor = Color.Transparent,
            focusedBorderColor = BrandBlue,
        ),
    )
}

@Composable
private fun ContinueButton(title: String, enabled: Boolean, busy: Boolean, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled && !busy,
        modifier = Modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(containerColor = BrandBlue),
    ) {
        if (busy) CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp) else Text(title)
    }
}

@Composable
private fun WelcomeStep(busy: Boolean, onContinue: (String) -> Unit, social: @Composable () -> Unit) {
    var email by rememberSaveable { mutableStateOf("") }
    Title("Welcome to Rollspot", "Sign in or create an account to save places and contribute to the community.")
    Field(email, { email = it }, "Email", KeyboardType.Email)
    ContinueButton("Continue with Email", AuthRules.looksLikeEmail(email), busy) { onContinue(email) }
    social()
}

@Composable
private fun PasswordStep(email: String, busy: Boolean, onSignIn: (String, String) -> Unit, social: @Composable () -> Unit) {
    var emailText by rememberSaveable { mutableStateOf(email) }
    var password by rememberSaveable { mutableStateOf("") }
    Title("Welcome back", "Sign in to save places and contribute to the community.")
    Field(emailText, { emailText = it }, "Email", KeyboardType.Email)
    Field(password, { password = it }, "Password", KeyboardType.Password, secret = true)
    ContinueButton("Continue", password.isNotEmpty() && AuthRules.looksLikeEmail(emailText), busy) { onSignIn(emailText, password) }
    social()
}

@Composable
private fun CreatePasswordStep(busy: Boolean, onContinue: (String) -> Unit) {
    var password by rememberSaveable { mutableStateOf("") }
    var confirm by rememberSaveable { mutableStateOf("") }
    Title("Create a password")
    Field(password, { password = it }, "Password", KeyboardType.Password, secret = true)
    Text(
        AuthRules.PASSWORD_HINT,
        style = MaterialTheme.typography.bodySmall,
        color = if (password.isEmpty() || AuthRules.isValidPassword(password)) Color.Gray else ErrorRed,
    )
    Field(confirm, { confirm = it }, "Confirm password", KeyboardType.Password, secret = true)
    ContinueButton("Continue", AuthRules.isValidPassword(password) && password == confirm, busy) { onContinue(password) }
}

@Composable
private fun NameStep(suggestedName: String, busy: Boolean, onContinue: (String) -> Unit) {
    var name by rememberSaveable(suggestedName) { mutableStateOf(suggestedName) }
    Title("What should we call you?")
    Field(name, { name = it }, "Your name")
    ContinueButton("Continue", name.isNotBlank(), busy) { onContinue(name) }
}

@Composable
private fun MobilityStep(busy: Boolean, onContinue: (List<String>) -> Unit) {
    var selected by rememberSaveable { mutableStateOf(listOf<String>()) }
    Title("How do you usually get around?", "Select all that apply")
    MobilityAids.options.forEach { option ->
        val isSelected = option in selected
        Surface(
            onClick = { selected = if (isSelected) selected - option else selected + option },
            shape = RoundedCornerShape(16.dp),
            color = FieldFill,
            border = if (isSelected) BorderStroke(2.dp, BrandBlue) else null,
            modifier = Modifier.fillMaxWidth().height(54.dp),
        ) {
            Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(option, Modifier.weight(1f), fontWeight = FontWeight.Medium)
                if (isSelected) Icon(Icons.Default.CheckCircle, contentDescription = "Selected", tint = BrandBlue)
            }
        }
    }
    // Same order as the options list, so both apps store the same array.
    ContinueButton("Continue", selected.isNotEmpty(), busy) { onContinue(MobilityAids.options.filter { it in selected }) }
}

@Composable
private fun VerifyEmailStep(email: String, busy: Boolean, onConfirmed: () -> Unit, onResend: () -> Unit) {
    Title("Check your email", "We sent a confirmation link to $email. Tap it, then come back here.")
    Text(
        "Resend email",
        color = BrandBlue,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.clickable(enabled = !busy, onClick = onResend),
    )
    ContinueButton("I've confirmed", true, busy, onConfirmed)
}

@Composable
private fun GoogleButton(busy: Boolean, viewModel: AuthViewModel) {
    if (!GoogleSignIn.isConfigured) return
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    Text("or Sign in with", style = MaterialTheme.typography.bodySmall, color = Color.Gray, modifier = Modifier.fillMaxWidth())
    OutlinedButton(
        onClick = {
            scope.launch {
                try {
                    GoogleSignIn.request(context)?.let { viewModel.signInWithGoogle(it.idToken, it.displayName) }
                } catch (error: Exception) {
                    viewModel.showError(error.message ?: "Sign in with Google failed. Try again.")
                }
            }
        },
        enabled = !busy,
        modifier = Modifier.fillMaxWidth().height(52.dp),
        shape = RoundedCornerShape(16.dp),
    ) {
        Text("G  ", color = Color(0xFF4285F4), fontWeight = FontWeight.Bold)
        Text("Continue with Google", color = Color.Black)
    }
}
