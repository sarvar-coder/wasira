package uz.wasira.domain

/** What the app says about itself, and who it owes. */
object AppInfo {
    /** Mirrors `versionName` in app/build.gradle.kts; AppInfoTest fails if the two drift. */
    const val VERSION = "1.0.0"

    /** The Quran text and every translation come from one free, keyless API. */
    const val QURAN_SOURCE = "alquran.cloud"
    const val QURAN_SOURCE_URL = "https://alquran.cloud"

    /**
     * The daily hadith, its translation, grade and explanation. HadeethEnc's
     * terms ask that it be credited as the source of what is republished.
     */
    const val HADITH_SOURCE = "HadeethEnc.com"
    const val HADITH_SOURCE_URL = "https://hadeethenc.com"

    /**
     * Amiri Quran ships inside the app, and the SIL Open Font License requires
     * its copyright notice and licence to travel with it. Read out of the font's
     * own name table, so it cannot drift from the file being redistributed.
     */
    const val FONT_NAME = "Amiri Quran"
    const val FONT_COPYRIGHT =
        "Copyright 2010-2022 The Amiri Project Authors (https://github.com/aliftype/amiri)."
    const val FONT_LICENCE = "SIL Open Font License, Version 1.1"
    const val FONT_LICENCE_URL = "https://openfontlicense.org"
}
