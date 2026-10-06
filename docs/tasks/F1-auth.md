# F1: Auth & onboarding (Better Auth)

## Goal
The same sign-in and onboarding flow on both apps, all of it driven by one shared `AuthModel` talking to
Better Auth on the Worker: email + password with email verification, Apple and Google, then onboarding
(name + mobility aids).

## Today
- Backend: `backend/src/auth.ts` (Better Auth with the bearer plugin, Apple, Google, Resend email), plus
  `/v1/auth/email-registered` and `/v1/auth/providers` in `src/index.ts`.
- iOS logic: `Services/AuthSessionStore.swift` (about 380 lines: email check, sign up/in, verify-email
  callback, Apple nonce, Google token exchange, onboarding, change password, sign out, password/email validation).
- iOS views: `Views/Auth/*` (Login, EmailFound, CreatePassword, VerifyEmail, Name, Mobility, AllSet, AuthChrome).
- Android: no auth at all.

## Backend
- [ ] Google: accept the **Android** client ID as well as the iOS one (multiple audiences for ID-token sign-in).
      Add `GOOGLE_ANDROID_CLIENT_ID` to the vars.
- [ ] Verify-email link deep-links into both apps (`puspadi://` scheme + Android intent filter + `web/.well-known`).
- [ ] Apple on Android: Better Auth's web redirect flow. If that's too much for V1.1, hide the Apple button on Android and note it here.

## Shared
- [ ] `auth/AuthRepository`: emailRegistered, signIn, signUp, resendVerification, socialSignIn(provider,
      idToken, nonce), restoreSession, changePassword, signOut.
- [ ] `auth/AuthModel` state machine: `Email → (Found: Password | New: CreatePassword → VerifyEmail) →
      Name → Mobility → AllSet → SignedIn`, plus social branches. Exposes `StateFlow<AuthState>` and takes actions.
- [ ] Move the validation rules into shared, with tests: `looksLikeEmail`, `isValid(password)`, and the
      normalized email (from `AuthSessionStore.swift`).
- [ ] Nonce generation and sha256 for Apple stay shared, and the platform supplies the ID token.

## iOS
- [ ] `Views/Auth/*` render `AuthModel` state and send its actions. `AuthSessionStore.swift` shrinks to an adapter for the Apple/Google SDK buttons.

## Android
- [ ] Compose screens matching the iOS flow, using the Figma frames for the auth flow (see `docs/specs.md`).
- [ ] Google sign-in via Credential Manager → ID token → `AuthModel.socialSignIn`.
- [ ] Session restore on launch, and sign out.

## Acceptance criteria
- A new email user can sign up on Android, verify, and then sign in with the same account on iOS (and the other way round).
- Wrong password, unverified email and network errors show the same messages on both apps (the messages come from shared).
- Killing and relaunching either app keeps the user signed in.
