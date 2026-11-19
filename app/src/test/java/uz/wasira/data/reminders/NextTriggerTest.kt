package uz.wasira.data.reminders

import java.time.ZoneId
import java.time.ZonedDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

class NextTriggerTest {
    private val tashkent = ZoneId.of("Asia/Tashkent")
    private val berlin = ZoneId.of("Europe/Berlin")

    private fun at(zone: ZoneId, y: Int, mo: Int, d: Int, h: Int, mi: Int, s: Int = 0) =
        ZonedDateTime.of(y, mo, d, h, mi, s, 0, zone)

    @Test
    fun `a time still ahead today fires today`() {
        val now = at(tashkent, 2026, 11, 19, 7, 0)
        assertEquals(at(tashkent, 2026, 11, 19, 8, 0), nextTrigger(480, now))
    }

    @Test
    fun `a time just passed fires tomorrow`() {
        val now = at(tashkent, 2026, 11, 19, 8, 0, 1)
        assertEquals(at(tashkent, 2026, 11, 20, 8, 0), nextTrigger(480, now))
    }

    @Test
    fun `the exact current minute fires tomorrow, not now`() {
        val now = at(tashkent, 2026, 11, 19, 8, 0)
        assertEquals(at(tashkent, 2026, 11, 20, 8, 0), nextTrigger(480, now))
    }

    @Test
    fun `midnight and the last minute of the day`() {
        val now = at(tashkent, 2026, 11, 19, 12, 0)
        assertEquals(at(tashkent, 2026, 11, 20, 0, 0), nextTrigger(0, now))
        assertEquals(at(tashkent, 2026, 11, 19, 23, 59), nextTrigger(1439, now))
    }

    @Test
    fun `rolls over month and year ends`() {
        val now = at(tashkent, 2026, 12, 31, 22, 0)
        assertEquals(at(tashkent, 2027, 1, 1, 8, 0), nextTrigger(480, now))
    }

    @Test
    fun `wall-clock time is kept across a spring-forward night`() {
        // Berlin 2027-03-28: 02:00 CET jumps to 03:00 CEST. The day before, 08:00 is
        // past, so the next 08:00 is on the transition day, 23 hours later.
        val now = at(berlin, 2027, 3, 27, 9, 0)
        val next = nextTrigger(480, now)
        assertEquals(at(berlin, 2027, 3, 28, 8, 0), next)
        assertEquals(2 * 3600, next.offset.totalSeconds)
    }

    @Test
    fun `a time inside the spring-forward gap is pushed past it`() {
        val now = at(berlin, 2027, 3, 28, 1, 0)
        val next = nextTrigger(2 * 60 + 30, now)
        assertEquals(java.time.LocalDateTime.of(2027, 3, 28, 3, 30), next.toLocalDateTime())
    }

    @Test
    fun `a time inside the fall-back overlap takes the earlier offset`() {
        // Berlin 2026-10-25: 03:00 CEST falls back to 02:00 CET, so 02:30 happens twice.
        val now = at(berlin, 2026, 10, 25, 0, 30)
        val next = nextTrigger(2 * 60 + 30, now)
        assertEquals(java.time.LocalDateTime.of(2026, 10, 25, 2, 30), next.toLocalDateTime())
        assertEquals(2 * 3600, next.offset.totalSeconds)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `rejects minutes outside a day`() {
        nextTrigger(1440, at(tashkent, 2026, 11, 19, 7, 0))
    }
}
