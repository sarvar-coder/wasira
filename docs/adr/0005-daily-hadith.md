# ADR-0005 — A hadith of the day, from HadeethEnc, under the ayah

- **Status:** accepted
- **Date:** 2026-11-19
- **Amends:** ADR-0003

## Context

ADR-0003 narrowed the app to one ayah a day. The user asked for one hadith a
day alongside it, with its explanation, in the app's languages where possible.

Eight hadith APIs were compared live on 2026-11-19:

| Source | Key | Uzbek | Explanation | English size |
|---|---|---|---|---|
| **HadeethEnc** (hadeethenc.com) | no | ~530 of ~2,800 | yes, with lessons | ~2,800 |
| fawazahmed0/hadith-api (jsDelivr) | no | none | no | ~36,000 |
| sunnah.com | yes (403 without) | none | no | — |
| hadithapi.com | yes (403 without) | none | no | — |
| oanor.com | yes | none | no | wraps fawazahmed0 |
| AhmedBaset / sunnah-hadith-api | self-host | none | no | — |

## Decision

**HadeethEnc.** It is the only source with Uzbek, the only one with an
explanation (sharh) and lessons, and it returns the Arabic, the translation,
attribution and grade in one response with no key. fawazahmed0 has thirteen
times the hadiths, but they are bare text, there is no Uzbek, and 2,800 is
over seven years of daily draws without a repeat.

**Drawn from the English listing, shown in the UI language when it exists.**
Only about a third of HadeethEnc's hadiths have Uzbek. Drawing only those
would repeat within eighteen months, so the draw is made over the whole
English set: Uzbek is shown when that hadith has it, and English otherwise.
The UI language is the one the app is actually showing (`R.string.hadith_language`),
not the device's, which may be one the app has no strings for.

**Three small requests, once a day.** HadeethEnc can list only by category,
so the draw is: the root categories with their counts, a category picked
weighted by size, then one page of one entry in it, then the hadith. The
categories overlap, so a hadith filed under two is slightly likelier. Like the
ayah, the draw does not need to be uniform.

**Its own file, `hadith.json`.** Same today-only rule as `daily.json`, but kept
apart so that changing the Quran translation, which refetches the ayah, never
redraws the hadith. It also stores the UI language it was fetched for. Without
that, an English stand-in for a missing Uzbek copy would look stale on every
launch and be fetched again.

**Under the ayah, failing on its own.** One scrolling column, ayah first. The
hadith has its own state, so a HadeethEnc failure shows a retry under an ayah
that loaded, and the other way round.

**Amiri Quran for the hadith's Arabic.** It is already bundled and covers
classical Arabic with full tashkeel. Adding Amiri Regular would add a font
for a script the shipped one already renders.

## Terms

HadeethEnc allows republishing its translations on conditions. The app follows
them as follows:

- **No modification, addition or deletion.** Every string is stored and shown
  as sent, including the trailing `\r` on each lesson. This is the same rule the
  Quran text is under.
- **Credit the source.** The About dialog names HadeethEnc.com and links it.
- **No inappropriate advertising.** The app has none.
- **Credit the version.** Not met: the API exposes no version number, so there
  is nothing to show. Revisit if it starts sending one.

## Consequences

- A day's network use is the ayah's 2.3 KB plus about 1 KB of listing and one
  hadith of 25–56 KB.
- Most days an Uzbek reader sees the hadith in English. This was chosen
  knowingly over repeats.
- The hadith's Uzbek is Cyrillic, while the app's own Uzbek strings are Latin.
  HadeethEnc publishes only Cyrillic.
- A reminder still names neither the ayah nor the hadith (ADR-0003).
