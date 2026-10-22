package app.rollspot.shared.profile

/** One line of a review's notes: `[entrance:Lobby] Has stairs` → label "Lobby", body "Has stairs". */
data class NoteLine(val label: String?, val body: String)

object ReviewNotes {
    /** Splits notes into lines; a leading `[section]` or `[facility:section]` tag becomes the line's label. */
    fun lines(notes: String): List<NoteLine> = notes.lines().map { raw ->
        val line = raw.trim()
        val close = line.indexOf(']')
        if (!line.startsWith("[") || close < 0) {
            NoteLine(null, line)
        } else {
            val tag = line.substring(1, close)
            NoteLine(tag.substringAfterLast(':'), line.substring(close + 1).trim())
        }
    }
}
