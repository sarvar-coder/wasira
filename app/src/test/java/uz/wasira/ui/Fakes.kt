package uz.wasira.ui

import java.time.LocalDateTime
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import uz.wasira.data.DailySource
import uz.wasira.data.FetchedAyah
import uz.wasira.data.QuranApi
import uz.wasira.data.ReminderScheduler
import uz.wasira.data.Settings
import uz.wasira.data.SettingsSource
import uz.wasira.domain.Ayah
import uz.wasira.domain.DailyAyah
import uz.wasira.domain.Edition
import uz.wasira.domain.Surah

class FakeSettings(
    var value: Settings = Settings(
        translationEdition = null,
        translationName = null,
        arabicFontSize = 30,
        reminderTimes = listOf(480, 660, 840, 1020, 1200),
    ),
) : SettingsSource {
    override suspend fun read() = value
    override suspend fun setTranslation(identifier: String, name: String?) {
        value = value.copy(translationEdition = identifier, translationName = name)
    }
    override suspend fun setArabicFontSize(size: Int) {
        if (size in listOf(22, 26, 30, 34)) value = value.copy(arabicFontSize = size)
    }
    override suspend fun setReminderTime(slot: Int, minutes: Int) {
        value = value.copy(
            reminderTimes = value.reminderTimes.toMutableList().also { it[slot] = minutes.coerceIn(0, 1439) },
        )
    }
}

class FakeApi(var editions: List<Edition> = listOf(SAHIH, JALANDHRY)) : QuranApi {
    var failures = 0
    var translationCalls = 0
    override suspend fun translations(): List<Edition> {
        translationCalls++
        if (failures > 0) {
            failures--
            throw IllegalStateException("offline")
        }
        return editions
    }
    override suspend fun ayah(number: Int, translation: String?): FetchedAyah = error("not used by the UI")
}

/** Returns [ayah] stamped with the date of [clock]; fails the first [failures] calls. */
class FakeDaily(
    var ayah: DailyAyah = fixture("golden_2_255"),
    private val clock: () -> LocalDateTime = LocalDateTime::now,
) : DailySource {
    var failures = 0
    var calls = 0
    override suspend fun today(): DailyAyah {
        calls++
        if (failures > 0) {
            failures--
            throw IllegalStateException("offline")
        }
        return ayah.copy(date = clock().toLocalDate().toString())
    }
}

class FakeReminders(var permitted: Boolean = true) : ReminderScheduler {
    val scheduled = mutableListOf<List<Int>>()
    override fun schedule(times: List<Int>) {
        scheduled += times
    }
    override fun canNotify() = permitted
}

val SAHIH = Edition("en.sahih", "en", "Saheeh International", "Saheeh International", "text", "translation", "ltr")
val JALANDHRY = Edition("ur.jalandhry", "ur", "جالندہری", "Jalandhry", "text", "translation", "rtl")

/**
 * A DailyAyah built from a live API response saved under fixtures/. The Arabic
 * is taken as sent; only the BOM the API prefixes to 1:1 is removed, as the data
 * layer documents.
 */
fun fixture(name: String, date: String = "2026-11-19"): DailyAyah {
    val stream = checkNotNull(FakeDaily::class.java.classLoader!!.getResourceAsStream("fixtures/$name.json")) {
        "missing fixture $name"
    }
    val root = Json.parseToJsonElement(stream.bufferedReader(Charsets.UTF_8).readText()).jsonObject
    val rows = root.getValue("data").jsonArray.map { it.jsonObject }
    val arabic = rows[0]
    val translation = rows[1]
    val surah = arabic.getValue("surah").jsonObject
    val sajda = arabic.getValue("sajda")
    val sajdaFlag = (sajda as? kotlinx.serialization.json.JsonPrimitive)?.booleanOrNull
    val obligatory = (sajda as? JsonObject)?.getValue("obligatory")?.jsonPrimitive?.boolean
    return DailyAyah(
        date = date,
        edition = translation.edition("identifier"),
        ayah = Ayah(
            number = arabic.int("number"),
            numberInSurah = arabic.int("numberInSurah"),
            surah = Surah(
                number = surah.int("number"),
                nameAr = surah.str("name"),
                nameEn = surah.str("englishName"),
                nameEnTranslation = surah.str("englishNameTranslation"),
                revelationType = surah.str("revelationType"),
                ayahCount = surah.int("numberOfAyahs"),
            ),
            text = arabic.str("text").removePrefix("﻿"),
            sajda = obligatory != null || sajdaFlag == true,
            sajdaObligatory = obligatory,
        ),
        translation = translation.str("text"),
        translationDirection = translation.edition("direction"),
    )
}

private fun JsonObject.str(key: String) = getValue(key).jsonPrimitive.content
private fun JsonObject.int(key: String) = getValue(key).jsonPrimitive.int
private fun JsonObject.edition(key: String) = getValue("edition").jsonObject.str(key)
