import 'package:go_router/go_router.dart';

import '../screens/auth/create_user_screen.dart';
import '../screens/cancel/cancel_flow_screen.dart';
import '../screens/developer/developer_screen.dart';
import '../screens/habit/add_habit_screen.dart';
import '../screens/habit/habit_detail_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/paywall/launch_paywall_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shop/consumable_shop_screen.dart';
import '../widgets/pending_claim_listener.dart';
import 'routes.dart';

export 'routes.dart';

/// Builds the [GoRouter]. Pass [startAtHome] = true after onboarding has
/// completed so the app skips `/create-user`.
///
/// [initialLocationOverride] wins over [startAtHome] when non-null (e.g. to
/// route a non-premium onboarded user straight to [Routes.launchPaywall]).
GoRouter buildRouter({
  required bool startAtHome,
  String? initialLocationOverride,
}) {
  return GoRouter(
    initialLocation:
        initialLocationOverride ?? (startAtHome ? Routes.home : Routes.createUser),
    routes: [
      // A ShellRoute wraps every route so the app-level [PendingClaimListener]
      // mounts BELOW GoRouter's Navigator — `showModalBottomSheet` needs a
      // Navigator ancestor, which a `MaterialApp.router` `builder:` callback
      // sits above. The shell builder's `context` is a Navigator descendant,
      // so the claim sheet can present from any route.
      ShellRoute(
        builder: (_, _, child) => PendingClaimListener(child: child),
        routes: [
          GoRoute(
            path: Routes.createUser,
            name: 'create-user',
            builder: (_, _) => const CreateUserScreen(),
          ),
          GoRoute(
            path: Routes.home,
            name: 'home',
            builder: (_, _) => const HomeScreen(),
          ),
          GoRoute(
            path: Routes.addHabit,
            name: 'add-habit',
            builder: (_, _) => const AddHabitScreen(),
          ),
          GoRoute(
            path: Routes.habitDetailTemplate,
            name: 'habit-detail',
            builder: (_, state) {
              final id = int.parse(state.pathParameters['id']!);
              return HabitDetailScreen(habitId: id);
            },
          ),
          GoRoute(
            path: Routes.launchPaywall,
            name: 'paywall',
            builder: (_, _) => const LaunchPaywallScreen(),
          ),
          GoRoute(
            path: Routes.shop,
            name: 'shop',
            builder: (_, _) => const ConsumableShopScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            name: 'settings',
            builder: (_, _) => const SettingsScreen(),
          ),
          GoRoute(
            path: Routes.cancelFlowTemplate,
            name: 'cancel-flow',
            builder: (_, state) =>
                CancelFlowScreen(productId: state.pathParameters['productId']!),
          ),
          GoRoute(
            path: Routes.developer,
            name: 'developer',
            builder: (_, _) => const DeveloperScreen(),
          ),
        ],
      ),
    ],
  );
}
