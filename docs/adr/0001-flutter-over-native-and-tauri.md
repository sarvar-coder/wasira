# ADR-0001 — Flutter, not native-per-platform, Tauri, KMP or React Native

- **Status:** Superseded by ADR-0004
- **Date:** 2026-09-06

## Context

Wasira targets macOS first, then Windows, Linux, iOS, iPad, Android and possibly
web. It is built by one developer, and the roadmap is to keep adding Quran
learning features.

## Decision

Build with Flutter.

## Alternatives considered

**Native per platform** (Swift/SwiftUI + C#/WinUI + C++/Qt + Kotlin + TS/React).
Best possible UX per platform, and CoreText renders Uthmani Arabic flawlessly.
Rejected: five codebases in five languages for one developer is a 5x multiplier
on exactly the feature work the roadmap depends on.

**Swift/SwiftUI, Apple-only.** One codebase for macOS + iOS + iPad, no Arabic
rendering risk. Rejected: covers three of the seven targets; the other four
would be a rewrite.

**Tauri v2.** The closest call. System WebKit renders Arabic as well as Safari
does, binaries are ~10 MB, and official plugins cover SQL, notifications, HTTP
and filesystem so almost no Rust is required. Rejected on two grounds: it costs
learning a web frontend, and each OS uses its own webview (WebKit, WebView2,
WebKitGTK), so Arabic rendering quality varies per platform rather than being
verified once.

**Kotlin Multiplatform + Compose.** Rejected: desktop is its weakest target and
macOS is our first target; also costs learning Kotlin.

**React Native.** Rejected: no Linux support, and macOS lags the core project.

## Consequences

Flutter renders text with its own engine rather than CoreText, and Quranic
diacritics have historically misrendered in it (flutter#16886, #78780, #143975).
Wrong tashkeel is a correctness bug in scripture, not a cosmetic one, so this
risk is retired before product code by the M0 font spike; the chosen font is
recorded in ADR-0002.

One engine also means Arabic rendering is verified once and identical on every
platform, which is the upside of the same trade that creates the risk.
