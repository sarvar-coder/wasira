# ADR-0002 — Amiri Quran is the Arabic font; Flutter passes the M0 rendering gate

- **Status:** accepted
- **Date:** 2026-09-06
- **Follows:** ADR-0001

## Context

ADR-0001 chose Flutter while recording one risk: Flutter renders text with its
own engine rather than CoreText, and Quranic diacritics have historically
misrendered in it (flutter#16886, #78780, #143975). Wrong tashkeel is a
correctness bug in scripture. The M0 spike existed solely to retire that risk.

Six deliberately hard ayahs were rendered on macOS in three OFL candidate fonts
via headless Flutter golden tests: 2:282 (longest, line breaking under dense
tashkeel), 2:1 and 68:1 (muqatta'at with madda), 11:41 (small superscript
letters), 18:38 (superscript alef + hamzat wasl), 7:69 (U+06DC SMALL HIGH SEEN
and U+06ED SMALL LOW MEEM in one word).

## Decision

Flutter passes the M0 gate. **Amiri Quran** is the Arabic font.

## Evidence

Three independent signals:

1. **Glyph coverage is complete.** Across the whole corpus — the six hard ayahs
   plus all 286 ayahs of Al-Baqarah — the text uses 64 distinct codepoints, and
   all three candidate fonts have a glyph for every one. Tofu is not possible.
2. **Shaping is correct** in every render: no reversed order, every mark
   attached to its own letter.
3. **The flutter#16886 symptom is absent.** No diacritic renders at the wrong
   end of a letter in any font. That specific failure was what M0 tested for.

Amiri Quran over the other two because it is the variant purpose-built for
Quranic text, with the Quranic marks designed in rather than inherited, and it
is the smallest: 137 KB against Amiri's 431 KB and Scheherazade New's 332 KB.
Amiri Quran and Amiri render near-identically, the Quran variant being derived
from Amiri; Scheherazade New is visibly wider and rounder.

KFGQPC Uthmanic Script HAFS was not tested. It is the font named in
flutter#16886, and unlike the candidates it is not SIL OFL, so it cannot be
redistributed without resolving its license first.

## Consequences

The font is locked. Changing it later requires re-running the M0 goldens, since
a different font can silently lack a rare Quranic mark.

The real app should carry a test asserting the Quran corpus never uses a
codepoint the shipped font lacks — cheap, and it catches exactly that failure.

Note for later: the 2:1 golden renders as "Bismillah ar-Rahman ar-Rahim الٓمٓ",
because the API concatenates the Bismillah into ayah 1. Ayah 1 of Al-Baqarah is
الٓمٓ alone. That is a data-layer bug, not a font bug, and is handled separately.
