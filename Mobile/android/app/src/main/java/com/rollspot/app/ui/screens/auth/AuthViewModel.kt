package com.rollspot.app.ui.screens.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.rollspot.shared.auth.AuthModel
import app.rollspot.shared.auth.AuthStep
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AuthUiState(
    /** Screens shown so far; the last one is on screen. Back pops it. */
    val steps: List<AuthStep> = listOf(AuthStep.Welcome),
    val isBusy: Boolean = false,
    val error: String? = null,
    val notice: String? = null,
) {
    val step: AuthStep get() = steps.last()
}

/**
 * Only keeps the Android back stack and loading/error flags. Every decision
 * (validation, which step is next, error wording) comes from the shared AuthModel.
 */
class AuthViewModel(private val auth: AuthModel) : ViewModel() {
    private val _state = MutableStateFlow(AuthUiState())
    val state: StateFlow<AuthUiState> = _state.asStateFlow()

    fun continueWithEmail(email: String) = run { auth.continueWithEmail(email) }
    fun signIn(email: String, password: String) = run { auth.signIn(email, password) }
    fun choosePassword(password: String) = run { auth.choosePassword(password) }
    fun chooseName(name: String) = run { auth.chooseName(name) }
    fun finishMobility(aids: List<String>) = run { auth.finishMobility(aids) }
    fun completeVerifiedSignUp() = run { auth.completeVerifiedSignUp() }

    fun signInWithGoogle(idToken: String, displayName: String?) = run {
        auth.signInWithIdToken("google", idToken, null, displayName, isNewAccount = false)
    }

    fun resendVerificationEmail() {
        if (_state.value.isBusy) return
        _state.update { it.copy(isBusy = true, error = null, notice = null) }
        viewModelScope.launch {
            try {
                auth.resendVerificationEmail()
                _state.update { it.copy(isBusy = false, notice = "A new confirmation email was sent.") }
            } catch (error: Exception) {
                _state.update { it.copy(isBusy = false, error = error.message) }
            }
        }
    }

    fun showError(message: String) = _state.update { it.copy(error = message) }

    /** Returns false when there is nothing to go back to (leave the flow). */
    fun back(): Boolean {
        if (_state.value.steps.size <= 1) return false
        _state.update { it.copy(steps = it.steps.dropLast(1), error = null, notice = null) }
        return true
    }

    private fun run(action: suspend () -> AuthStep) {
        if (_state.value.isBusy) return
        _state.update { it.copy(isBusy = true, error = null, notice = null) }
        viewModelScope.launch {
            try {
                val next = action()
                _state.update { it.copy(steps = it.steps + next, isBusy = false) }
            } catch (error: Exception) {
                _state.update { it.copy(isBusy = false, error = error.message ?: "Something went wrong. Try again.") }
            }
        }
    }
}
