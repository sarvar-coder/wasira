package uz.wasira.data.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import uz.wasira.WasiraApp

/**
 * A reminder slot's alarm fired: post the notification, then re-arm that slot for
 * its next occurrence. The alarms are one-shot, so skipping the re-arm would make
 * this the slot's last reminder.
 */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val slot = intent.getIntExtra(EXTRA_SLOT, -1)
        if (slot !in 0 until AlarmReminderScheduler.SLOTS) return

        ReminderNotification.post(context, slot)

        // The time is read from settings rather than carried in the intent, so a
        // time changed since this alarm was armed is the one armed next.
        val app = context.applicationContext as WasiraApp
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                app.settings.read().reminderTimes.getOrNull(slot)
                    ?.let { AlarmReminderScheduler(app).arm(slot, it) }
            } catch (_: Exception) {
                // The next launch or boot re-arms every slot.
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        const val EXTRA_SLOT = "slot"
    }
}
