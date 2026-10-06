package app.rollspot.shared.auth

/** Input rules for the sign-in and sign-up forms. Views use these to enable buttons and show hints. */
object AuthRules {
    const val PASSWORD_HINT = "Use at least 8 characters, including a number and a special character."

    fun normalizeEmail(value: String): String = value.trim().lowercase()

    fun looksLikeEmail(value: String): Boolean {
        val trimmed = value.trim()
        val at = trimmed.indexOf('@')
        return at > 0 && trimmed.length >= 5 && trimmed.substring(at + 1).contains('.')
    }

    fun isValidPassword(password: String): Boolean =
        password.length >= 8 &&
            password.any { it.isDigit() } &&
            password.any { !it.isLetterOrDigit() }
}

/** The answers to "How do you usually get around?". These strings are stored in `profiles.mobility_aids`. */
object MobilityAids {
    const val WHEELCHAIR = "Wheelchair"
    const val NONE = "No mobility aid"

    val options: List<String> = listOf(WHEELCHAIR, "Crutches", "Walking Aid", NONE, "Other")

    /** The role shown next to a contributor's name, matching the backend's reviewer_role. */
    fun role(aids: List<String>): String? = when {
        aids.isEmpty() -> null
        WHEELCHAIR in aids -> "Wheelchair User"
        else -> "Community Contributor"
    }
}
