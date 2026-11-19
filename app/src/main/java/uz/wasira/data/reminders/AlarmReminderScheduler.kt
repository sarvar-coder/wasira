package uz.wasira.data.reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import java.time.ZoneId
import java.time.ZonedDateTime
import uz.wasira.data.ReminderScheduler

/**
 * Five daily reminders on [AlarmManager].
 *
 * Each slot is one inexact, idle-allowed alarm armed for its next occurrence only;
 * [ReminderReceiver] re-arms it for the following day when it fires, and
 * [RescheduleReceiver] re-arms all five after a reboot or a clock/zone change.
 * Inexact on purpose: a reminder a few minutes late is fine, and exact alarms
 * need SCHEDULE_EXACT_ALARM, which the user would have to grant in Settings.
 */
class AlarmReminderScheduler(context: Context) : ReminderScheduler {
    private val context = context.applicationContext
    private val alarms = this.context.getSystemService(AlarmManager::class.java)

    /** Cancelling every slot first is what keeps a changed time from leaving its old alarm behind. */
    override fun schedule(times: List<Int>) {
        for (slot in 0 until SLOTS) alarms.cancel(pendingIntent(slot))
        times.take(SLOTS).forEachIndexed { slot, minutes -> arm(slot, minutes) }
    }

    override fun canNotify(): Boolean = NotificationManagerCompat.from(context).areNotificationsEnabled()

    /** Arms [slot] for the next occurrence of [minutes] after local midnight. */
    fun arm(slot: Int, minutes: Int) {
        val at = nextTrigger(minutes, ZonedDateTime.now(ZoneId.systemDefault()))
        alarms.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            at.toInstant().toEpochMilli(),
            pendingIntent(slot),
        )
    }

    // The request code is the slot, so each slot owns exactly one PendingIntent:
    // re-arming replaces it and cancel finds it. Extras take no part in matching.
    private fun pendingIntent(slot: Int): PendingIntent = PendingIntent.getBroadcast(
        context,
        slot,
        Intent(context, ReminderReceiver::class.java).putExtra(ReminderReceiver.EXTRA_SLOT, slot),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    companion object {
        const val SLOTS = 5
    }
}
