package app.rollspot.shared.notifications

import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.auth.InMemoryTokenStore
import app.rollspot.shared.drafts.ContributeDrafts
import app.rollspot.shared.drafts.InMemoryDraftStorage
import app.rollspot.shared.profile.ProfileModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockEngineConfig
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

private val jsonHeaders = headersOf(HttpHeaders.ContentType, "application/json")

@OptIn(ExperimentalCoroutinesApi::class)
class NotificationsModelTest {
    private val requests = mutableListOf<String>()
    private var remindersOn = true
    private var failSaves = false
    private var clock = 5_000_000L

    // Unconfined: requests finish before the call returns, so state can be checked right after.
    private val api = RollspotApi("https://api.test", InMemoryTokenStore("session"), MockEngine(MockEngineConfig().apply {
        dispatcher = Dispatchers.Unconfined
        addHandler { request ->
            val body = (request.body as? OutgoingContent.ByteArrayContent)?.bytes()?.decodeToString().orEmpty()
            requests += "${request.method.value} ${request.url.encodedPath} $body".trim()
            when {
                request.url.encodedPath == "/v1/profile" && failSaves && request.method.value == "PATCH" ->
                    respond("""{"error":"internal_error","message":"down"}""", HttpStatusCode.InternalServerError, jsonHeaders)
                request.url.encodedPath == "/v1/profile" -> {
                    if ("notifyReviewReminders" in body) remindersOn = "\"notifyReviewReminders\":true" in body
                    respond(
                        """{"id":"u1","pseudonym":"p","notify_review_reminders":$remindersOn}""",
                        headers = jsonHeaders,
                    )
                }
                else -> respond("""{"status":"ok"}""", headers = jsonHeaders)
            }
        }
    }))
    private val profile = ProfileModel(api)
    private val drafts = ContributeDrafts(InMemoryDraftStorage()) { clock }

    private fun TestScope.model() = NotificationsModel(api, profile, drafts, backgroundScope)

    @Test
    fun reminderNeedsAnUnfinishedReviewPermissionAndTheSwitch() = runTest(UnconfinedTestDispatcher()) {
        val model = model()
        drafts.setUser("u1")
        drafts.remember("p1", "Beachwalk")
        assertNull(model.reminder.value, "no permission yet: nothing scheduled")

        model.setPermission(NotificationPermission.Granted)
        assertEquals(ReminderPlan("p1", "Beachwalk", clock + ReminderPlan.DELAY_MILLIS), model.reminder.value)

        // More answers later push the reminder back.
        clock += 60_000
        drafts.remember("p1", "Beachwalk")
        assertEquals(clock + ReminderPlan.DELAY_MILLIS, model.reminder.value?.fireAtMillis)

        model.setReviewReminders(false)
        assertNull(model.reminder.value, "switched off")
        model.setReviewReminders(true)

        drafts.forget("p1")
        assertNull(model.reminder.value, "submitted or discarded: cancel it")
    }

    @Test
    fun tokenIsRegisteredOncePerUserAndRemovedBeforeSignOut() = runTest(UnconfinedTestDispatcher()) {
        val model = model()
        model.setPushToken("tok-1", PushPlatform.Ios)
        assertTrue(requests.isEmpty(), "signed out: keep the token for later")

        model.signedIn("u1")
        model.signedIn("u1")
        model.setPushToken("tok-1", PushPlatform.Ios)
        assertEquals(listOf("""PUT /v1/devices {"token":"tok-1","platform":"ios"}"""), requests)

        model.setPushToken("tok-2", PushPlatform.Ios)
        assertEquals("""PUT /v1/devices {"token":"tok-2","platform":"ios"}""", requests.last())

        model.unregister()
        model.signedOut()
        assertEquals("DELETE /v1/devices/tok-2", requests.last())
        assertFalse(model.state.value.isSignedIn)
    }

    @Test
    fun aSwitchShowsAtOnceAndUndoesItselfWhenSavingFails() = runTest(UnconfinedTestDispatcher()) {
        val model = model()
        failSaves = true
        assertFailsWith<Exception> { model.setAnnouncements(false) }
        assertTrue(model.state.value.settings.announcements, "back to what the server has")
        assertTrue(model.state.value.error != null)

        failSaves = false
        model.setPermission(NotificationPermission.Granted)
        assertTrue(model.state.value.receivesAnnouncements)
        model.setPermission(NotificationPermission.Denied)
        assertTrue(model.state.value.isBlocked)
        assertFalse(model.state.value.receivesAnnouncements, "blocked by the phone: unsubscribe")
    }
}
