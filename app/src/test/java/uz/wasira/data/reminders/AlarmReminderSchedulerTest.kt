package uz.wasira.data.reminders

import android.app.AlarmManager
import android.app.Application
import android.app.NotificationManager
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

// A plain Application: WasiraApp.onCreate would reach into the data layer.
// SDK 35: Robolectric needs Java 21 for SDK 36+, and the toolchain is 17.
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class AlarmReminderSchedulerTest {
    private val context: Application = ApplicationProvider.getApplicationContext()
    private val alarms = shadowOf(context.getSystemService(AlarmManager::class.java))

    @Test
    fun `arms one alarm per slot, all in the future`() {
        AlarmReminderScheduler(context).schedule(listOf(480, 660, 840, 1020, 1200))

        val scheduled = alarms.scheduledAlarms
        assertEquals(5, scheduled.size)
        val now = System.currentTimeMillis()
        scheduled.forEach {
            assertEquals(AlarmManager.RTC_WAKEUP, it.type)
            assertTrue(it.triggerAtTime > now)
        }
    }

    @Test
    fun `rescheduling replaces rather than adds`() {
        val scheduler = AlarmReminderScheduler(context)
        scheduler.schedule(listOf(480, 660, 840, 1020, 1200))
        scheduler.schedule(listOf(481, 661, 841, 1021, 1201))

        assertEquals(5, alarms.scheduledAlarms.size)
    }

    @Test
    fun `posting creates the channel and a notification per slot with fixed text`() {
        ReminderNotification.post(context, 0)
        ReminderNotification.post(context, 3)

        val system = context.getSystemService(NotificationManager::class.java)
        assertEquals("Daily ayah", system.getNotificationChannel("daily_ayah").name)
        val manager = shadowOf(system)
        assertEquals(2, manager.allNotifications.size)
        val posted = manager.getNotification(3)
        assertEquals("Wasira", shadowOf(posted).contentTitle)
        assertEquals("Today's ayah is ready", shadowOf(posted).contentText)
    }
}
