package uz.wasira.domain

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Test

class DayKeyTest {
    @Test fun `is YYYY-MM-DD, zero-padded`() {
        assertEquals("2026-09-06", dayKey(LocalDate.of(2026, 9, 6)))
        assertEquals("2026-12-31", dayKey(LocalDate.of(2026, 12, 31)))
        assertEquals("0987-01-02", dayKey(LocalDate.of(987, 1, 2)))
    }
}
