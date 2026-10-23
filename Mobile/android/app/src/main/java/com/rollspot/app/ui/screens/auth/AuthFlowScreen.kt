package com.rollspot.app.ui.screens.auth

import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.RadioButtonChecked
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import app.rollspot.shared.auth.AuthRules
import app.rollspot.shared.auth.AuthStep
import app.rollspot.shared.auth.MobilityAids
import com.rollspot.app.R
import com.rollspot.app.RollspotApplication
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.theme.*
import kotlinx.coroutines.launch

/** Starting state for the debug design review (`designReview` launch extra). */
data class AuthPreview(
    val steps: List<AuthStep> = listOf(AuthStep.Welcome),
    val password: String = "",
    val error: String? = null,
    val aids: List<String> = emptyList(),
)

/**
 * Sign-in / sign-up. One screen per iOS view in Views/Auth (same layout, sizes and copy);
 * which screen comes next is decided by the shared AuthModel.
 */
@Composable
fun AuthFlowScreen(onDone: () -> Unit, onCancel: () -> Unit, preview: AuthPreview? = null) {
    val sdk = rollspotSdk()
    val viewModel: AuthViewModel = viewModel { AuthViewModel(sdk.auth, preview?.steps ?: listOf(AuthStep.Welcome)) }
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(state.step) { if (state.step is AuthStep.Done) onDone() }
    val callbacks = (context.applicationContext as RollspotApplication).authCallbacks
    LaunchedEffect(Unit) {
        callbacks.collect { if (viewModel.state.value.step is AuthStep.VerifyEmail) viewModel.completeVerifiedSignUp() }
    }
    BackHandler { if (!viewModel.back()) onCancel() }

    // Push forward, pop back: same direction as a navigation stack on iOS.
    var depth by remember { mutableIntStateOf(state.steps.size) }
    val forward = state.steps.size >= depth
    SideEffect { depth = state.steps.size }

    AnimatedContent(
        targetState = state.step,
        transitionSpec = {
            val dir = if (forward) 1 else -1
            (slideInHorizontally(tween(280, easing = Rollspot.EaseOut)) { it * dir / 3 } + fadeIn(tween(200)))
                .togetherWith(slideOutHorizontally(tween(280, easing = Rollspot.EaseOut)) { -it * dir / 3 } + fadeOut(tween(160)))
        },
        label = "auth-step",
    ) { step ->
        when (step) {
            AuthStep.AllSet -> AllSetScreen(onExplore = onDone)
            else -> Box(Modifier.fillMaxSize()) {
                GradientBackground()
                Column(
                    Modifier.fillMaxSize().systemBarsPadding().imePadding().padding(horizontal = 24.dp),
                ) {
                    when (step) {
                        AuthStep.Welcome -> WelcomeStep(state, viewModel, onCancel)
                        is AuthStep.EmailFound -> EmailFoundStep(step.email, state, viewModel, preview)
                        is AuthStep.CreatePassword -> CreatePasswordStep(step.email, state, viewModel)
                        is AuthStep.Name -> NameStep(step.suggestedName, state, viewModel)
                        AuthStep.Mobility -> MobilityStep(state, viewModel, preview?.aids.orEmpty())
                        is AuthStep.VerifyEmail -> VerifyEmailStep(step.email, state, viewModel)
                        else -> Unit
                    }
                }
            }
        }
    }
}

@Composable
private fun TopBar(viewModel: AuthViewModel) {
    Spacer(Modifier.height(4.dp))
    BackCircleButton(onClick = { viewModel.back() })
}

@Composable
private fun Heading(title: String, subtitle: String? = null) {
    Text(title, style = Rollspot.Title, color = Color.Black)
    subtitle?.let { Text(it, style = Rollspot.Subheadline, color = Rollspot.Secondary) }
}

@Composable
private fun FieldLabel(text: String, error: Boolean = false) {
    Text(text, style = Rollspot.Caption, color = if (error) Rollspot.ErrorRed else Rollspot.Secondary)
}

@Composable
private fun InputField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    error: Boolean = false,
    secret: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    enabled: Boolean = true,
) {
    var focused by remember { mutableStateOf(false) }
    var reveal by remember { mutableStateOf(false) }
    FieldBox(focused = focused, error = error) {
        Box(Modifier.weight(1f)) {
            if (value.isEmpty()) Text(placeholder, style = Rollspot.Body, color = Color(0x4D3C3C43))
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                enabled = enabled,
                singleLine = true,
                textStyle = Rollspot.Body.copy(color = Color.Black),
                cursorBrush = SolidColor(Rollspot.BrandBlue),
                visualTransformation = if (secret && !reveal) PasswordVisualTransformation('●') else VisualTransformation.None,
                keyboardOptions = KeyboardOptions(keyboardType = if (secret) KeyboardType.Password else keyboardType),
                // The hint is drawn separately; this names the field for TalkBack.
                modifier = Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused }
                    .semantics { contentDescription = placeholder },
            )
        }
        if (secret) {
            Icon(
                if (reveal) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility,
                contentDescription = if (reveal) "Hide password" else "Show password",
                tint = Rollspot.Secondary,
                modifier = Modifier.size(20.dp).clickable { reveal = !reveal },
            )
        }
    }
}

