package app.rollspot.shared.profile

import kotlin.test.Test
import kotlin.test.assertEquals

class ReviewNotesTest {
    @Test
    fun tagsBecomeLabels() {
        assertEquals(
            listOf(NoteLine("Elevator", ""), NoteLine(null, "Ask security."), NoteLine("lobby", "It has stairs")),
            ReviewNotes.lines("[Elevator]\nAsk security.\n[entrance:lobby] It has stairs"),
        )
    }

    @Test
    fun unclosedBracketStaysText() {
        assertEquals(listOf(NoteLine(null, "[oops")), ReviewNotes.lines("[oops"))
    }
}
