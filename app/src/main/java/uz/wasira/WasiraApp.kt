package uz.wasira

import android.app.Application
import java.io.File
import java.util.concurrent.TimeUnit
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import uz.wasira.data.AlquranApi
import uz.wasira.data.DailyRepository
import uz.wasira.data.LocalStore
import uz.wasira.data.QuranApi
import uz.wasira.data.ReminderScheduler
import uz.wasira.data.SettingsRepository
import uz.wasira.data.reminders.AlarmReminderScheduler

/** Manual dependency container. One instance per process. */
class WasiraApp : Application() {
    lateinit var api: QuranApi
        private set
    lateinit var settings: SettingsRepository
        private set
    lateinit var daily: DailyRepository
        private set
    lateinit var reminders: ReminderScheduler
        private set

    /** Lives as long as the process; for work that must outlive any one screen. */
    val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        val client = OkHttpClient.Builder().callTimeout(60, TimeUnit.SECONDS).build()
        api = AlquranApi(client, AlquranApi.BASE_URL.toHttpUrl())
        settings = SettingsRepository(LocalStore(File(filesDir, "settings.json")))
        daily = DailyRepository(api, LocalStore(File(filesDir, "daily.json")), settings)
        reminders = AlarmReminderScheduler(this)

        // Not awaited: reminders are rewritten on every launch and none of it
        // needs to happen before the first frame.
        appScope.launch { refreshReminders() }
    }

    /**
     * Rewrites the five daily reminders. Called on launch and by RescheduleReceiver.
     *
     * Skipped until a translation has been chosen: that is the moment the app
     * stops being a picker. Skipped too without notification permission — asking
     * for it is the UI's job, not launch's.
     */
    suspend fun refreshReminders() {
        try {
            val current = settings.read()
            if (current.translationEdition == null) return
            if (!reminders.canNotify()) return
            reminders.schedule(current.reminderTimes)
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // No reminders is a worse app, not a broken one.
        }
    }
}
