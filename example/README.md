# JustOne for Flutter — ZeroSettle SDK sample

**JustOne for Flutter** is a habit-tracker reference app demonstrating how to
integrate the ZeroSettle Flutter SDK. It mirrors the native Android JustOne
sample at `../../ZeroSettle-Android/sample/`.

This sample is structured as a real app, not a debug harness: there's a local
habit-tracking domain (Drift + WorkManager-style notifications) on top of which
the ZeroSettle SDK is integrated.

## Tech stack

| Concern | Package |
|---|---|
| Local database | `drift` + `sqlite3_flutter_libs` |
| Navigation | `go_router` |
| Preferences | `shared_preferences` |
| Notifications | `flutter_local_notifications` + `flutter_timezone` |
| Confetti | `confetti` |
| Theme | Material 3 (`useMaterial3: true`) |

## Routes

| Route | Screen | Description |
|---|---|---|
| `/create-user` | `CreateUserScreen` | First-launch onboarding; captures a display name and calls `ZeroSettle.identify`. |
| `/` | `HomeScreen` | 12-week heatmap across all habits + per-habit check-off list. FAB shows upsell sheet once the 3-habit free cap is reached. |
| `/add-habit` | `AddHabitScreen` | Emoji + colour habit creation form. Gated by premium — opens upsell at the 3-habit cap. |
| `/habit/:id` | `HabitDetailScreen` | Per-habit current streak + completion history. |
| `/paywall` | `LaunchPaywallScreen` | Full-screen paywall shown at startup for non-premium users who have never dismissed it. |
| `/shop` | `ConsumableShopScreen` | Streak Saver consumable shop. Lists consumable products and tracks owned count locally via `UserPrefs.streakSaverCount`. |
| `/settings` | `SettingsScreen` | Account info, subscription management (cancel / pause / resume / upgrade), Streak Saver balance, daily reminder toggle, and a Developer entry. Embeds a `ZeroSettleOfferTip`. |
| `/cancel/:productId` | `CancelFlowScreen` | Renders the server-driven cancel-flow config (questions / save offer / pause option / confirm cancel). Shows confetti on cancellation. |
| `/developer` | `DeveloperScreen` | Developer harness — entry point for the sub-screens below (internal builds only). |

### Developer harness sub-screens

The `/developer` route is a list that pushes each sub-screen via `Navigator`:

| Sub-screen | Class | Description |
|---|---|---|
| Environment | `EnvSwitcherScreen` | Switch between sandbox / live / staging / internal publishable keys at runtime. |
| Entitlements | `DevEntitlementsScreen` | Raw dump of current SDK entitlements. |
| Offers | `DevOffersScreen` | Inspect available migration / upgrade offers returned by the SDK. |
| Pending actions | `DevPendingActionsScreen` | List pending SDK actions (unfinished transactions, retries). |
| Cancel flow (debug) | `DevCancelDebugScreen` | Trigger the cancel flow for any product id without navigating via Settings. |
| Upgrade offer | `DevUpgradeOfferScreen` | Inspect and trigger upgrade-offer presentation. |
| Debug | `DevDebugScreen` | Live SDK event log + state-reset actions. |

## Paywall gating

Free users are capped at **3 habits**. The cap is checked via `isPremium()` in
`domain/premium_status.dart`:

- The Home FAB calls `showPremiumUpsell()` (a modal bottom sheet —
  `PremiumUpsellSheet`) once the count hits 3.
- `main.dart` redirects to `/paywall` on startup when the user is non-premium
  and has never dismissed the launch paywall.
- `LaunchPaywallScreen` shows the full-screen paywall; dismissing it sets a
  flag in `UserPrefs` so it doesn't re-appear on the next launch.

## UCB-aware buy widget (`DualPriceButtons`)

`widgets/dual_price_buttons.dart` encapsulates the two purchase paths:

- **UCB on** (Google External Content Links eligible): renders a single
  **"Buy"** button that calls `purchaseViaPlayBilling()` (keeps the user inside
  Google Play billing).
- **UCB off**: renders two buttons — **"Pay on web"** (`purchase()` → web
  checkout) and **"Google Play"** (`purchaseViaPlayBilling()`).

Both the paywall and the upsell sheet use `DualPriceButtons`.

## Consumable shop

`ConsumableShopScreen` lists consumable Streak Saver products. Consumables do
not produce a server-side entitlement, so the owned count is tracked locally in
`UserPrefs.streakSaverCount` and incremented on each successful purchase.

## EOD reminder

`notifications/notification_service.dart` exposes
`scheduleEodReminder(TimeOfDay)` and `cancelEodReminder()`. The reminder is a
daily local notification scheduled via `flutter_local_notifications` zoned
scheduling (device-local timezone resolved by `flutter_timezone`). The
`ReminderCard` in Settings lets the user toggle it on/off and choose the time.

## File layout

```
lib/
├── main.dart                       — entry + SDK bootstrap + identity restore + paywall redirect
├── app/
│   ├── app_theme.dart              — Material 3 theme tokens
│   ├── inherited_just_one.dart     — JustOneScope + InheritedJustOne (decoupled from main.dart)
│   ├── routes.dart                 — Route name constants (dependency-free)
│   └── app_routes.dart             — GoRouter builder (imports every screen)
├── data/
│   ├── database.dart               — Drift schema (Habit, Completion, HabitDao)
│   ├── database.g.dart             — generated (committed)
│   └── user_prefs.dart             — typed wrapper over shared_preferences
├── domain/
│   ├── habit_calc.dart             — pure-Dart streak + heatmap functions
│   └── premium_status.dart         — isPremium() helper (reads SDK entitlements)
├── notifications/
│   └── notification_service.dart   — EOD reminder scheduling (flutter_local_notifications)
├── screens/
│   ├── auth/create_user_screen.dart
│   ├── cancel/cancel_flow_screen.dart
│   ├── developer/
│   │   ├── developer_screen.dart
│   │   ├── env_switcher_screen.dart
│   │   ├── dev_entitlements_screen.dart
│   │   ├── dev_offers_screen.dart
│   │   ├── dev_pending_actions_screen.dart
│   │   ├── dev_cancel_debug_screen.dart
│   │   ├── dev_upgrade_offer_screen.dart
│   │   └── dev_debug_screen.dart
│   ├── habit/{add_habit_screen,habit_detail_screen}.dart
│   ├── home/{home_screen,habit_list_item,heatmap_widget}.dart
│   ├── paywall/{launch_paywall_screen,premium_upsell_sheet}.dart
│   ├── settings/{settings_screen,account_card,subscription_card,streak_saver_card,reminder_card}.dart
│   └── shop/consumable_shop_screen.dart
└── widgets/
    ├── checkout_sheet_header.dart  — shared header widget for checkout bottom sheets
    ├── confetti_success.dart       — confetti overlay used on cancel completion
    ├── dual_price_buttons.dart     — UCB-aware buy widget (web + Play billing buttons)
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
`IAPEnvironment.load()`. The Developer harness includes an `EnvSwitcherScreen`
that lets you change the active environment at runtime without rebuilding.
