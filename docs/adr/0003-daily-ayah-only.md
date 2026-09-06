# ADR-0003 — The app is one ayah a day, not a Quran reader

- **Status:** accepted
- **Date:** 2026-09-06
- **Follows:** ADR-0001, ADR-0002

## Context

v1 shipped as a full reader: a surah list, a reader with recitation playback and
per-ayah highlighting, offline audio downloads per reciter with a concurrency
cap, bookmarks, share, and a daily ayah as one tab of four. It worked, was
tested to 211 cases, and built on macOS.

It was also the wrong product. The thing that gets used daily is the daily ayah;
everything else was a reader that already exists in a dozen better apps. Four
tabs made the daily ayah one destination among several rather than the point.

## Decision

The app is one window showing the ayah of the day. The surah list, the reader,
bookmarks, downloads and all recitation playback are removed.

Three consequences follow from the scope rather than from taste, and each was
decided deliberately:

**Fetch per day rather than sync the Quran.** The reader needed all 6236 ayahs
offline, which cost a 5.3 MB first-launch download and 12,472 database rows.
One ayah a day costs one 2.3 KB request against
`/ayah/{n}/editions/quran-uthmani,{translation}`, which returns both editions
and the surah inline. The price is that the app needs the network once a day; a
missed fetch shows a retry rather than an ayah.

**No database.** What survives is a translation, five reminder times and one
ayah. SQLite carried eight tables, a schema version and a migration path for
that. Two JSON files carry it instead, written through a temporary file and
renamed so a crash leaves the previous contents. This drops `sqlite3` and
`sqlite3_flutter_libs`.

**No determinism in the pick.** The daily seed existed so a day the user missed
could be regenerated instead of stored forever. History is gone — the cache
holds today and is erased at rollover — so there is nothing to reproduce. The
ayah is drawn once with `Random()` and read from disk until the date changes.

**Reminders repeat rather than schedule ahead.** The old design scheduled a
rolling seven-day window so each notification could carry its ayah's
translation. That needs to know tomorrow's ayah, which this design refuses on
purpose. Five notifications now repeat daily at fixed times with fixed text.
One ayah, five nudges — the count of reminders is unrelated to the count of
ayahs.

## Consequences

- Roughly 4,200 lines of `lib/` and `test/` deleted, and four packages:
  `sqlite3`, `sqlite3_flutter_libs`, `just_audio`, `share_plus`.
- The app is offline-hostile in a way it was not: one network failure a day is
  visible to the user. This is the real cost and it was accepted knowingly.
- Copy survives; share does not, because share cost a package for one button.
- The Bismillah split survives and still matters: a random draw lands on an
  ayah 1 roughly once every fifty-five days.
- The Arabic size preference survives and gained a control. It was previously
  readable only from the daily screen and settable only from the reader, so
  deleting the reader would have frozen it.
- Everything removed is recoverable from history at `b6d3d62`.

## Alternatives considered

**A menu bar app** (`NSStatusItem` + `LSUIElement`), which would have suited a
once-a-day glance better than a window. Rejected for now because it needs native
Swift and a popover lifecycle; a small window placed near the top of the screen
gets most of the benefit for ten lines. Revisit if the window proves to be in
the way.

**Keeping the offline sync** so the daily ayah always resolves. Rejected: 5.3 MB
and 12,472 rows to serve one ayah a day is the tail wagging the dog, and it was
the only reason the database, the sync isolate and the onboarding progress bar
existed.
