# Wasira

A Quran reader. This glossary fixes the vocabulary the schema, the UI and the
conversation all use, because several of these words are routinely blurred and
blurring them has already produced bugs.

## Structure of the text

**Ayah**:
A single verse of the Quran. There are 6,236. The exception to preferring it
over "verse" is the fixed compound **verse-by-verse**, which names an audio
edition type rather than standing in for "ayah".
_Avoid_: verse, line

**Ayah number**:
An ayah's position in the whole Quran, 1 to 6,236. Unique.
_Avoid_: global index, absolute number, id

**Ayah number in surah**:
An ayah's position within its own surah, restarting at 1 for each. **Not**
interchangeable with ayah number — 2:1 is ayah number 8.
_Avoid_: local number, verse number

**Surah**:
One of the 114 named divisions of the Quran.
_Avoid_: chapter, sura

**Juz**:
One of 30 roughly equal parts, used for pacing a reading over a month.
_Avoid_: para, part

**Hizb quarter**:
One of 240 subdivisions; four quarters make a hizb, two hizbs make a juz.
_Avoid_: hizb, eighth

**Ruku**:
A thematic passage of several ayahs, marking a place to bow in prayer.

**Manzil**:
One of 7 parts, used for pacing a reading over a week.

**Page**:
A page of the printed Madani mushaf, 1 to 604. A property of an ayah, not of
this app's own layout.
_Avoid_: screen, sheet

**Mushaf**:
A physical printed copy of the Quran. Used here as the reference something is
compared *against*, not as something the app currently reproduces.

## Marks and script

**Uthmani**:
The orthography of the printed Madani mushaf, with full diacritics and Quran-
specific marks. The script this app renders.
_Avoid_: Arabic script, original text

**Tashkeel**:
The vowel and pronunciation marks written above and below the letters. Prefer
this when discussing the text; "diacritics" is the right word when discussing
type rendering, and upstream font and engine reports use it.
_Avoid_: accents, harakat

**Muqatta'at**:
The disconnected letters that open 29 surahs, such as الٓمٓ. Read as letter
names, not as a word.
_Avoid_: mysterious letters, abbreviations

**Bismillah**:
The opening formula بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ. It is ayah 1 of
Al-Fatiha, absent from At-Tawbah entirely, an unnumbered opening line elsewhere,
and ordinary ayah content inside 27:30.
_Avoid_: basmala, header, intro

**Sajda**:
An ayah at which prostration is called for. There are 15, of which some are
obligatory and the rest recommended — a split that varies by madhhab, so the
app records the classification rather than asserting a ruling.
_Avoid_: prostration verse, sujood

## Editions and audio

**Edition**:
One published rendering of the Quran, in text or audio, identified by a slug.
The Arabic text, a translation, a tafsir and a reciter are all editions.
_Avoid_: version, source, book

**Translation**:
An edition rendering the meaning of the Quran in another language.
_Avoid_: interpretation

**Tafsir**:
An edition of scholarly commentary rather than a plain rendering. Some editions
labelled as translations are effectively tafsir, carrying commentary inline.

**Recitation**:
The Quran read aloud **in Arabic**. Audio of a translation being read aloud is
not recitation and is never presented as one.
_Avoid_: audio, reading

**Reciter**:
A person who performs recitation. Reserved for Arabic recitation only.
_Avoid_: narrator, speaker, voice

**Murattal**:
A measured, everyday recitation style, suited to reading along and memorising.

**Mujawwad**:
A slower, more melodic recitation style, suited to listening.

**Verse-by-verse**:
An audio edition with one file per ayah. Required for following along ayah by
ayah, and for repeating a single ayah.
_Avoid_: ayah audio, per-verse

**Surah-by-surah**:
An audio edition with one file per surah. Cannot follow individual ayahs.
_Avoid_: full surah audio, continuous

## Reading and learning

**Reader**:
The screen on which a surah's ayahs are read. Not the person.
_Avoid_: viewer, page

**Hifz**:
Memorisation of the Quran. The practice the repeat features exist to serve.
_Avoid_: learning, study

**Daily ayah**:
An ayah selected for a given calendar date and kept, so that revisiting that
date shows the same ayah. Selection is fixed per date, never re-rolled.
_Avoid_: random ayah, ayah of the day

## Hadith

**Hadith**:
A report of what the Prophet ﷺ said, did or approved, as transmitted. Plural
**hadiths** in this repo. Never called an ayah or a verse, and never quoted
as Quran.
_Avoid_: saying, narration (as the noun for the whole report)

**Hadith of the day**:
One hadith drawn for today and shown under the daily ayah. Like the daily
ayah, it is held only for today.

**Attribution**:
Who recorded a hadith, as HadeethEnc phrases it: "Narrated by At-Tirmidhi",
"Agreed upon" (Bukhari and Muslim both).
_Avoid_: source, reference

**Grade**:
A hadith's authenticity classification: authentic (sahih), good (hasan) and so
on. Shown as given, the same way the sajda classification is data and not a
ruling.
_Avoid_: rating, strength

**Explanation**:
The scholarly commentary (sharh) on one hadith. The hadith counterpart of a
tafsir.
_Avoid_: commentary, tafsir

**Lessons**:
The points HadeethEnc draws from a hadith, sent as `hints`.
_Avoid_: hints, benefits