@Composable
private fun SocialButtons(state: AuthUiState, viewModel: AuthViewModel) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("or Sign in with", style = Rollspot.Caption, color = Rollspot.Secondary)
        // Apple sign-in on Android needs a web redirect flow; it is hidden until that exists.
        GoogleButton(enabled = !state.isBusy) {
            if (!GoogleSignIn.isConfigured) {
                // Same as iOS until the Android OAuth client ID is set (see #44).
                viewModel.showError("Google Sign-In has not been configured yet.")
                return@GoogleButton
            }
            scope.launch {
                try {
                    GoogleSignIn.request(context)?.let { viewModel.signInWithGoogle(it.idToken, it.displayName) }
                } catch (error: Exception) {
                    viewModel.showError(error.message ?: "Sign in with Google failed. Try again.")
                }
            }
        }
    }
}

@Composable
private fun ErrorText(state: AuthUiState) {
    state.error?.let { Text(it, style = Rollspot.Caption, color = Rollspot.ErrorRed) }
}

// ---- Screens (mirroring Views/Auth/*.swift) ----

@Composable
private fun ColumnScope.WelcomeStep(state: AuthUiState, viewModel: AuthViewModel, onCancel: () -> Unit) {
    var email by rememberSaveable { mutableStateOf("") }
    Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.End) {
            Text(
                "Not now",
                style = Rollspot.Subheadline.copy(fontWeight = FontWeight.Medium),
                color = Rollspot.Secondary,
                modifier = Modifier.clickable(onClick = onCancel),
            )
        }
        Heading("Welcome to Rollspot", "Sign in or create an account to save places and contribute to the community.")
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            InputField(email, { email = it }, "Email Address", error = state.error != null, keyboardType = KeyboardType.Email)
            ErrorText(state)
        }
        // Always looks active (design); an invalid email gets the shared inline error.
        ContinueButton("Continue", loading = state.isBusy) { viewModel.continueWithEmail(email) }
        SocialButtons(state, viewModel)
    }
}

@Composable
private fun ColumnScope.EmailFoundStep(email: String, state: AuthUiState, viewModel: AuthViewModel, preview: AuthPreview?) {
    var emailText by rememberSaveable { mutableStateOf(email) }
    var password by rememberSaveable { mutableStateOf(preview?.password.orEmpty()) }
    val error = state.error ?: preview?.error
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        TopBar(viewModel)
        Heading("Welcome to Rollspot", "Sign in or create an account to save places and contribute to the community.")
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FieldLabel("Email")
            InputField(emailText, { emailText = it }, "Email Address", keyboardType = KeyboardType.Email)
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FieldLabel("Password", error = error != null)
            InputField(password, { password = it }, "Password", error = error != null, secret = true)
            error?.let { Text(it, style = Rollspot.Caption, color = Rollspot.ErrorRed) }
        }
        ContinueButton("Continue", loading = state.isBusy) { viewModel.signIn(emailText, password) }
        SocialButtons(state, viewModel)
    }
}

@Composable
private fun ColumnScope.CreatePasswordStep(email: String, state: AuthUiState, viewModel: AuthViewModel) {
    var password by rememberSaveable { mutableStateOf("") }
    var confirm by rememberSaveable { mutableStateOf("") }
    val valid = AuthRules.isValidPassword(password)
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        TopBar(viewModel)
        Heading("Create a password")
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FieldLabel("Email")
            InputField(email, {}, "Email Address", enabled = false)
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FieldLabel("Password")
            InputField(password, { password = it }, "Password", secret = true)
            Text(
                AuthRules.PASSWORD_HINT,
                style = Rollspot.Caption,
                color = if (password.isEmpty() || valid) Rollspot.Secondary else Rollspot.ErrorRed,
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FieldLabel("Confirm Password")
            InputField(confirm, { confirm = it }, "Confirm Password", secret = true)
        }
        ErrorText(state)
    }
    Spacer(Modifier.weight(1f))
    ContinueButton("Continue", Modifier.padding(bottom = 12.dp), enabled = valid && password == confirm) {
        viewModel.choosePassword(password)
    }
}

