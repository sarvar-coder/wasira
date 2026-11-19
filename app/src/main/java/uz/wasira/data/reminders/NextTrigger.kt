package uz.wasira.data.reminders

import java.time.LocalTime
import java.time.ZonedDateTime

/**
 * The next moment a reminder set for [minutes] after local midnight should fire,
 * strictly after [now], in [now]'s zone.
 *
 * Today at that wall-clock time if it is still ahead, otherwise tomorrow. A time
 * already reached today starts tomorrow rather than firing the moment it is armed,
 * which reads as a bug rather than a reminder.
 *
 * Built from the local date and time, not by adding 24 hours, so a DST change
 * keeps the wall-clock time. A time inside a spring-forward gap is pushed forward
 * by the gap (02:30 in a 02:00→03:00 gap fires at 03:30); one inside a fall-back
 * overlap takes the earlier offset.
 */
fun nextTrigger(minutes: Int, now: ZonedDateTime): ZonedDateTime {
    require(minutes in 0..1439) { "minutes out of range: $minutes" }
    val at = LocalTime.of(minutes / 60, minutes % 60)
    val today = ZonedDateTime.of(now.toLocalDate(), at, now.zone)
    if (today.isAfter(now)) return today
    return ZonedDateTime.of(now.toLocalDate().plusDays(1), at, now.zone)
}
