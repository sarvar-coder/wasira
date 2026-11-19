package uz.wasira.data.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import uz.wasira.WasiraApp

/**
 * Re-arms all five reminders after a reboot (alarms are wiped) or a clock or zone
 * change (the armed instants no longer match the chosen local times).
 *
 * Without this receiver every reminder silently stops after the first reboot.
 */
class RescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in ACTIONS) return
        val app = context.applicationContext as WasiraApp
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                app.refreshReminders()
            } finally {
                pending.finish()
            }
        }
    }

    private companion object {
        val ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
        )
    }
}
