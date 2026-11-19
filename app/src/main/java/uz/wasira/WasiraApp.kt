package uz.wasira

import android.app.Application
import java.io.File
import java.util.concurrent.TimeUnit
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import uz.wasira.data.AlquranApi
import uz.wasira.data.DailyRepository
import uz.wasira.data.LocalStore
import uz.wasira.data.QuranApi
import uz.wasira.data.ReminderScheduler
import uz.wasira.data.SettingsRepository

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

    override fun onCreate() {
        super.onCreate()
        val client = OkHttpClient.Builder().callTimeout(60, TimeUnit.SECONDS).build()
        api = AlquranApi(client, AlquranApi.BASE_URL.toHttpUrl())
        settings = SettingsRepository(LocalStore(File(filesDir, "settings.json")))
        daily = DailyRepository(api, LocalStore(File(filesDir, "daily.json")), settings)
        reminders = object : ReminderScheduler { // Agent C replaces with AlarmReminderScheduler(this)
            override fun schedule(times: List<Int>) {}
            override fun canNotify() = false
        }
    }
}
