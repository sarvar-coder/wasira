# Wasira

Quran reader. macOS first; Windows, Linux, iOS, iPad, Android later.

## Scripture is not ordinary data

The Arabic Quran text is never modified, normalised, or diacritic-stripped.
A transform on it is a correctness bug, not a style choice.

**One exception exists, and it is segmentation rather than alteration.** The API
concatenates the Bismillah into ayah 1, so `quran-uthmani` returns 2:1 as
`بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ الٓمٓ` while every translation returns only
"Alif, Lam, Meem". Al-Baqarah's first verse is الٓمٓ alone.

| Surah | Rule |
|---|---|
| 1 | Bismillah **is** ayah 1 — keep it |
| 9 | No Bismillah exists — render no header |
| 2–8, 10–114 | Split it off ayah 1, render as a surah header |
| **27:30** | **Never touched.** That Bismillah is inside Sulayman's letter — genuine ayah content |

Only ayah **1** is ever split. `bismillah_test.dart` pins all four rows and
asserts 27:30 stays byte-identical to the API response.

The `﻿` BOM prefixing 1:1 is stripped.

## Audio is recitation, and recitation is Arabic

The reciter list is a hardcoded set of three, never a runtime filter over the API:

| Reciter | Edition | Path |
|---|---|---|
| Mishary Rashid Alafasy | `ar.alafasy` | verse-by-verse |
| Husary (Mujawwad) | `ar.husarymujawwad` | verse-by-verse |
| Muhammad al-Luhaidan | `ar.muhammadalluhaidan` | **surah-by-surah** |

Of the API's 190 audio editions, 14 are non-Arabic. Those are people reading a
*translation* aloud, which is not recitation; they are never offered as reciters.

Two playback paths, because al-Luhaidan is surah-by-surah:

```
verse-by-verse   /quran/audio/{bitrate}/{edition}/{ayahNumber}.mp3
surah-by-surah   /quran/audio-surah/128/{edition}/{surahNumber}.mp3
```

The API returns `audio: null` for surah-by-surah editions, so that URL is built
by hand. Al-Luhaidan has no per-ayah highlight, repeat-ayah, or play-from-here;
those controls are disabled **with a visible reason** rather than absent.

**Bitrate comes from the edition row, never a literal.** 128k is not universal —
`ar.abdulsamad` 403s at 128k and serves 64k; `ar.minshawi` is the reverse.

**Audio downloads run at most 4 concurrent requests.** Al-Baqarah is 286 separate
files; alquran.cloud and islamic.network are free services with no key, and the
cap is there to keep it that way.

## Verify against the live API before asserting

`curl` the endpoint and look. Six assumptions about this API have already proven
false, four of which would have shipped: a non-Arabic "reciter", the Bismillah
concatenation, an unused sajda flag, a hardcoded bitrate, a tafsir-style
translation with 2660-character entries, and a reciter whose per-ayah URL does
not exist. Prefer a test that pins real behaviour over a comment claiming it.

## Silent failures

Both are fixed in the repo. Keep them fixed — each fails with no error message:

- `com.apple.security.network.client` in **both** `DebugProfile.entitlements` and
  `Release.entitlements`. Absent, every HTTP call fails silently.
- `CFBundleAllowMixedLocalizations` in `Info.plist`. Absent, the share sheet
  renders in the wrong language — which bites because the app ships uz/ru/en/ar.

## Architecture

Flutter's mixed layout: data layer by type, UI layer by feature. Three
deviations from the official structure are deliberate — no flavors, no
`domain/use_cases/`, and a single model set rather than DTOs plus mappers.

State is `flutter_bloc` with **events**, not bare Cubits. Events record user
intent (`SurahOpened`, `AyahPlayed`), which is what future memorization
analytics reads. Sealed states make the UI `switch` exhaustive, so an unhandled
error case fails the build.

Eight packages are allowed: `sqlite3`, `sqlite3_flutter_libs`, `just_audio`,
`flutter_local_notifications`, `http`, `path_provider`, `flutter_bloc`,
`share_plus`. A ninth needs its justification written here.

## Text rendering

Arabic renders in **Amiri Quran**, locked by ADR-0002. Changing it means
re-running the M0 goldens: a different font can silently lack a rare Quranic
mark. Uthmani diacritics collide below `height: 2.0`.

Arabic ayah text is always `TextDirection.rtl`. Translation direction comes from
`editions.direction`, which the API supplies. App layout mirrors only when the UI
language is RTL.

`uz.sodik` is a tafsir-translation: average 217 characters, maximum 2660, against
`en.sahih`'s 137. Translations past ~300 characters clamp with a "Show more".

## Decisions live in ADRs

`docs/adr/` holds why, not what. Read before relitigating a choice.
