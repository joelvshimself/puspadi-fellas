# Security and privacy architecture

## Implemented controls

| Area | Verified implementation |
|---|---|
| Authentication | Better Auth email/password with verification, Apple/Google identity tokens, bearer sessions with signature requirement |
| Authorization | `requireUserId`; owner checks for review deletion/media references; separate `ADMIN_TOKEN` |
| iOS token | Keychain, `AfterFirstUnlockThisDeviceOnly` |
| Android token | AES-GCM key in Android Keystore; ciphertext in private SharedPreferences |
| Transport | Production URLs are HTTPS; Android release blocks cleartext; iOS ATS allows only local networking exception |
| Secrets | Backend secrets in Wrangler / ignored `.dev.vars`; secret names only in example |
| Data integrity | SQL foreign keys/checks/unique constraints; contribution validation; size/content-type bounds |
| Account deletion | `DELETE /v1/me` cascades D1 user data and attempts R2 cleanup |
| Media ownership | V2 submission verifies staged-photo ownership |

## Trust boundaries

Mobile apps are untrusted clients. The Worker validates auth, ownership, place existence, contribution
codes, and media limits. D1 is not exposed directly. R2 is accessed only through the Worker, although
media GET is public for anyone who knows an object key.

OAuth provider private credentials and Resend/admin secrets belong only in Worker configuration. Mobile
apps contain public client identifiers.

## Sensitive data

- Auth tables may contain password hashes/provider tokens managed by Better Auth; application code does
  not read them directly.
- Profiles can contain display name, mobility aids, avatar, pseudonym, and visibility intent.
- Reviews are public and link structured accessibility observations to a displayed reviewer identity.
- Session tokens are stored securely; iOS unfinished-review text is not encrypted.
- Worker logging can include local verification email HTML when Resend is absent; production logs should
  never use that fallback.

## Potential issues

1. **Privacy:** `show_real_name` is persisted but public `reviewOutput` always returns `display_name` when
   present.
2. **Enumeration:** unauthenticated `/v1/auth/email-registered` reveals whether an email exists.
3. **Rate limiting:** none exists around auth, enumeration, uploads, or admin sync.
4. **Error exposure:** unexpected errors return their message to clients.
5. **Public media:** no signed URL or authorization; object-key obscurity is the only access boundary.
6. **Legacy review path:** legacy media URL ownership is not checked; V2 is protected.
7. **Token persistence:** iOS suppresses Keychain write failure.
8. **Draft privacy:** iOS stores review drafts unencrypted in UserDefaults.
9. **Privacy manifest:** no `PrivacyInfo.xcprivacy` was found.
10. **Backups:** Android allows backup; explicit data-extraction/backup policy was not found.
