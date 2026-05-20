# JustOne for Flutter — ZeroSettle SDK sample

**JustOne for Flutter** is a habit-tracker reference app demonstrating how to
integrate the ZeroSettle Flutter SDK. It mirrors the native Android JustOne
sample at `../../ZeroSettle-Android/sample/`.

This sample is structured as a real app, not a debug harness: there's a local
habit-tracking domain (Drift + WorkManager-style notifications) on top of which
the ZeroSettle SDK is integrated. Part 1 (this commit) is the core habit-tracker;
Part 2 layers paywall gating, monetization screens, the cancel/upgrade flows,
and the developer harness on top.

## Tech stack

| Concern | Package |
|---|---|
| Local database | `drift` + `sqlite3_flutter_libs` |
| Navigation | `go_router` |
| Preferences | `shared_preferences` |
| Notifications | `flutter_local_notifications` + `workmanager` (scaffold) |
| Theme | Material 3 (`useMaterial3: true`) |

## Routes (Part 1)

| Route | Screen | Description |
|---|---|---|
| `/create-user` | `CreateUserScreen` | First-launch onboarding; captures a display name and calls `ZeroSettle.identify`. |
| `/` | `HomeScreen` | 12-week heatmap across all habits + per-habit check-off list. |
| `/add-habit` | `AddHabitScreen` | Emoji + colour habit creation form. |
| `/habit/:id` | `HabitDetailScreen` | Per-habit current streak + completion history. |

Part 2 adds: `/paywall`, `/shop`, `/cancel/:productId`, `/settings`, `/developer/*`.

## File layout

```
lib/
├── main.dart                       — entry + SDK bootstrap + identity restore
├── app/
│   ├── app_theme.dart              — Material 3 theme tokens
│   ├── inherited_just_one.dart     — JustOneScope + InheritedJustOne (decoupled from main.dart)
│   ├── routes.dart                 — Routes name constants (dependency-free)
│   └── app_routes.dart             — GoRouter builder (imports every screen)
├── data/
│   ├── database.dart               — Drift schema (Habit, Completion, HabitDao)
│   ├── database.g.dart             — generated (committed)
│   └── user_prefs.dart             — typed wrapper over shared_preferences
├── domain/
│   └── habit_calc.dart             — pure-Dart streak + heatmap functions
├── notifications/
│   └── notification_service.dart   — flutter_local_notifications scaffold
├── screens/
│   ├── auth/create_user_screen.dart
│   ├── home/{home_screen,habit_list_item,heatmap_widget}.dart
│   └── habit/{add_habit_screen,habit_detail_screen}.dart
└── iap_environment.dart            — env roster (unchanged from previous example)
```

## Running

From this directory:

```bash
flutter pub get
flutter run                         # launches the app on a connected device
flutter test                        # runs the unit + widget tests
```

If you change the Drift schema in `lib/data/database.dart`, regenerate the
companion file:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Commit the regenerated `database.g.dart` — it is checked into the repo.

## Identity persistence

The first time you launch, `CreateUserScreen` captures a display name and
generates a stable per-install user id (`u_<ms-timestamp>`). Both are stored
in `UserPrefs` and re-used on subsequent launches — the app skips
`/create-user` and identifies the user to ZeroSettle on `main()`.

Wipe app data (Android Settings → Apps → JustOne → Storage → Clear data, or
delete + reinstall on iOS) to re-onboard.

## Environment switching

`iap_environment.dart` defines the publishable-key roster (sandbox / live /
staging / internal). The app resolves the active environment at launch via
`IAPEnvironment.load()`. A runtime env switcher UI lands in Part 2's developer
harness.

## Part 2 (not yet shipped)

Part 2 adds the SDK-heavy surfaces:
- Launch paywall with UCB-aware dual-price buy widget.
- Consumable shop with owned-count.
- Premium upsell sheet.
- Settings (cancel / pause / resume subscription).
- Cancel flow with confetti.
- Developer sub-screens (env switcher, raw entitlements, offer inspector,
  pending-actions inspector, cancel/upgrade debug, SDK event log).
- Deep-link return handling for web-checkout completion.
- Native `purchaseViaPlayBilling()` wiring for the Play Store buy button.
- Paywall gating (cap free users at 3 habits).
- EOD reminder scheduling via workmanager.
