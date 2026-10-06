package com.rollspot.app.ui.screens.auth

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.rollspot.app.BuildConfig

/** Android's native Google sheet. It only produces an ID token; the shared AuthModel does the rest. */
object GoogleSignIn {
    val isConfigured: Boolean get() = BuildConfig.GOOGLE_WEB_CLIENT_ID.isNotBlank()

    class Result(val idToken: String, val displayName: String?)

    /** Null when the user closed the sheet. */
    suspend fun request(activityContext: Context): Result? {
        val option = GetGoogleIdOption.Builder()
            .setServerClientId(BuildConfig.GOOGLE_WEB_CLIENT_ID)
            .setFilterByAuthorizedAccounts(false)
            .build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        return try {
            val credential = CredentialManager.create(activityContext).getCredential(activityContext, request).credential
            if (credential is CustomCredential && credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                val google = GoogleIdTokenCredential.createFrom(credential.data)
                Result(google.idToken, google.displayName)
            } else {
                throw IllegalStateException("Sign in with Google failed. Try again.")
            }
        } catch (cancelled: GetCredentialCancellationException) {
            null
        }
    }
}
