package uz.wasira.domain

import java.time.LocalDate

/**
 * A calendar day as a stable key: `2026-09-06`.
 *
 * Local components only. Converting to UTC first would move the boundary for
 * anyone not on it and hand them yesterday's ayah at breakfast.
 */
fun dayKey(date: LocalDate): String =
    "%04d-%02d-%02d".format(java.util.Locale.ROOT, date.year, date.monthValue, date.dayOfMonth)
