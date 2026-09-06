# Wasira

One ayah a day. macOS first; Windows, Linux, iOS, iPad, Android later.

The app was a full Quran reader — surah list, reader, recitation, offline
downloads, bookmarks. It is now one window showing the ayah of the day. That
history matters when reading the repo: `git show b6d3d62` is the last commit
before the narrowing, and ADR-0003 says why.

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
draw lands on an ayah 1 roughly once every fifty-five days. `bismillah_test.dart`
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
- **A reminder cannot name the ayah.** Reminders are five repeating daily
  notifications with fixed text. Carrying the ayah in the body would mean
  knowing tomorrow's, which is the one thing this app deliberately does not do.

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

Both are fixed in the repo. Keep them fixed — each fails with no error message:

- `com.apple.security.network.client` in **both** `DebugProfile.entitlements` and
  `Release.entitlements`. Absent, every HTTP call fails silently.
- `CFBundleAllowMixedLocalizations` in `Info.plist`. Absent, macOS text renders
  in the wrong language — which bites because the app ships uz/ru/en/ar.

CI runs `flutter analyze` and `flutter test` only. **It never builds the app**,
so a plugin that fails to integrate passes CI. Run `flutter build macos --debug`
by hand whenever a package changes.

## Storage is two JSON files

`settings.json` holds the chosen translation, the Arabic size and five reminder
times. `daily.json` holds today's ayah. Both are written through a temporary
file and renamed, so a crash mid-write leaves the previous contents.

Reads never throw. A missing file is a first launch and a corrupt one is
indistinguishable from it as far as the app can act — and a daily ayah is cheap
to fetch again.

There is no database. Adding one back needs a reason written here.

## Architecture

Flutter's mixed layout: data layer by type, UI layer by feature.

State is `flutter_bloc` with **events**, not bare Cubits. Sealed states make the
UI `switch` exhaustive, so an unhandled case fails the build.

Six packages: `path_provider`, `http`, `flutter_bloc`,
`flutter_local_notifications`, `timezone`, `cupertino_icons`. A seventh needs its
justification written here.

`timezone` is not a free choice — `flutter_local_notifications.zonedSchedule`
takes a `TZDateTime` and the plain-`DateTime` API is gone. It does not know
which zone this is (`tz.local` defaults to UTC, five hours out for Tashkent), so
the IANA name is read from `/etc/localtime` rather than adding a package for it.
Windows keeps its zone in the registry and will need a lookup when it ships.

## Text rendering

Arabic renders in **Amiri Quran**, locked by ADR-0002. Changing it means
re-running the goldens: a different font can silently lack a rare Quranic mark.
Uthmani diacritics collide below `height: 2.0`.

Arabic ayah text is always `TextDirection.rtl`. App layout mirrors only when the
UI language is RTL.

`uz.sodik` is a tafsir-translation: average 217 characters, maximum 2660, against
`en.sahih`'s 137. Translations past 300 characters clamp with a "Show more".

## The window

460×620, placed near the top of the screen on launch against `visibleFrame` so
it clears the menu bar and the Dock. A normal window — no `NSStatusItem`, no
`LSUIElement`, no window package.

## Decisions live in ADRs

`docs/adr/` holds why, not what. Read before relitigating a choice.
