# Wasira

One ayah a day. Android, native Kotlin; iOS later.

The app was a full Quran reader — surah list, reader, recitation, offline
downloads, bookmarks — and then a Flutter macOS app showing one ayah. It is now
a native Android app showing the ayah of the day. That history matters when
reading the repo: `git show b6d3d62` is the last commit before the narrowing
(ADR-0003), and `git show flutter-final` is the last Flutter state (ADR-0004).

## Scripture is not ordinary data

The Arabic Quran text is never modified, normalised, or diacritic-stripped.
A transform on it is a correctness bug, not a style choice. What leaves the app
through Copy is byte-identical to what the API sent.

**One exception exists, and it is segmentation rather than alteration.** The API
concatenates the Bismillah into ayah 1, so `quran-uthmani` returns 2:1 as
`بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ الٓمٓ` while every translation returns only
"Alif, Lam, Meem". Al-Baqarah's first ayah is الٓمٓ alone.

| Surah | Rule |
|---|---|
| 1 | Bismillah **is** ayah 1 — keep it |
| 9 | No Bismillah exists — nothing to split |
| 2–8, 10–114 | Split it off ayah 1 |
| **27:30** | **Never touched.** That Bismillah is inside Sulayman's letter — genuine ayah content |

Only ayah **1** is ever split. This still matters with one ayah a day: a random
draw lands on an ayah 1 roughly once every fifty-five days. The Bismillah test
pins all four rows and asserts 27:30 stays byte-identical to the API response.

The `﻿` BOM prefixing 1:1 is stripped.

## One request a day

```
GET /v1/ayah/{n}/editions/quran-uthmani,{translation}     2.3 KB
```

Both editions in one call. Each row carries its surah inline — number, name,
ayah count — which is why the app stores no surah table, no ayah table and no
translation table.

`n` is a global ayah number, 1 to 6236. That range is fixed by the text, not by
anything the app downloads.

## Today, and only today

There is no yesterday and no tomorrow in the data model. The cache holds exactly
one ayah; the moment its date is not today it is thrown away and a new one is
drawn. No history, no calendar, no prefetch.

Two consequences worth not relitigating:

- **The draw is not deterministic and does not need to be.** A seed existed so a
  past day could be reproduced instead of stored. There are no past days.
- **A reminder cannot name the ayah.** Reminders are five daily notifications
  with fixed text. Carrying the ayah in the body would mean knowing tomorrow's,
  which is the one thing this app deliberately does not do.

## Verify against the live API before asserting

`curl` the endpoint and look. Assumptions about this API have already proven
false, several of which would have shipped: the Bismillah concatenation, an
unused sajda flag, a tafsir-style translation with 2660-character entries, and
`sajda` arriving as `false` or as an object depending on the ayah. Prefer a test
that pins real behaviour over a comment claiming it.

Still open upstream: surahs 95 and 97 send a spurious `U+0651` shadda on the
Bismillah. Reported at `islamic-network/.github#2`; both spellings are
recognised.

## Silent failures

Each fails with no error message. Keep them fixed:

- **`INTERNET` permission in the manifest.** Absent, every HTTP call fails.
- **`POST_NOTIFICATIONS` requested at runtime on API 33+.** Declaring it is not
  enough; unrequested, reminders fire and never show.
- **`RescheduleReceiver` stays.** Alarms are wiped on reboot; without it every
  reminder silently stops after the first restart.

## Storage is two JSON files

`settings.json` holds the chosen translation, the Arabic size and five reminder
times. `daily.json` holds today's ayah. Both live in `filesDir` and are written
through `AtomicFile`, so a crash mid-write leaves the previous contents.

Reads never throw. A missing file is a first launch and a corrupt one is
indistinguishable from it as far as the app can act — and a daily ayah is cheap
to fetch again.

There is no database. Adding one back needs a reason written here.

## Architecture

Jetpack Compose. UI layer by feature (`ui/`), data layer by type (`data/`),
models in `domain/`.

Each screen has a ViewModel that takes a sealed `Event` through a single
`onEvent` and exposes a sealed `State` — no bare mutator methods. Sealed states
make the UI `when` exhaustive, so an unhandled case fails the build.

Dependencies are wired by hand in `WasiraApp`. No DI framework.

Packages, exactly: `core-ktx`, `activity-compose`, the Compose BOM (`ui`,
`material3`, `ui-tooling-preview`), `lifecycle-viewmodel-compose` +
`lifecycle-runtime-compose`, `kotlinx-coroutines-android`,
`kotlinx-serialization-json`, OkHttp. Test-only: JUnit4, `coroutines-test`,
`mockwebserver3`, Robolectric, Compose `ui-test`, Roborazzi. Another needs its
justification written here.

## Reminders

Five daily notifications at user-chosen times, fixed text, channel `daily_ayah`.
Each is one inexact `AlarmManager.setAndAllowWhileIdle` alarm — no
`SCHEDULE_EXACT_ALARM`; a few minutes late is fine. An alarm is one-shot:
`ReminderReceiver` posts and re-arms that slot for its next occurrence, and
`RescheduleReceiver` re-arms all five on boot, clock change and zone change.
Times are local wall-clock in `ZoneId.systemDefault()`, computed with `java.time`
so DST keeps the wall-clock time.

Nothing is armed until a translation is chosen and notifications are allowed.

## Text rendering

Arabic renders in **Amiri Quran**, locked by ADR-0002. Changing it means
re-running the goldens: a different font can silently lack a rare Quranic mark.
Uthmani diacritics collide below line height `2.0`.

Arabic ayah text is always RTL. App layout mirrors only when the UI language is
RTL.

`uz.sodik` is a tafsir-translation: average 217 characters, maximum 2660, against
`en.sahih`'s 137. Translations past 300 characters clamp with a "Show more".

## Build and test

```
./gradlew assembleDebug
./gradlew testDebugUnitTest
./gradlew lintDebug
./gradlew installDebug
```

CI runs lint, unit tests and `assembleDebug` — CI builds the app now.

**Never use an emulator.** Test on the physical phone over `adb`.

## Decisions live in ADRs

`docs/adr/` holds why, not what. Read before relitigating a choice.
