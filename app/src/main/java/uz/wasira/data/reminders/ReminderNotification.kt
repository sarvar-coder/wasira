package uz.wasira.data.reminders

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import uz.wasira.MainActivity
import uz.wasira.R

/**
 * The reminder notification. Fixed text: it never names the ayah, because naming
 * it would mean knowing the ayah of the day it fires on, and the app only ever
 * knows today's.
 */
internal object ReminderNotification {
    const val CHANNEL_ID = "daily_ayah"

    /** Idempotent: re-creating an existing channel only updates its name and description. */
    fun ensureChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply { description = context.getString(R.string.notification_channel_description) }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    // areNotificationsEnabled() covers POST_NOTIFICATIONS on 33+; lint cannot see that.
    @SuppressLint("MissingPermission")
    fun post(context: Context, slot: Int) {
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return
        ensureChannel(context)

        val open = PendingIntent.getActivity(
            context,
            slot,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(context.getString(R.string.notification_title))
            .setContentText(context.getString(R.string.notification_body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        manager.notify(slot, notification)
    }
}