@Composable
private fun ColumnScope.NameStep(suggestedName: String, state: AuthUiState, viewModel: AuthViewModel) {
    var name by rememberSaveable(suggestedName) { mutableStateOf(suggestedName) }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        TopBar(viewModel)
        StepProgressBar(0.33f, Modifier.padding(vertical = 8.dp))
        Text("What should we call you?", style = Rollspot.Title, color = Color.Black)
        InputField(name, { name = it }, "Your name")
        ErrorText(state)
    }
    Spacer(Modifier.weight(1f))
    ContinueButton("Continue", Modifier.padding(bottom = 12.dp), enabled = name.isNotBlank()) { viewModel.chooseName(name) }
}

@Composable
private fun ColumnScope.MobilityStep(state: AuthUiState, viewModel: AuthViewModel, initial: List<String>) {
    var selected by rememberSaveable { mutableStateOf(initial) }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        TopBar(viewModel)
        StepProgressBar(0.66f, Modifier.padding(vertical = 8.dp))
        Text("How do you usually get around?", style = Rollspot.Title, color = Color.Black)
        Text("Select all that apply", style = Rollspot.Subheadline, color = Rollspot.Secondary)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            MobilityAids.options.forEach { option ->
                val isSelected = option in selected
                val interaction = remember { MutableInteractionSource() }
                val shape = RoundedCornerShape(16.dp)
                Row(
                    Modifier
                        .fillMaxWidth()
                        .height(54.dp)
                        .pressScale(interaction)
                        .background(Rollspot.FieldFill, shape)
                        .then(if (isSelected) Modifier.border(2.dp, Rollspot.BrandBlue, shape) else Modifier)
                        .clickable(interactionSource = interaction, indication = null) {
                            selected = if (isSelected) selected - option else selected + option
                        }
                        .padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        option,
                        style = Rollspot.Body.copy(fontWeight = FontWeight.Medium),
                        color = if (isSelected) Rollspot.BrandBlue else Color.Black,
                        modifier = Modifier.weight(1f),
                    )
                    // Radio dot, as in the design.
                    AnimatedVisibility(isSelected, enter = scaleIn(tween(150), 0.6f) + fadeIn(tween(150)), exit = scaleOut(tween(150), 0.6f) + fadeOut(tween(150))) {
                        Icon(Icons.Filled.RadioButtonChecked, contentDescription = "Selected", tint = Rollspot.BrandBlue, modifier = Modifier.size(22.dp))
                    }
                }
            }
        }
        ErrorText(state)
    }
    Spacer(Modifier.weight(1f))
    // Same order as the options, so both apps store the same array.
    ContinueButton("Continue", Modifier.padding(bottom = 12.dp), enabled = selected.isNotEmpty(), loading = state.isBusy) {
        viewModel.finishMobility(MobilityAids.options.filter { it in selected })
    }
}

@Composable
private fun ColumnScope.VerifyEmailStep(email: String, state: AuthUiState, viewModel: AuthViewModel) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        TopBar(viewModel)
        StepProgressBar(0.88f, Modifier.padding(vertical = 8.dp))
        Heading("Check your email", "We sent a confirmation link to $email. Tap it, then come back here.")
        ErrorText(state)
        state.notice?.let { Text(it, style = Rollspot.Caption, color = Rollspot.Secondary) }
        Text(
            "Resend email",
            style = Rollspot.Subheadline.copy(fontWeight = FontWeight.SemiBold),
            color = Rollspot.BrandBlue,
            modifier = Modifier.clickable(enabled = !state.isBusy) { viewModel.resendVerificationEmail() },
        )
    }
    Spacer(Modifier.weight(1f))
    ContinueButton("I've confirmed", Modifier.padding(bottom = 12.dp), loading = state.isBusy) { viewModel.completeVerifiedSignUp() }
}

/** "You're all set!": a floating glass card over the map (design "Welcome Screen", iOS AuthAllSetView). */
@Composable
fun AllSetScreen(onExplore: () -> Unit) {
    Box(Modifier.fillMaxSize()) {
        com.rollspot.app.ui.components.StaticMapBackdrop(Modifier.fillMaxSize())
        Column(
            Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(8.dp)
                .fillMaxWidth()
                .background(Color.White, RoundedCornerShape(32.dp))
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(Modifier.padding(top = 10.dp).size(40.dp, 5.dp).background(Color(0x59808080), RoundedCornerShape(3.dp)))
            Image(painterResource(R.drawable.all_set_mall), contentDescription = null, modifier = Modifier.padding(top = 8.dp).size(285.dp, 135.dp))
            Text("You're all set!", style = Rollspot.Title, color = Color.Black)
            Text(
                "Find accessible malls, save your favorites, or contribute a review to help others.",
                style = Rollspot.Subheadline,
                color = Rollspot.Secondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 12.dp),
            )
            ContinueButton("Explore Malls", Modifier.widthIn(max = 200.dp).padding(bottom = 24.dp), onClick = onExplore)
        }
    }
}
