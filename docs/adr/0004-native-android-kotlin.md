# ADR-0004 — Native Android in Kotlin; Flutter and macOS dropped

- **Status:** accepted
- **Date:** 2026-11-19
- **Supersedes:** ADR-0001

## Context

ADR-0001 chose Flutter because Wasira targeted seven platforms with macOS first,
and one codebase was the only way one developer could serve them all.

That premise no longer holds. Wasira now targets mobile only, Android first. A
once-a-day nudge belongs on the phone, where the reminder is seen; a desktop
window is opened deliberately or not at all. With macOS gone and one platform in
scope, the cross-platform engine buys nothing and still costs its own text
renderer, a plugin layer between the app and the OS, and a CI that never built
the app.

The Flutter code is deleted. Its last state is commit `c7a57fb`, tagged
`flutter-final`.

## Decision

Native Android, in Kotlin, with Jetpack Compose.

- **State:** a ViewModel per screen taking sealed events through a single
  `onEvent` and exposing a sealed state. This keeps what the `flutter_bloc`
  events rule existed for: the UI's `when` over the state is exhaustive, so an
  unhandled case fails the build. No bare mutator methods.
- **DI:** manual, in the `Application` subclass. Four dependencies do not need a
  framework.
- **Storage:** the same two JSON files, `settings.json` and `daily.json`, in
  `filesDir`, written to a `.part` file and atomically renamed over the target.
- **Reminders:** five inexact `AlarmManager` alarms, each re-armed when it fires
  and all re-armed by a receiver on boot, clock change and zone change. This
  replaces `flutter_local_notifications` and `timezone`.
- **Time zone:** `ZoneId.systemDefault()`. The `/etc/localtime` symlink read
  that worked around `tz.local` defaulting to UTC is gone with the package that
  needed it.

## Consequences

- iOS, when it comes, means either Kotlin Multiplatform or a separate port. That
  is accepted: one platform done natively now is worth more than two later.
- Arabic is shaped by the platform's own text stack rather than Flutter's
  engine, so the flutter#16886 risk that motivated the M0 spike no longer
  applies — but the font choice stands (ADR-0002), and goldens are still how a
  font change is judged.
- The scripture rules are unchanged: the Arabic is never altered, the Bismillah
  split rules and the 27:30 exception carry over exactly.
- ADR-0003's scope stands: one ayah a day, no reader, no history.
- CI now builds the app on every push, which the Flutter CI never did.
