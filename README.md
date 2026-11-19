# Wasira

One ayah a day, on Android. The Arabic in Uthmani script with a translation of
your choice, and up to five daily reminders.

Data: [alquran.cloud](https://alquran.cloud) (`api-1.yaml`).

## Requirements

- JDK 17
- Android SDK 37

## Commands

```
./gradlew assembleDebug        # build
./gradlew testDebugUnitTest    # unit tests
./gradlew lintDebug            # lint
./gradlew installDebug         # install on a connected phone
```

Rules for working on the code are in `CLAUDE.md`; decisions in `docs/adr/`.
